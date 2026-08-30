import '../models/token_definition.dart';

class ArtworkCreditResolver {
  const ArtworkCreditResolver._();

  static const String unknownArtist = 'Artist unknown';
  static const String userUploadedArtist = 'user uploaded';

  static String forVariant(ArtworkVariant variant) {
    if (variant.url.startsWith('file://')) return userUploadedArtist;
    final artist = variant.artist.trim();
    return artist.isEmpty ? unknownArtist : artist;
  }

  static String forSelection({
    required String url,
    required List<ArtworkVariant> variants,
  }) {
    if (url.startsWith('file://')) return userUploadedArtist;
    for (final variant in variants) {
      if (variant.url == url) return forVariant(variant);
    }
    return unknownArtist;
  }
}
