import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Manages downloading and caching of token artwork from Scryfall CDN
class ArtworkManager {
  /// User-Agent header for good etiquette when downloading from Scryfall
  static const String userAgent = 'DoublingSeason/1.0';

  /// Get the artwork cache directory path
  static Future<Directory> getArtworkCacheDirectory() async {
    final appDir = await getApplicationSupportDirectory();
    final cacheDir = Directory('${appDir.path}/artwork_cache');

    // Create directory if it doesn't exist
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }

    return cacheDir;
  }

  /// Generate a deterministic filename from a URL using MD5 hash
  static String _urlToFilename(String url) {
    final bytes = utf8.encode(url);
    final hash = md5.convert(bytes);
    return '$hash.jpg';
  }

  /// Get the local file path for a cached artwork (null if not cached)
  static Future<File?> getCachedArtworkFile(String url) async {
    final cacheDir = await getArtworkCacheDirectory();
    final filename = _urlToFilename(url);
    final file = File('${cacheDir.path}/$filename');

    if (await file.exists()) {
      return file;
    }

    return null;
  }

  /// Check if artwork is already cached
  static Future<bool> isArtworkCached(String url) async {
    final file = await getCachedArtworkFile(url);
    return file != null;
  }

  /// Download artwork from URL and cache it locally
  /// Returns the cached file on success, null on failure
  /// Optional onProgress callback provides download progress (0.0 to 1.0)
  static Future<File?> downloadArtwork(
    String url, {
    Function(double)? onProgress,
  }) async {
    try {
      // Check if already cached
      final existing = await getCachedArtworkFile(url);
      if (existing != null) {
        onProgress?.call(1.0);
        return existing;
      }

      // Download the image
      final request = http.Request('GET', Uri.parse(url));
      request.headers['User-Agent'] = userAgent;

      final streamedResponse = await http.Client().send(request);

      if (streamedResponse.statusCode != 200) {
        print('Failed to download artwork: HTTP ${streamedResponse.statusCode}');
        return null;
      }

      // Get content length for progress tracking
      final contentLength = streamedResponse.contentLength ?? 0;

      // Collect the response bytes
      final bytes = <int>[];
      await for (var chunk in streamedResponse.stream) {
        bytes.addAll(chunk);
        if (contentLength > 0 && onProgress != null) {
          onProgress(bytes.length / contentLength);
        }
      }

      // Save to cache
      final cacheDir = await getArtworkCacheDirectory();
      final filename = _urlToFilename(url);
      final file = File('${cacheDir.path}/$filename');

      await file.writeAsBytes(bytes);

      onProgress?.call(1.0);
      return file;

    } catch (e) {
      print('Error downloading artwork: $e');
      return null;
    }
  }

  /// Delete a specific cached artwork
  static Future<bool> deleteCachedArtwork(String url) async {
    try {
      final file = await getCachedArtworkFile(url);
      if (file != null) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      print('Error deleting cached artwork: $e');
      return false;
    }
  }

  /// Get total size of artwork cache in bytes
  static Future<int> getTotalCacheSize() async {
    try {
      final cacheDir = await getArtworkCacheDirectory();

      if (!await cacheDir.exists()) {
        return 0;
      }

      int totalSize = 0;
      await for (var entity in cacheDir.list()) {
        if (entity is File) {
          final stat = await entity.stat();
          totalSize += stat.size;
        }
      }

      return totalSize;
    } catch (e) {
      print('Error calculating cache size: $e');
      return 0;
    }
  }

  /// Clear all cached artwork
  static Future<bool> clearAllArtwork() async {
    try {
      final cacheDir = await getArtworkCacheDirectory();

      if (!await cacheDir.exists()) {
        return true;
      }

      await for (var entity in cacheDir.list()) {
        if (entity is File) {
          await entity.delete();
        }
      }

      return true;
    } catch (e) {
      print('Error clearing artwork cache: $e');
      return false;
    }
  }

  /// Format cache size in human-readable format (e.g., "2.5 MB")
  static String formatCacheSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      final kb = bytes / 1024;
      return '${kb.toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      final mb = bytes / (1024 * 1024);
      return '${mb.toStringAsFixed(1)} MB';
    } else {
      final gb = bytes / (1024 * 1024 * 1024);
      return '${gb.toStringAsFixed(1)} GB';
    }
  }

  /// Crop artwork to remove card border and text areas
  /// Crop percentages: 8.8% left/right, 14.5% top, 36.8% bottom
  /// This is applied on-the-fly during display, not during download
  static Map<String, double> getCropPercentages() {
    return {
      'left': 0.088,
      'right': 0.088,
      'top': 0.145,
      'bottom': 0.368,
    };
  }
}
