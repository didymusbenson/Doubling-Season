import '../models/token_definition.dart';

class ArtworkMetadataEnricher {
  const ArtworkMetadataEnricher._();

  static bool needsArtistMetadata(List<ArtworkVariant>? variants) {
    return variants?.any(
          (variant) =>
              !variant.url.startsWith('file://') &&
              variant.artist.trim().isEmpty,
        ) ??
        false;
  }

  /// Preserves saved ordering and custom variants while filling metadata from
  /// the current bundled definitions. Newly available official variants are
  /// appended so legacy board items receive the same complete picker as newly
  /// created items.
  static List<ArtworkVariant> merge({
    required List<ArtworkVariant> existing,
    required List<ArtworkVariant> authoritative,
  }) {
    final authoritativeByUrl = {
      for (final variant in authoritative) variant.url: variant,
    };
    final merged = <ArtworkVariant>[];
    final seenUrls = <String>{};

    for (final variant in existing) {
      final source = authoritativeByUrl[variant.url];
      merged.add(
        ArtworkVariant(
          set: variant.set.isEmpty ? source?.set ?? '' : variant.set,
          url: variant.url,
          artist: variant.artist.trim().isEmpty
              ? source?.artist ?? ''
              : variant.artist,
        ),
      );
      seenUrls.add(variant.url);
    }

    for (final variant in authoritative) {
      if (seenUrls.add(variant.url)) merged.add(variant);
    }
    return merged;
  }
}
