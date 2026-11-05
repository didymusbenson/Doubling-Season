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
  final Map<String, Uint8List> _resolved = {};
  String _key(String source, String? fallback) => '$source|${fallback ?? ''}';
  int get cachedCount => _loads.length;
  bool failed(String source) => _failures.containsKey(_key(source, null));

  /// Stable bytes for a fresh renderer, without an asynchronous waiting frame.
  /// A validated source also satisfies a new derivative/fallback policy.
  Uint8List? peek(String source, {String? fallback}) =>
      _resolved[_key(source, fallback)] ?? _resolved[_key(source, null)];

  void evict(String source, {String? fallback}) {
    final key = _key(source, fallback);
    _loads.remove(key);
    _failures.remove(key);
    _resolved.remove(key);
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
      _resolved.remove(oldest);
    }
    late final Future<Uint8List> result;
    result = Future<Uint8List>.microtask(() async {
      try {
        Uint8List bytes;
        if (fallback == null || fallback == source) {
          bytes = await loadBytes(source);
        } else {
          try {
            // Reuse the exact source bytes already fetched for validation, even
            // when rendering also specifies a derivative fallback policy.
            bytes = await load(source);
          } catch (_) {
            bytes = await load(fallback);
          }
        }
        // A request may finish after eviction or replacement. It must not
        // resurrect stale bytes or bypass the cache's capacity limit.
        if (identical(_loads[key], result)) _resolved[key] = bytes;
        return bytes;
      } catch (_) {
        if (identical(_loads[key], result)) _failures[key] = now();
        rethrow;
      }
    });
    _loads[key] = result;
    return result;
  }
}
