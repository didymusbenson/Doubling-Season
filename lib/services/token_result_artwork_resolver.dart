import '../database/token_database.dart';
import '../models/token_definition.dart' show ArtworkVariant;
import '../providers/rules_provider.dart';
import '../utils/artwork_preference_manager.dart';

class ResolvedTokenArtwork {
  final String? url;
  final String? set;
  final List<ArtworkVariant>? options;

  const ResolvedTokenArtwork({this.url, this.set, this.options});
}

/// Resolves a rules result through saved preference, then database default.
class TokenResultArtworkResolver {
  const TokenResultArtworkResolver._();

  static ResolvedTokenArtwork resolve({
    required TokenCreationResult result,
    TokenDatabase? tokenDatabase,
  }) {
    final preferences = ArtworkPreferenceManager();
    final definition = tokenDatabase?.findByCompositeId(result.tokenDatabaseId);

    if (definition == null) {
      return ResolvedTokenArtwork(
        url: preferences.getPreferredArtwork(result.compositeId),
      );
    }

    String? url;
    String? set;
    final preferred = preferences.getPreferredArtwork(definition.id);
    if (preferred != null) {
      url = preferred;
      if (!preferred.startsWith('file://') && definition.artwork.isNotEmpty) {
        final match = definition.artwork.firstWhere(
          (art) => art.url == preferred,
          orElse: () => definition.artwork.first,
        );
        set = match.set;
      }
    } else if (definition.artwork.isNotEmpty) {
      url = definition.artwork.first.url;
      set = definition.artwork.first.set;
    }

    return ResolvedTokenArtwork(
      url: url,
      set: set,
      options: definition.artwork.isEmpty
          ? null
          : List<ArtworkVariant>.from(definition.artwork),
    );
  }
}
