import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

/// Result of a manifest check. `available` is true only when the remote
/// `version` is strictly greater than the locally-active `tokenDbVersion` AND
/// the app's version satisfies the manifest's `min_app_version` floor.
class TokenUpdateResult {
  final bool available;
  final int currentVersion;
  final int? remoteVersion;
  final int? remoteSize;
  final String? remoteSha256;
  final String? remoteUpdatedDate;
  final String? minAppVersion;
  final String? error;

  const TokenUpdateResult({
    required this.available,
    required this.currentVersion,
    this.remoteVersion,
    this.remoteSize,
    this.remoteSha256,
    this.remoteUpdatedDate,
    this.minAppVersion,
    this.error,
  });

  factory TokenUpdateResult.failure(int currentVersion, String message) =>
      TokenUpdateResult(
        available: false,
        currentVersion: currentVersion,
        error: message,
      );
}

/// Stateless check / download / revert helpers. No provider, no listeners —
/// callers compose this with their own loading UI.
///
/// All methods are safe to call without network; failures return [false] /
/// `error`-populated results rather than throwing.
class TokenUpdateService {
  static const Duration _timeout = Duration(seconds: 10);

  /// Fetches the remote manifest and compares against the locally-stored
  /// `tokenDbVersion`. Does NOT download the database itself, and does NOT
  /// stamp the `tokenDbLastCheck` throttle — the caller owns that, so it can
  /// defer stamping until the user has actually acknowledged a shown modal.
  static Future<TokenUpdateResult> checkForUpdate() async {
    final prefs = await SharedPreferences.getInstance();
    final currentVersion = prefs.getInt(PreferenceKeys.tokenDbVersion) ?? 0;

    try {
      final response = await http
          .get(Uri.parse(RemoteUrls.tokenManifestUrl))
          .timeout(_timeout);

      if (response.statusCode != 200) {
        return TokenUpdateResult.failure(
            currentVersion, 'Server returned ${response.statusCode}');
      }

      final manifest = jsonDecode(response.body) as Map<String, dynamic>;
      final remoteVersion = manifest['version'] as int;
      final remoteSize = manifest['size'] as int?;
      final remoteSha = manifest['sha256'] as String?;
      final remoteUpdated = manifest['updated'] as String?;
      final minAppVersion = manifest['min_app_version'] as String?;
      final appVersion = (await PackageInfo.fromPlatform()).version;
      final compatible = minAppVersion == null ||
          _compareVersions(appVersion, minAppVersion) >= 0;

      return TokenUpdateResult(
        available: remoteVersion > currentVersion && compatible,
        currentVersion: currentVersion,
        remoteVersion: remoteVersion,
        remoteSize: remoteSize,
        remoteSha256: remoteSha,
        remoteUpdatedDate: remoteUpdated,
        minAppVersion: minAppVersion,
        error:
            compatible ? null : 'Requires app version $minAppVersion or newer',
      );
    } on SocketException {
      return TokenUpdateResult.failure(
          currentVersion, 'No internet connection');
    } catch (e) {
      return TokenUpdateResult.failure(
          currentVersion, 'Check failed: ${e.toString()}');
    }
  }

  /// Downloads the remote database, verifies its SHA256 matches the manifest,
  /// and writes it (plus the manifest) into the override directory. The
  /// caller is responsible for triggering [TokenDatabase.loadTokens] after
  /// success so the new data is parsed and indexed.
  ///
  /// Returns true on success. On failure (network, integrity, IO), the local
  /// override is left untouched — partial writes are explicitly avoided.
  static Future<bool> downloadUpdate({
    required int remoteVersion,
    required String expectedSha256,
    int? expectedSize,
    String? updatedDate,
    String? minAppVersion,
  }) async {
    try {
      final response = await http
          .get(Uri.parse(RemoteUrls.tokenDatabaseUrl))
          .timeout(const Duration(seconds: 60));

      if (response.statusCode != 200) return false;

      final bytes = response.bodyBytes;
      if (expectedSize != null && bytes.length != expectedSize) return false;
      final actualSha = sha256.convert(bytes).toString();
      if (actualSha != expectedSha256) return false;
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! List) return false;

      if (minAppVersion != null) {
        final appVersion = (await PackageInfo.fromPlatform()).version;
        if (_compareVersions(appVersion, minAppVersion) < 0) return false;
      }

      final dir = await getApplicationDocumentsDirectory();
      final overrideDir = Directory('${dir.path}/token_db');
      final pendingDir = Directory('${dir.path}/token_db.pending');
      final previousDir = Directory('${dir.path}/token_db.previous');
      if (await pendingDir.exists()) await pendingDir.delete(recursive: true);
      await pendingDir.create(recursive: true);

      final manifestPayload = {
        'version': remoteVersion,
        'sha256': expectedSha256,
        'size': expectedSize ?? bytes.length,
        'updated': updatedDate,
        'min_app_version': minAppVersion,
      };
      final tempDb = File('${pendingDir.path}/token_database.json');
      final tempManifest = File('${pendingDir.path}/manifest.json');

      await tempDb.writeAsBytes(bytes, flush: true);
      await tempManifest.writeAsString(
        jsonEncode(manifestPayload),
        flush: true,
      );

      // Promote the verified directory as one unit, retaining the prior
      // generation. The database and manifest are therefore never split
      // across generations during a normal update or rollback.
      if (await previousDir.exists()) {
        await previousDir.delete(recursive: true);
      }
      var currentBackedUp = false;
      try {
        if (await overrideDir.exists()) {
          await overrideDir.rename(previousDir.path);
          currentBackedUp = true;
        }
        await pendingDir.rename(overrideDir.path);
      } catch (_) {
        if (await overrideDir.exists()) {
          await overrideDir.delete(recursive: true);
        }
        if (currentBackedUp && await previousDir.exists()) {
          await previousDir.rename(overrideDir.path);
        }
        if (await pendingDir.exists()) {
          await pendingDir.delete(recursive: true);
        }
        return false;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(PreferenceKeys.tokenDbVersion, remoteVersion);

      return true;
    } catch (_) {
      return false;
    }
  }

  /// Deletes the local override (DB + manifest) so the next
  /// [TokenDatabase.loadTokens] falls back to the bundled asset. Resets the
  /// stored `tokenDbVersion` to 0 so a subsequent check will flag any newer
  /// remote as an available update.
  static Future<void> revertToBundled() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final overrideDir = Directory('${dir.path}/token_db');
      if (await overrideDir.exists()) {
        await overrideDir.delete(recursive: true);
      }
      for (final suffix in ['pending', 'previous']) {
        final sibling = Directory('${dir.path}/token_db.$suffix');
        if (await sibling.exists()) await sibling.delete(recursive: true);
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(PreferenceKeys.tokenDbVersion, 0);
    } catch (_) {
      // Best-effort.
    }
  }

  /// True if a downloaded override is currently in use (i.e., the `token_db`
  /// directory and manifest are present). Used by the About-screen UI to
  /// decide whether to show the "Reset to Built-in" button.
  static Future<bool> hasOverride() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final manifest = File('${dir.path}/token_db/manifest.json');
      return await manifest.exists();
    } catch (_) {
      return false;
    }
  }

  static int _compareVersions(String left, String right) {
    List<int> parts(String value) => value
        .split('-')
        .first
        .split('.')
        .map((part) => int.tryParse(part) ?? 0)
        .toList();

    final a = parts(left);
    final b = parts(right);
    final length = a.length > b.length ? a.length : b.length;
    for (var index = 0; index < length; index++) {
      final aPart = index < a.length ? a[index] : 0;
      final bPart = index < b.length ? b[index] : 0;
      if (aPart != bPart) return aPart.compareTo(bPart);
    }
    return 0;
  }
}
