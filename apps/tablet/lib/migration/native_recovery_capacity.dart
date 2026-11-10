import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Read-only capacity probe for an explicitly chosen, existing destination.
///
/// Pass [availableBytes] to LegacyRecoveryExportBudget. This does not select a
/// destination, reserve space, request permissions, or activate migration.
/// Unsupported platforms, invalid paths, and all probe failures return null.
class NativeRecoveryCapacity {
  static const channelName = 'com.loosetie.triplingtable/recovery_capacity';
  final MethodChannel _channel;

  const NativeRecoveryCapacity({
    MethodChannel channel = const MethodChannel(channelName),
  }) : _channel = channel;

  Future<int?> availableBytes(Directory destination) async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return null;
    }
    try {
      final path = destination.path;
      // Never turn relative paths or file/content URIs into implicit locations.
      if (!path.startsWith('/') || path.contains('\u0000')) return null;
      if (await FileSystemEntity.type(path, followLinks: false) !=
          FileSystemEntityType.directory) {
        return null;
      }
      final canonical = await destination.resolveSymbolicLinks();
      final response = await _channel.invokeMethod<Object?>(
        'availableBytes',
        <String, Object>{'path': canonical},
      );
      if (response is! Map || response['path'] != canonical) return null;
      final bytes = response['availableBytes'];
      if (bytes is! int || bytes < 0 || bytes > 0x7fffffffffffffff) {
        return null;
      }
      // Reject a directory that vanished or was replaced with a link while the
      // probe ran. This narrows races; it cannot reserve or lock a filesystem.
      if (await FileSystemEntity.type(path, followLinks: false) !=
              FileSystemEntityType.directory ||
          await destination.resolveSymbolicLinks() != canonical) {
        return null;
      }
      return bytes;
    } catch (_) {
      return null;
    }
  }
}
