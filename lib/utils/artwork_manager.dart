import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Manages downloading and caching of token artwork from Scryfall CDN
class ArtworkManager {
  /// User-Agent header for good etiquette when downloading from Scryfall
  static const String userAgent = 'DoublingSeason/1.0';

  /// Get the artwork cache directory path
  static Future<Directory> getArtworkCacheDirectory() async {
    if (kIsWeb) {
      // Web doesn't support file system access
      throw UnsupportedError('File system caching not available on web platform');
    }

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
    if (kIsWeb) {
      // Web doesn't support file caching - images load directly from network
      return null;
    }

    // Handle custom artwork (file:// URLs) - already local
    if (url.startsWith('file://')) {
      final localPath = url.replaceFirst('file://', '');
      final file = File(localPath);
      if (await file.exists()) {
        return file;
      }
      return null;
    }

    // Handle Scryfall URLs - check cache directory
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
    if (kIsWeb) {
      // Web doesn't support file caching - images load directly from network
      // Signal completion for progress callbacks
      onProgress?.call(1.0);
      return null;
    }

    // Safety check: Skip file:// URLs (custom artwork is already local)
    if (url.startsWith('file://')) {
      debugPrint('Skipping download for local file:// URL');
      return null;
    }

    // Check if already cached
    final existing = await getCachedArtworkFile(url);
    if (existing != null) {
      onProgress?.call(1.0);
      return existing;
    }

    final client = http.Client();
    try {
      // Download the image
      final request = http.Request('GET', Uri.parse(url));
      request.headers['User-Agent'] = userAgent;

      final streamedResponse = await client.send(request);

      if (streamedResponse.statusCode != 200) {
        if (kDebugMode) {
          print('Failed to download artwork: HTTP ${streamedResponse.statusCode}');
        }
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
      if (kDebugMode) {
        print('Error downloading artwork: $e');
      }
      return null;
    } finally {
      client.close();
    }
  }

  /// Delete a specific cached artwork
  static Future<bool> deleteCachedArtwork(String url) async {
    if (kIsWeb) {
      // Web doesn't support file caching - nothing to delete
      return false;
    }

    try {
      final file = await getCachedArtworkFile(url);
      if (file != null) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting cached artwork: $e');
      }
      return false;
    }
  }

  /// Get total size of artwork cache in bytes
  static Future<int> getTotalCacheSize() async {
    if (kIsWeb) {
      // Web doesn't support file caching - cache size is always 0
      return 0;
    }

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
      if (kDebugMode) {
        print('Error calculating cache size: $e');
      }
      return 0;
    }
  }

  /// Clear all cached artwork
  static Future<bool> clearAllArtwork() async {
    if (kIsWeb) {
      // Web doesn't support file caching - nothing to clear
      return true;
    }

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
      if (kDebugMode) {
        print('Error clearing artwork cache: $e');
      }
      return false;
    }
  }

  /// Get the custom uploads directory (user-imported artwork for tokens)
  static Future<Directory> getCustomUploadsDirectory() async {
    if (kIsWeb) {
      throw UnsupportedError('File system not available on web platform');
    }
    final appDir = await getApplicationDocumentsDirectory();
    final customDir = Directory('${appDir.path}/custom_artwork');
    if (!await customDir.exists()) {
      await customDir.create(recursive: true);
    }
    return customDir;
  }

  /// Get total size of custom uploaded artwork in bytes
  /// Includes both custom token artwork and deck box images
  static Future<int> getCustomUploadsSize() async {
    if (kIsWeb) return 0;

    try {
      int totalSize = 0;

      // Custom token artwork
      final customDir = await getCustomUploadsDirectory();
      if (await customDir.exists()) {
        await for (var entity in customDir.list()) {
          if (entity is File) {
            totalSize += (await entity.stat()).size;
          }
        }
      }

      // Deck box images (stored in artwork cache as deck_box_*.png)
      final cacheDir = await getArtworkCacheDirectory();
      if (await cacheDir.exists()) {
        await for (var entity in cacheDir.list()) {
          if (entity is File && entity.path.contains('deck_box_')) {
            totalSize += (await entity.stat()).size;
          }
        }
      }

      return totalSize;
    } catch (e) {
      if (kDebugMode) {
        print('Error calculating custom uploads size: $e');
      }
      return 0;
    }
  }

  /// Clear all custom uploaded artwork (token uploads and deck box images)
  static Future<bool> clearCustomUploads() async {
    if (kIsWeb) return true;

    try {
      // Clear custom token artwork
      final customDir = await getCustomUploadsDirectory();
      if (await customDir.exists()) {
        await for (var entity in customDir.list()) {
          if (entity is File) {
            await entity.delete();
          }
        }
      }

      // Clear deck box images from artwork cache
      final cacheDir = await getArtworkCacheDirectory();
      if (await cacheDir.exists()) {
        await for (var entity in cacheDir.list()) {
          if (entity is File && entity.path.contains('deck_box_')) {
            await entity.delete();
          }
        }
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error clearing custom uploads: $e');
      }
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

  /// Maximum dimension (width or height) for custom artwork images.
  /// Exceeds Scryfall art_crop quality (~626px) with headroom.
  /// Reduces per-image from potentially 2-8MB to ~100-200KB.
  static const int maxCustomArtworkDimension = 768;

  /// Resize an image file so its longest edge is at most [maxDimension] pixels.
  /// Maintains aspect ratio. If both dimensions are already within the limit,
  /// returns the original file unchanged. Outputs as JPEG for smaller file size.
  /// On failure, returns the original file (graceful fallback).
  static Future<File> resizeImageFile(
    File imageFile, {
    int maxDimension = maxCustomArtworkDimension,
  }) async {
    try {
      final bytes = await imageFile.readAsBytes();

      // Decode just enough to get dimensions
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final originalImage = frame.image;

      final int originalWidth = originalImage.width;
      final int originalHeight = originalImage.height;

      // Skip resize if already within limits
      if (originalWidth <= maxDimension && originalHeight <= maxDimension) {
        originalImage.dispose();
        debugPrint('Image already within size limit: ${originalWidth}x$originalHeight');
        return imageFile;
      }

      // Calculate target dimensions maintaining aspect ratio
      final double scaleFactor;
      if (originalWidth >= originalHeight) {
        // Width is the longest edge
        scaleFactor = maxDimension / originalWidth;
      } else {
        // Height is the longest edge
        scaleFactor = maxDimension / originalHeight;
      }

      final int targetWidth = (originalWidth * scaleFactor).round();
      final int targetHeight = (originalHeight * scaleFactor).round();

      originalImage.dispose();

      // Re-decode at target size (efficient — decodes directly to target resolution)
      final resizedCodec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: targetWidth,
        targetHeight: targetHeight,
      );
      final resizedFrame = await resizedCodec.getNextFrame();
      final resizedImage = resizedFrame.image;

      // Encode as PNG (dart:ui only supports PNG via toByteData)
      final byteData = await resizedImage.toByteData(
        format: ui.ImageByteFormat.png,
      );
      resizedImage.dispose();

      if (byteData == null) {
        debugPrint('Failed to encode resized image — using original');
        return imageFile;
      }

      // Write resized image back to the same file path
      final resizedBytes = byteData.buffer.asUint8List();
      await imageFile.writeAsBytes(resizedBytes);

      debugPrint(
        'Resized custom artwork: ${originalWidth}x$originalHeight -> ${targetWidth}x$targetHeight '
        '(${bytes.length} bytes -> ${resizedBytes.length} bytes)',
      );

      return imageFile;
    } catch (e) {
      // Graceful fallback: if resize fails for any reason, use the original
      debugPrint('Failed to resize image, using original: $e');
      return imageFile;
    }
  }

  /// Crop artwork to remove card border and text areas
  /// For Scryfall artwork: 8.8% left/right, 14.5% top, 36.8% bottom
  /// For custom artwork (file:// URLs): No cropping (0% on all sides)
  /// This is applied on-the-fly during display, not during download
  static Map<String, double> getCropPercentages([String? artworkUrl]) {
    // Custom artwork should not be cropped (user already cropped it before upload)
    if (artworkUrl != null && artworkUrl.startsWith('file://')) {
      return {
        'left': 0.0,
        'right': 0.0,
        'top': 0.0,
        'bottom': 0.0,
      };
    }

    // Scryfall artwork uses standard crop percentages
    return {
      'left': 0.088,
      'right': 0.088,
      'top': 0.145,
      'bottom': 0.368,
    };
  }
}
