import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import '../models/item.dart';
import '../database/token_database.dart';
import '../providers/token_provider.dart';
import '../providers/rules_provider.dart';
import '../utils/artwork_manager.dart';
import '../utils/game_events.dart';
import 'token_merge_compatibility.dart';
import 'token_result_artwork_resolver.dart';

/// Shared service for creating tokens from rules engine results.
/// Eliminates duplication across token search, new token sheet,
/// token card quick-add, and utility actions.
class TokenCreationService {
  /// Create companion tokens (results[1..n]) from rules evaluation.
  /// The primary token (results[0]) is handled by the caller since
  /// each call site has different primary token handling (different artwork
  /// sources, different UI flows).
  ///
  /// [results] - Full list from evaluateRules(). Only results.skip(1) are processed.
  /// [tokenProvider] - For inserting items and finding existing stacks.
  /// [summoningSicknessEnabled] - Whether to apply sickness to creatures.
  /// [insertionOrder] - Starting order value for new items. Incremented per item.
  /// [tokenDatabase] - Optional database for artwork fallback lookup.
  /// [addToExistingStacks] - If true (default), merges into matching stacks.
  ///
  /// Returns the total number of companion tokens created/added.
  static Future<int> createCompanionTokens({
    required List<TokenCreationResult> results,
    required TokenProvider tokenProvider,
    required bool summoningSicknessEnabled,
    required double insertionOrder,
    TokenDatabase? tokenDatabase,
  }) async {
    if (results.length <= 1) return 0;

    int companionCount = 0;
    double nextOrder = insertionOrder;

    for (final companion in results.skip(1)) {
      if (companion.quantity <= 0) continue;
      companionCount += companion.quantity;

      final artwork = TokenResultArtworkResolver.resolve(
        result: companion,
        tokenDatabase: tokenDatabase,
      );

      // Check for an exact, clean, artwork-compatible stack.
      final existingStack = tokenProvider.items.firstWhereOrNull(
        (item) => TokenMergeCompatibility.canMerge(
          item,
          name: companion.name,
          pt: companion.pt,
          colors: companion.colors,
          type: companion.type,
          abilities: companion.abilities,
          artworkUrl: artwork.url,
        ),
      );

      if (existingStack != null) {
        existingStack.amount += companion.quantity;
        if (summoningSicknessEnabled &&
            existingStack.hasPowerToughness &&
            !existingStack.hasHaste) {
          existingStack.summoningSick += companion.quantity;
        }
        await existingStack.save();
        if (existingStack.hasPowerToughness) {
          GameEvents.instance
              .notifyCreatureEntered(existingStack, companion.quantity);
        }
      } else {
        final newItem = Item(
          name: companion.name,
          pt: companion.pt,
          abilities: companion.abilities,
          colors: companion.colors,
          type: companion.type,
          amount: companion.quantity,
          tapped: 0,
          summoningSick: 0,
          order: nextOrder,
          artworkUrl: artwork.url,
          artworkSet: artwork.set,
          artworkOptions: artwork.options,
        );
        nextOrder += 1.0;

        await tokenProvider.insertItem(newItem);

        // Apply summoning sickness AFTER insert
        if (summoningSicknessEnabled &&
            newItem.hasPowerToughness &&
            !newItem.hasHaste) {
          newItem.summoningSick = companion.quantity;
        }

        // Download artwork in background, then trigger rebuild
        if (!kIsWeb &&
            newItem.artworkUrl != null &&
            !newItem.artworkUrl!.startsWith('file://')) {
          final downloadUrl = newItem.artworkUrl!;
          ArtworkManager.downloadArtwork(downloadUrl).then((file) {
            final currentItem = tokenProvider.items.firstWhereOrNull(
              (item) => item.artworkUrl == downloadUrl,
            );
            if (currentItem == null) return;
            if (file != null) {
              // Trigger rebuild so FutureBuilder picks up the cached file
              currentItem.save();
            } else {
              debugPrint(
                  'Artwork download failed for ${companion.name}, resetting URL');
              currentItem.artworkUrl = null;
              currentItem.artworkSet = null;
              currentItem.save();
            }
          }).catchError((error) {
            debugPrint('Error during background artwork download: $error');
          });
        }
      }
    }

    return companionCount;
  }

  /// Create all tokens from rules results where there is no distinct "primary"
  /// (e.g., Academy Manufactor action where all results are equal peers).
  /// Merges into existing matching stacks when possible.
  ///
  /// Returns the total number of tokens created/added.
  static Future<int> createAllFromResults({
    required List<TokenCreationResult> results,
    required TokenProvider tokenProvider,
    required bool summoningSicknessEnabled,
    required double insertionOrder,
    TokenDatabase? tokenDatabase,
  }) async {
    int totalCount = 0;
    double nextOrder = insertionOrder;

    for (final result in results) {
      if (result.quantity <= 0) continue;
      totalCount += result.quantity;

      final artwork = TokenResultArtworkResolver.resolve(
        result: result,
        tokenDatabase: tokenDatabase,
      );

      // Check for an exact, clean, artwork-compatible stack.
      final existingStack = tokenProvider.items.firstWhereOrNull(
        (item) => TokenMergeCompatibility.canMerge(
          item,
          name: result.name,
          pt: result.pt,
          colors: result.colors,
          type: result.type,
          abilities: result.abilities,
          artworkUrl: artwork.url,
        ),
      );

      if (existingStack != null) {
        existingStack.amount += result.quantity;
        if (summoningSicknessEnabled &&
            existingStack.hasPowerToughness &&
            !existingStack.hasHaste) {
          existingStack.summoningSick += result.quantity;
        }
        await existingStack.save();
        if (existingStack.hasPowerToughness) {
          GameEvents.instance
              .notifyCreatureEntered(existingStack, result.quantity);
        }
      } else {
        final newItem = Item(
          name: result.name,
          pt: result.pt,
          abilities: result.abilities,
          colors: result.colors,
          type: result.type,
          amount: result.quantity,
          tapped: 0,
          summoningSick: 0,
          order: nextOrder,
          artworkUrl: artwork.url,
          artworkSet: artwork.set,
          artworkOptions: artwork.options,
        );
        nextOrder += 1.0;

        await tokenProvider.insertItem(newItem);

        if (summoningSicknessEnabled &&
            newItem.hasPowerToughness &&
            !newItem.hasHaste) {
          newItem.summoningSick = result.quantity;
        }

        // Download artwork in background, then trigger rebuild
        if (!kIsWeb &&
            newItem.artworkUrl != null &&
            !newItem.artworkUrl!.startsWith('file://')) {
          final downloadUrl = newItem.artworkUrl!;
          ArtworkManager.downloadArtwork(downloadUrl).then((file) {
            final currentItem = tokenProvider.items.firstWhereOrNull(
              (item) => item.artworkUrl == downloadUrl,
            );
            if (currentItem == null) return;
            if (file != null) {
              // Trigger rebuild so FutureBuilder picks up the cached file
              currentItem.save();
            } else {
              currentItem.artworkUrl = null;
              currentItem.artworkSet = null;
              currentItem.save();
            }
          }).catchError((error) {
            debugPrint('Error during background artwork download: $error');
          });
        }
      }
    }

    return totalCount;
  }
}
