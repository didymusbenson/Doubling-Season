import '../storage/storage_namespace.dart';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Uploaded images are immutable, content-addressed assets, kept outside the
/// frequently rewritten session aggregate. No automatic reclamation can remove
/// media still referenced by an archive, preset, or another seat.
class TabletMediaStore {
  static Future<Box<dynamic>>? _opening;
  static final Map<String, Uint8List> _cache = {};
  static Future<Box<dynamic>> _box() =>
      _opening ??= Hive.openBox<dynamic>(TableStorageKeys.media);

  static Future<String> save(Uint8List bytes) async {
    if (bytes.isEmpty || bytes.length > 12 * 1024 * 1024) {
      throw const FormatException('Choose an image smaller than 12 MB.');
    }
    final hash = sha256.convert(bytes).toString();
    final box = await _box();
    if (!box.containsKey(hash)) {
      await box.put(hash, bytes);
      await box.flush();
    }
    final reference = 'tablet-art:$hash';
    _cache[reference] = bytes;
    return reference;
  }

  static Future<Uint8List?> read(String reference) async {
    if (_cache.containsKey(reference)) return _cache[reference];
    if (!reference.startsWith('tablet-art:')) return null;
    final stored = (await _box()).get(reference.substring(11));
    final bytes = stored is Uint8List
        ? stored
        : stored is List
        ? Uint8List.fromList(stored.cast<int>())
        : null;
    if (bytes != null) _cache[reference] = bytes;
    return bytes;
  }
}
