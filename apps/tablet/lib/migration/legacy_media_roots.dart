/// Resolves old absolute artwork references only against caller-verified roots
/// in an already retained installation copy. Never probes the live filesystem,
/// guesses a container prefix, or falls back to a basename search.
class LegacyMediaRoots {
  final Map<String, String> roots;

  LegacyMediaRoots(Map<String, String> roots)
    : roots = Map.unmodifiable(roots) {
    for (final entry in this.roots.entries) {
      final source = _absoluteSegments(entry.key);
      final target = _relativeSegments(entry.value);
      if (!{'custom_artwork', 'artwork_cache'}.contains(source.last) ||
          target.last != source.last) {
        throw const FormatException('Expected a verified legacy artwork root.');
      }
    }
    final sources = this.roots.keys.toList();
    for (var i = 0; i < sources.length; i++) {
      for (var j = i + 1; j < sources.length; j++) {
        if (sources[i].startsWith('${sources[j]}/') ||
            sources[j].startsWith('${sources[i]}/')) {
          throw const FormatException('Overlapping legacy artwork roots.');
        }
      }
    }
  }

  /// Null means unresolved. Missing/unsupported references stay in the snapshot
  /// so the journal reports them instead of inventing or clearing artwork.
  String? resolve(String reference, Set<String> retainedPaths) {
    try {
      final List<String> segments;
      if (reference.startsWith('file://')) {
        if (RegExp(r'%2f|%5c', caseSensitive: false).hasMatch(reference)) {
          return null;
        }
        final uri = Uri.parse(reference);
        if (uri.scheme != 'file' ||
            uri.hasAuthority && uri.host.isNotEmpty ||
            uri.hasQuery ||
            uri.hasFragment ||
            uri.userInfo.isNotEmpty ||
            uri.hasPort) {
          return null;
        }
        segments = _absoluteSegments(uri.toFilePath());
        // URI parsing must not normalize away traversal evidence.
        final rawPath = reference.substring('file://'.length);
        _absoluteSegments(Uri.decodeComponent(rawPath));
      } else {
        segments = _absoluteSegments(reference);
      }
      for (final entry in roots.entries) {
        final root = _absoluteSegments(entry.key);
        if (segments.length <= root.length) continue;
        if (List.generate(
          root.length,
          (i) => segments[i] == root[i],
        ).any((same) => !same)) {
          continue;
        }
        final candidate =
            '${entry.value}/${segments.skip(root.length).join('/')}';
        return retainedPaths.contains(candidate) ? candidate : null;
      }
    } on FormatException {
      return null;
    } on UnsupportedError {
      return null;
    } on ArgumentError {
      return null;
    }
    return null;
  }
}

List<String> _absoluteSegments(String path) {
  if (!path.startsWith('/')) {
    throw const FormatException('Absolute verified artwork root required.');
  }
  return _relativeSegments(path.substring(1));
}

List<String> _relativeSegments(String path) {
  final parts = path.split('/');
  if (parts.any((part) => part.isEmpty || part == '.' || part == '..') ||
      path.contains('\\') ||
      path.contains(':') ||
      path.contains('\u0000') ||
      path.contains('%')) {
    throw const FormatException('Unsafe artwork path.');
  }
  return parts;
}
