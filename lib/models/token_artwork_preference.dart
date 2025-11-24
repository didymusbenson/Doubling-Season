// lib/models/token_artwork_preference.dart

import 'package:hive/hive.dart';

part 'token_artwork_preference.g.dart';

@HiveType(typeId: 5)
class TokenArtworkPreference extends HiveObject {
  /// Composite ID matching deduplication logic: "name|pt|colors|type|abilities"
  /// This matches the TokenDefinition.id format from the database
  @HiveField(0)
  String tokenIdentity;

  /// Currently selected/last used artwork (Scryfall URL or file:// path)
  /// This is applied as default when creating new tokens of this type
  @HiveField(1)
  String? lastUsedArtwork;

  /// User's custom uploaded artwork (file:// path), persists independently
  /// Remains available even when user switches to Scryfall artwork
  /// Null if user has never uploaded custom art for this token type
  @HiveField(2)
  String? customArtworkPath;

  TokenArtworkPreference({
    required this.tokenIdentity,
    this.lastUsedArtwork,
    this.customArtworkPath,
  });

  /// Helper: Is custom artwork available for this token type?
  bool get hasCustomArtwork =>
      customArtworkPath != null && customArtworkPath!.isNotEmpty;

  /// Helper: Is currently using custom artwork?
  bool get isUsingCustomArtwork =>
      lastUsedArtwork != null &&
      lastUsedArtwork!.startsWith('file://');
}
