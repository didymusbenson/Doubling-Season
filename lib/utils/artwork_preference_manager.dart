import 'package:hive/hive.dart';
import '../models/token_artwork_preference.dart';

class ArtworkPreferenceManager {
  static const String _boxName = 'artworkPreferences';

  /// Get the Hive box (assumes already opened in HiveSetup)
  Box<TokenArtworkPreference> get _box => Hive.box<TokenArtworkPreference>(_boxName);

  /// Get preferred artwork for a token type (returns null if no preference set)
  String? getPreferredArtwork(String tokenIdentity) {
    final preference = _box.get(tokenIdentity);
    return preference?.lastUsedArtwork;
  }

  /// Set preferred artwork for a token type (creates preference if doesn't exist)
  Future<void> setPreferredArtwork(String tokenIdentity, String artworkUrl) async {
    var preference = _box.get(tokenIdentity);

    if (preference == null) {
      // Create new preference
      preference = TokenArtworkPreference(
        tokenIdentity: tokenIdentity,
        lastUsedArtwork: artworkUrl,
      );
      await _box.put(tokenIdentity, preference);
    } else {
      // Update existing preference
      preference.lastUsedArtwork = artworkUrl;
      await preference.save();
    }
  }

  /// Set custom artwork for a token type (stores file path separately)
  Future<void> setCustomArtwork(String tokenIdentity, String filePath) async {
    var preference = _box.get(tokenIdentity);

    if (preference == null) {
      preference = TokenArtworkPreference(
        tokenIdentity: tokenIdentity,
        lastUsedArtwork: filePath,
        customArtworkPath: filePath,
      );
      await _box.put(tokenIdentity, preference);
    } else {
      preference.customArtworkPath = filePath;
      preference.lastUsedArtwork = filePath;
      await preference.save();
    }
  }

  /// Get custom artwork path for a token type (returns null if never uploaded)
  String? getCustomArtworkPath(String tokenIdentity) {
    final preference = _box.get(tokenIdentity);
    return preference?.customArtworkPath;
  }

  /// Check if custom artwork exists for a token type
  bool hasCustomArtwork(String tokenIdentity) {
    final preference = _box.get(tokenIdentity);
    return preference?.hasCustomArtwork ?? false;
  }

  /// Remove custom artwork for a token type (also deletes file)
  Future<void> removeCustomArtwork(String tokenIdentity) async {
    final preference = _box.get(tokenIdentity);
    if (preference == null) return;

    // Delete file if exists
    if (preference.customArtworkPath != null) {
      // TODO: Delete file from filesystem
      // final file = File(preference.customArtworkPath!.replaceFirst('file://', ''));
      // if (await file.exists()) await file.delete();
    }

    // Clear custom artwork fields
    preference.customArtworkPath = null;

    // If this was the active artwork, clear it too
    if (preference.isUsingCustomArtwork) {
      preference.lastUsedArtwork = null;
    }

    await preference.save();
  }

  /// Clear all preferences (for testing/debugging)
  Future<void> clearAll() async {
    await _box.clear();
  }
}
