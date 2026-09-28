import '../models/token_definition.dart';

class ArtworkMetadataEnricher {
  const ArtworkMetadataEnricher._();

  /// Metadata identity only. Never rewrite stored URLs or cache keys. Preserve
  /// the face so the two sides of a card cannot borrow each other's credit.
  static String identity(String url) {
    final uri = Uri.tryParse(url);
    if (uri?.host == 'cards.scryfall.io') {
      final match = RegExp(
        r'^/[^/]+/(front|back)/[0-9a-f]/[0-9a-f]/([0-9a-f-]{36})\.(jpg|png)$',
      ).firstMatch(uri!.path);
      if (match != null) return 'scryfall:${match[1]}:${match[2]}';
    }
    return url;
  }

  static bool needsArtistMetadata(List<ArtworkVariant>? variants) =>
      variants?.any(
        (variant) =>
            !variant.url.startsWith('file://') && variant.artist.trim().isEmpty,
      ) ??
      false;

  /// Saved variants always win. Only a positively identified definition adds
  /// alternate art; the broader catalog only fills credits for known images.
  static List<ArtworkVariant> merge({
    required List<ArtworkVariant> existing,
    required List<ArtworkVariant> authoritative,
    Iterable<ArtworkVariant> catalog = const [],
    String? selectedUrl,
    String? selectedSet,
  }) {
    final sources = <String, ArtworkVariant>{};
    for (final variant in [...authoritative, ...catalog]) {
      for (final key in [variant.url, identity(variant.url)]) {
        final previous = sources[key];
        if (previous == null || previous.artist.trim().isEmpty) {
          sources[key] = variant;
        }
      }
    }
    final saved = [...existing];
    if (selectedUrl != null &&
        selectedUrl.isNotEmpty &&
        !saved.any((v) => v.url == selectedUrl)) {
      saved.add(ArtworkVariant(set: selectedSet ?? '', url: selectedUrl));
    }
    final merged = <ArtworkVariant>[];
    final seen = <String>{};
    for (final variant in saved) {
      final source = variant.url.startsWith('file://')
          ? null
          : sources[variant.url] ?? sources[identity(variant.url)];
      merged.add(
        ArtworkVariant(
          set: variant.set.isEmpty ? source?.set ?? '' : variant.set,
          url: variant.url,
          artist: variant.artist.trim().isEmpty
              ? source?.artist ?? ''
              : variant.artist,
        ),
      );
      seen.add(identity(variant.url));
    }
    for (final variant in authoritative) {
      if (seen.add(identity(variant.url))) merged.add(variant);
    }
    return merged;
  }
}
