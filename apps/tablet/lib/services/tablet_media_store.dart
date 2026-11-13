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
    // Own the input before the first await. Neither the caller nor a returned
    // cached buffer may mutate bytes underneath their content-addressed key.
    final owned = Uint8List.fromList(bytes);
    final hash = sha256.convert(owned).toString();
    final reference = 'tablet-art:$hash';
    final box = await _box();
    if (box.containsKey(hash)) {
      if (_verifiedBytes(reference, box.get(hash)) == null) {
        _cache.remove(reference);
        throw StateError('Stored artwork failed integrity verification.');
      }
    } else {
      await box.put(hash, owned);
    }
    // Retry must flush even when an earlier put left a valid in-memory key but
    // its flush failed. Never acknowledge a cache-only repair of corrupt data.
    await box.flush();
    final stored = _verifiedBytes(reference, box.get(hash));
    if (stored == null) {
      _cache.remove(reference);
      throw StateError('Stored artwork failed integrity verification.');
    }
    _cache.putIfAbsent(
      reference,
      () => Uint8List.fromList(stored).asUnmodifiableView(),
    );
    return reference;
  }

  /// Immutable bytes already verified by a read or acknowledged save. The
  /// stable read-only object preserves Flutter's decoded-image identity during
  /// drag/reorder. A presentation cache hit is not persistence evidence; export
  /// explicitly requests a storage-verified read.
  static Uint8List? peek(String reference) => _cache[reference];

  /// Cold or explicitly verified reads return null for missing/corrupt stored
  /// bytes, using the existing artwork placeholder. Export rejects null as
  /// unavailable, without replacing the saved reference
  /// or overwriting/removing the original corrupt storage evidence.
  static Future<Uint8List?> read(
    String reference, {
    bool verifyStored = false,
  }) async {
    if (!reference.startsWith('tablet-art:')) return null;
    // Rendering may reuse a trusted immutable buffer without hashing every
    // image again on every board update. Acceptance/export must opt out.
    if (!verifyStored && _cache.containsKey(reference)) {
      return _cache[reference];
    }
    final bytes = _verifiedBytes(
      reference,
      (await _box()).get(reference.substring(11)),
    );
    if (bytes == null) {
      _cache.remove(reference);
      return null;
    }
    return _cache.putIfAbsent(
      reference,
      () => Uint8List.fromList(bytes).asUnmodifiableView(),
    );
  }

  static Uint8List? _verifiedBytes(String reference, dynamic stored) {
    if (stored is! List || stored.isEmpty || stored.length > 12 * 1024 * 1024) {
      return null;
    }
    final Uint8List bytes;
    if (stored is Uint8List) {
      bytes = stored;
    } else if (stored.every(
      (value) => value is int && value >= 0 && value <= 255,
    )) {
      bytes = Uint8List.fromList(stored.cast<int>());
    } else {
      return null;
    }
    if ('tablet-art:${sha256.convert(bytes)}' != reference) {
      return null;
    }
    return bytes;
  }
}
