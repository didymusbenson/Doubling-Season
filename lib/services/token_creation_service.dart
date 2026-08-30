import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import '../database/token_database.dart';
import '../models/item.dart';
import '../providers/rules_provider.dart';
import '../providers/token_provider.dart';
import '../utils/artwork_manager.dart';
import '../utils/game_events.dart';
import 'token_merge_compatibility.dart';
import 'token_result_artwork_resolver.dart';

enum TokenMergePolicy { never, compatibleCleanStack }

enum TokenCreationEventPolicy { creatureEntered, none }

class TokenCommitRequest {
  final TokenCreationResult result;
  final ResolvedTokenArtwork artwork;
  final double order;
  final bool createTapped;
  final bool applySummoningSickness;
  final TokenMergePolicy mergePolicy;
  final TokenCreationEventPolicy eventPolicy;

  const TokenCommitRequest({
    required this.result,
    required this.artwork,
    required this.order,
    required this.applySummoningSickness,
    this.createTapped = false,
    this.mergePolicy = TokenMergePolicy.compatibleCleanStack,
    this.eventPolicy = TokenCreationEventPolicy.creatureEntered,
  });
}

class TokenCommitOutcome {
  final List<Item> createdItems;
  final int createdQuantity;
  final Map<Item, int> mergedQuantities;

  const TokenCommitOutcome({
    required this.createdItems,
    required this.createdQuantity,
    required this.mergedQuantities,
  });

  int get totalQuantity =>
      createdQuantity +
      mergedQuantities.values.fold(0, (sum, amount) => sum + amount);
}

class TokenCommitException implements Exception {
  final Object cause;
  final StackTrace stackTrace;
  final TokenCommitOutcome partialOutcome;

  const TokenCommitException({
    required this.cause,
    required this.stackTrace,
    required this.partialOutcome,
  });

  @override
  String toString() => 'Token creation partially failed: $cause';
}

/// Shared commit boundary for already-evaluated token creation results.
///
/// Rules evaluation, artwork choice, and unified-board order stay outside this
/// service. Every request explicitly selects merge and event behavior.
class TokenCreationService {
  static Future<TokenCommitOutcome> commit({
    required List<TokenCommitRequest> requests,
    required TokenProvider tokenProvider,
  }) async {
    final createdItems = <Item>[];
    var createdQuantity = 0;
    final mergedQuantities = <Item, int>{};

    for (final request in requests) {
      if (request.result.quantity <= 0) continue;

      try {
        final mergeTarget =
            request.mergePolicy == TokenMergePolicy.compatibleCleanStack
                ? tokenProvider.items.firstWhereOrNull(
                    (item) => TokenMergeCompatibility.canMerge(
                      item,
                      name: request.result.name,
                      pt: request.result.pt,
                      colors: request.result.colors,
                      type: request.result.type,
                      abilities: request.result.abilities,
                      artworkUrl: request.artwork.url,
                    ),
                  )
                : null;

        if (mergeTarget != null) {
          mergeTarget.amount += request.result.quantity;
          if (request.applySummoningSickness &&
              mergeTarget.hasPowerToughness &&
              !mergeTarget.hasHaste) {
            mergeTarget.summoningSick += request.result.quantity;
          }
          await mergeTarget.save();
          mergedQuantities.update(
            mergeTarget,
            (quantity) => quantity + request.result.quantity,
            ifAbsent: () => request.result.quantity,
          );
          _emitEvent(request, mergeTarget);
          continue;
        }

        final newItem = Item(
          name: request.result.name,
          pt: request.result.pt,
          abilities: request.result.abilities,
          colors: request.result.colors,
          type: request.result.type,
          amount: request.result.quantity,
          tapped: request.createTapped ? request.result.quantity : 0,
          summoningSick: 0,
          order: request.order,
          artworkUrl: request.artwork.url,
          artworkSet: request.artwork.set,
          artworkOptions: request.artwork.options == null
              ? null
              : List.from(request.artwork.options!),
        );

        await tokenProvider.insertItem(
          newItem,
          notifyCreatureEntered: false,
        );
        if (request.applySummoningSickness &&
            newItem.hasPowerToughness &&
            !newItem.hasHaste) {
          newItem.summoningSick = request.result.quantity;
          await newItem.save();
        }
        createdItems.add(newItem);
        createdQuantity += request.result.quantity;
        _emitEvent(request, newItem);
        _cacheArtwork(newItem);
      } catch (error, stackTrace) {
        throw TokenCommitException(
          cause: error,
          stackTrace: stackTrace,
          partialOutcome: TokenCommitOutcome(
            createdItems: List.unmodifiable(createdItems),
            createdQuantity: createdQuantity,
            mergedQuantities: Map.unmodifiable(mergedQuantities),
          ),
        );
      }
    }

    return TokenCommitOutcome(
      createdItems: List.unmodifiable(createdItems),
      createdQuantity: createdQuantity,
      mergedQuantities: Map.unmodifiable(mergedQuantities),
    );
  }

  static void _emitEvent(TokenCommitRequest request, Item item) {
    if (request.eventPolicy == TokenCreationEventPolicy.creatureEntered &&
        item.hasPowerToughness) {
      GameEvents.instance.notifyCreatureEntered(item, request.result.quantity);
    }
  }

  static void _cacheArtwork(Item item) {
    if (kIsWeb) return;
    final url = item.artworkUrl;
    if (url == null || url.startsWith('file://')) return;

    ArtworkManager.downloadArtwork(url).then((file) async {
      if (file == null || !item.isInBox || item.artworkUrl != url) return;
      await item.save();
    }).catchError((error) {
      debugPrint('Error during background artwork download: $error');
    });
  }

  static List<TokenCommitRequest> requestsFromResults({
    required Iterable<TokenCreationResult> results,
    required bool summoningSicknessEnabled,
    required double insertionOrder,
    TokenDatabase? tokenDatabase,
    TokenMergePolicy mergePolicy = TokenMergePolicy.compatibleCleanStack,
    TokenCreationEventPolicy eventPolicy =
        TokenCreationEventPolicy.creatureEntered,
  }) {
    var nextOrder = insertionOrder;
    return [
      for (final result in results)
        if (result.quantity > 0)
          TokenCommitRequest(
            result: result,
            artwork: TokenResultArtworkResolver.resolve(
              result: result,
              tokenDatabase: tokenDatabase,
            ),
            order: nextOrder++,
            applySummoningSickness: summoningSicknessEnabled,
            mergePolicy: mergePolicy,
            eventPolicy: eventPolicy,
          ),
    ];
  }

  static Future<int> createCompanionTokens({
    required List<TokenCreationResult> results,
    required TokenProvider tokenProvider,
    required bool summoningSicknessEnabled,
    required double insertionOrder,
    TokenDatabase? tokenDatabase,
  }) async {
    final outcome = await commit(
      requests: requestsFromResults(
        results: results.skip(1),
        summoningSicknessEnabled: summoningSicknessEnabled,
        insertionOrder: insertionOrder,
        tokenDatabase: tokenDatabase,
      ),
      tokenProvider: tokenProvider,
    );
    return outcome.totalQuantity;
  }

  static Future<int> createAllFromResults({
    required List<TokenCreationResult> results,
    required TokenProvider tokenProvider,
    required bool summoningSicknessEnabled,
    required double insertionOrder,
    TokenDatabase? tokenDatabase,
  }) async {
    final outcome = await commit(
      requests: requestsFromResults(
        results: results,
        summoningSicknessEnabled: summoningSicknessEnabled,
        insertionOrder: insertionOrder,
        tokenDatabase: tokenDatabase,
      ),
      tokenProvider: tokenProvider,
    );
    return outcome.totalQuantity;
  }
}
