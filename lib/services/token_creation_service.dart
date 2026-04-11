import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import '../models/item.dart';
import '../models/token_definition.dart' as token_models;
import '../database/token_database.dart';
import '../providers/token_provider.dart';
import '../providers/rules_provider.dart';
import '../utils/artwork_manager.dart';
import '../utils/artwork_preference_manager.dart';

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

      // Check for existing matching stack (same identity, no counters)
      final existingStack = tokenProvider.items.firstWhereOrNull(
        (item) =>
            item.name == companion.name &&
            item.pt == companion.pt &&
            item.colors == companion.colors &&
            item.type == companion.type &&
            item.abilities == companion.abilities &&
            item.plusOneCounters == 0 &&
            item.minusOneCounters == 0 &&
            item.counters.isEmpty,
      );

      if (existingStack != null) {
        existingStack.amount += companion.quantity;
        if (summoningSicknessEnabled &&
            existingStack.hasPowerToughness &&
            !existingStack.hasHaste) {
          existingStack.summoningSick += companion.quantity;
        }
        await existingStack.save();
      } else {
        // Resolve artwork via preferences → database fallback
        String? artworkUrl;
        String? artworkSet;
        List<token_models.ArtworkVariant>? artworkOptions;

        final artworkPrefManager = ArtworkPreferenceManager();
        final companionDef = tokenDatabase?.findByCompositeId(companion.tokenDatabaseId);

        if (companionDef != null) {
          final preferredArtwork = artworkPrefManager.getPreferredArtwork(companionDef.id);
          if (preferredArtwork != null) {
            artworkUrl = preferredArtwork;
            if (!preferredArtwork.startsWith('file://') && companionDef.artwork.isNotEmpty) {
              final matchingArtwork = companionDef.artwork.firstWhere(
                (art) => art.url == preferredArtwork,
                orElse: () => companionDef.artwork[0],
              );
              artworkSet = matchingArtwork.set;
            }
          } else if (companionDef.artwork.isNotEmpty) {
            artworkUrl = companionDef.artwork[0].url;
            artworkSet = companionDef.artwork[0].set;
          }
          artworkOptions = companionDef.artwork.isNotEmpty
              ? List<token_models.ArtworkVariant>.from(companionDef.artwork)
              : null;
        } else {
          // No database entry — try preference by composite ID directly
          artworkUrl = artworkPrefManager.getPreferredArtwork(companion.compositeId);
        }

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
          artworkUrl: artworkUrl,
          artworkSet: artworkSet,
          artworkOptions: artworkOptions,
        );
        nextOrder += 1.0;

        await tokenProvider.insertItem(newItem);

        // Apply summoning sickness AFTER insert
        if (summoningSicknessEnabled &&
            newItem.hasPowerToughness &&
            !newItem.hasHaste) {
          newItem.summoningSick = companion.quantity;
        }

        // Download artwork in background
        if (!kIsWeb && newItem.artworkUrl != null && !newItem.artworkUrl!.startsWith('file://')) {
          final downloadUrl = newItem.artworkUrl!;
          ArtworkManager.downloadArtwork(downloadUrl).then((file) {
            if (file == null) {
              debugPrint('Artwork download failed for ${companion.name}, resetting URL');
              final currentItem = tokenProvider.items.firstWhereOrNull(
                (item) => item.artworkUrl == downloadUrl,
              );
              if (currentItem != null) {
                currentItem.artworkUrl = null;
                currentItem.artworkSet = null;
                currentItem.save();
              }
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

      // Check for existing matching stack (same identity, no counters)
      final existingStack = tokenProvider.items.firstWhereOrNull(
        (item) =>
            item.name == result.name &&
            item.pt == result.pt &&
            item.colors == result.colors &&
            item.type == result.type &&
            item.abilities == result.abilities &&
            item.plusOneCounters == 0 &&
            item.minusOneCounters == 0 &&
            item.counters.isEmpty,
      );

      if (existingStack != null) {
        existingStack.amount += result.quantity;
        if (summoningSicknessEnabled &&
            existingStack.hasPowerToughness &&
            !existingStack.hasHaste) {
          existingStack.summoningSick += result.quantity;
        }
        await existingStack.save();
      } else {
        // Resolve artwork
        String? artworkUrl;
        String? artworkSet;
        List<token_models.ArtworkVariant>? artworkOptions;

        final artworkPrefManager = ArtworkPreferenceManager();
        final def = tokenDatabase?.findByCompositeId(result.tokenDatabaseId);

        if (def != null) {
          final preferredArtwork = artworkPrefManager.getPreferredArtwork(def.id);
          if (preferredArtwork != null) {
            artworkUrl = preferredArtwork;
            if (!preferredArtwork.startsWith('file://') && def.artwork.isNotEmpty) {
              final matchingArtwork = def.artwork.firstWhere(
                (art) => art.url == preferredArtwork,
                orElse: () => def.artwork[0],
              );
              artworkSet = matchingArtwork.set;
            }
          } else if (def.artwork.isNotEmpty) {
            artworkUrl = def.artwork[0].url;
            artworkSet = def.artwork[0].set;
          }
          artworkOptions = def.artwork.isNotEmpty
              ? List<token_models.ArtworkVariant>.from(def.artwork)
              : null;
        } else {
          artworkUrl = artworkPrefManager.getPreferredArtwork(result.compositeId);
        }

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
          artworkUrl: artworkUrl,
          artworkSet: artworkSet,
          artworkOptions: artworkOptions,
        );
        nextOrder += 1.0;

        await tokenProvider.insertItem(newItem);

        if (summoningSicknessEnabled &&
            newItem.hasPowerToughness &&
            !newItem.hasHaste) {
          newItem.summoningSick = result.quantity;
        }

        // Download artwork in background
        if (!kIsWeb && newItem.artworkUrl != null && !newItem.artworkUrl!.startsWith('file://')) {
          final downloadUrl = newItem.artworkUrl!;
          ArtworkManager.downloadArtwork(downloadUrl).then((file) {
            if (file == null) {
              final currentItem = tokenProvider.items.firstWhereOrNull(
                (item) => item.artworkUrl == downloadUrl,
              );
              if (currentItem != null) {
                currentItem.artworkUrl = null;
                currentItem.artworkSet = null;
                currentItem.save();
              }
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
