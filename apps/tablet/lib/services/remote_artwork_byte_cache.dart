import 'dart:typed_data';

/// Bounded immutable remote bytes, shared by validation and presentation.
/// Failures stay bounded too; retry is explicit or after the cooldown on a
/// subsequent request. No timers/background retry loops are created.
class RemoteArtworkByteCache {
  RemoteArtworkByteCache({
    required this.loadBytes,
    this.capacity = 48,
    this.retryDelay = const Duration(seconds: 30),
    DateTime Function()? now,
  }) : assert(capacity > 0),
       now = now ?? DateTime.now;
  final Future<Uint8List> Function(String) loadBytes;
  final int capacity;
  final Duration retryDelay;
  final DateTime Function() now;
  final Map<String, Future<Uint8List>> _loads = {};
  final Map<String, DateTime> _failures = {};
  String _key(String source, String? fallback) => '$source|${fallback ?? ''}';
  int get cachedCount => _loads.length;
  bool failed(String source) => _failures.containsKey(_key(source, null));

  void evict(String source, {String? fallback}) {
    final key = _key(source, fallback);
    _loads.remove(key);
    _failures.remove(key);
  }

  Future<Uint8List> load(
    String source, {
    String? fallback,
    bool retry = false,
  }) {
    final key = _key(source, fallback);
    final failedAt = _failures[key];
    if (retry ||
        (failedAt != null && now().difference(failedAt) >= retryDelay)) {
      evict(source, fallback: fallback);
    }
    final existing = _loads[key];
    if (existing != null) return existing;
    while (_loads.length >= capacity && _loads.isNotEmpty) {
      final oldest = _loads.keys.first;
      _loads.remove(oldest);
      _failures.remove(oldest);
    }
    late final Future<Uint8List> result;
    result = Future<Uint8List>.microtask(() async {
      try {
        if (fallback == null || fallback == source) {
          return await loadBytes(source);
        }
        try {
          // Reuse the exact source bytes already fetched for validation, even
          // when rendering also specifies a derivative fallback policy.
          return await load(source);
        } catch (_) {
          return await load(fallback);
        }
      } catch (_) {
        if (identical(_loads[key], result)) _failures[key] = now();
        rethrow;
      }
    });
    _loads[key] = result;
    return result;
  }
}
