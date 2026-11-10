import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Limits apply before decoding a line and while consuming payloads. The caller
/// owns the upstream stream's allocation and cancellation behavior.
class LegacyRecoveryValidationLimits {
  final int maxStreamBytes,
      maxLineBytes,
      maxEntries,
      maxSources,
      maxStreamEvents;
  final int maxMetadataBytes, maxFileBytes, maxPayloadBytes;
  final Duration timeout;
  const LegacyRecoveryValidationLimits({
    this.maxStreamBytes = 8 * 1024 * 1024 * 1024,
    this.maxLineBytes = 512 * 1024,
    this.maxEntries = 10000,
    this.maxSources = 32,
    this.maxStreamEvents = 1000000,
    this.maxMetadataBytes = 4 * 1024 * 1024,
    this.maxFileBytes = 4 * 1024 * 1024 * 1024,
    this.maxPayloadBytes = 6 * 1024 * 1024 * 1024,
    this.timeout = const Duration(minutes: 10),
  });
}

class LegacyRecoveryValidationCancelled implements Exception {
  const LegacyRecoveryValidationCancelled();
}

class LegacyRecoveryValidationCancellation {
  bool _cancelled = false;
  final _listeners = <void Function()>{};
  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    for (final listener in _listeners.toList()) {
      listener();
    }
    _listeners.clear();
  }
}

/// Successful validation establishes internal consistency, NOT authenticity,
/// restore safety, snapshot consistency, or permission to migrate. Even a
/// complete artifact excludes coordination bytes and unlisted stores. All
/// markers, names, paths, and link targets remain untrusted inert evidence.
class LegacyRecoveryValidationResult {
  final bool complete;
  final int sources, entries, files, metadataOnlyEntries, unavailableEntries;
  final int incompleteFiles, unstableSources, payloadBytes;
  final String sha256Digest;
  const LegacyRecoveryValidationResult._({
    required this.complete,
    required this.sources,
    required this.entries,
    required this.files,
    required this.metadataOnlyEntries,
    required this.unavailableEntries,
    required this.incompleteFiles,
    required this.unstableSources,
    required this.payloadBytes,
    required this.sha256Digest,
  });
}

/// Standalone read-only validator. Never opens paths, Hive, or a destination.
/// Rejects nonportable path names rather than promising that they can be safely
/// restored. Unicode normalization/case-folding collisions are not exhaustively
/// detected; some genuine exporter paths are deliberately unsupported. A validation error never returns a usable partial success result.
class LegacyRecoveryValidator {
  static Future<LegacyRecoveryValidationResult> validate(
    Stream<List<int>> input, {
    LegacyRecoveryValidationLimits limits =
        const LegacyRecoveryValidationLimits(),
    LegacyRecoveryValidationCancellation? cancellation,
  }) async {
    if ([
          limits.maxStreamBytes,
          limits.maxLineBytes,
          limits.maxEntries,
          limits.maxSources,
          limits.maxStreamEvents,
          limits.maxMetadataBytes,
          limits.maxFileBytes,
          limits.maxPayloadBytes,
        ].any((n) => n < 1) ||
        limits.timeout <= Duration.zero) {
      throw ArgumentError('Validation limits must be positive.');
    }
    final state = _Validator(limits);
    final watch = Stopwatch()..start();
    var stopped = false;
    void check() {
      if (stopped || (cancellation?._cancelled ?? false)) {
        throw const LegacyRecoveryValidationCancelled();
      }
      if (watch.elapsed >= limits.timeout) {
        throw TimeoutException('Recovery validation timed out.');
      }
    }

    final iterator = StreamIterator<List<int>>(input);
    var line = <int>[];
    var total = 0;
    final cancelled = Completer<LegacyRecoveryValidationResult>();
    void onCancel() =>
        cancelled.completeError(const LegacyRecoveryValidationCancelled());
    cancellation?._listeners.add(onCancel);
    var events = 0;
    Future<LegacyRecoveryValidationResult> consume() async {
      while (true) {
        check();
        final more = await iterator.moveNext();
        check();
        if (!more) break;
        if (++events > limits.maxStreamEvents) _bad('Event limit');
        for (final byte in iterator.current) {
          if (total % 4096 == 0) check();
          if (++total > limits.maxStreamBytes) _bad('Stream limit');
          if (byte < 0 || byte > 255) _bad('Invalid byte');
          if (state.done) _bad('Trailing bytes');
          if (byte == 10) {
            check();
            state.accept(line);
            line = <int>[];
          } else {
            if (line.length >= limits.maxLineBytes) _bad('Line limit');
            line.add(byte);
          }
        }
      }
      check();
      if (line.isNotEmpty || !state.done) _bad('Truncated stream');
      return state.result();
    }

    try {
      return await Future.any<LegacyRecoveryValidationResult>([
        consume(),
        if (cancellation != null) cancelled.future,
      ]).timeout(limits.timeout);
    } finally {
      stopped = true;
      cancellation?._listeners.remove(onCancel);
      watch.stop();
      // StreamIterator cancels on error/EOF too. A hostile upstream can refuse
      // cleanup; do not allow it to defeat the validator's bounded wait.
      unawaited(iterator.cancel().catchError((Object _) {}));
    }
  }
}

Never _bad(String reason) =>
    throw FormatException('Recovery validation: $reason.');

class _Validator {
  final LegacyRecoveryValidationLimits limits;
  final _hash = _Hash();
  final _names = <String>{};
  Set<String> exclusions = {};
  final _paths = <String, String>{};
  final _parents = <String>{};
  final _spellings = <String, String>{};
  int pathStorageBytes = 0;
  final _problems = <String>[];
  String phase = 'header', name = '', kind = '', checksum = '';
  String? previousKey;
  int entries = 0, files = 0, metadata = 0, unavailable = 0, incomplete = 0;
  int unstable = 0, payload = 0, metadataBytes = 0, length = 0, count = 0;
  int sourceUnavailable = 0, sourceIncomplete = 0;
  _Hash? fileHash;
  bool complete = false;
  _Validator(this.limits);
  bool get done => phase == 'done';

  void accept(List<int> raw) {
    // Reject nesting and duplicate keys before permissive jsonDecode can erase
    // evidence. The v2 schema has only a flat object and arrays of strings.
    final text = utf8.decode(raw, allowMalformed: false);
    final value = _StrictRecord(text).read();
    final type = value['type'];
    if (type != 'chunk') {
      metadataBytes += raw.length;
      if (metadataBytes > limits.maxMetadataBytes) _bad('Metadata limit');
    }
    if (phase == 'header') {
      _schema(value, 'format version capturedAt scope chunkBytes');
      if (value['format'] != 'tripling-season-migration-recovery-stream' ||
          value['version'] is! int ||
          value['version'] != 2 ||
          value['chunkBytes'] is! int ||
          value['chunkBytes'] != 49152) {
        _bad('Header');
      }
      final date = _string(value, 'capturedAt', 64);
      if (!date.endsWith('Z') ||
          DateTime.tryParse(date)?.toUtc().toIso8601String() != date) {
        _bad('Capture time');
      }
      _string(value, 'scope', 1024);
      phase = 'source';
    } else if (phase == 'source' && type == 'source') {
      _schema(value, 'type name excludedTopLevelLockFiles coordinationAliases');
      name = _string(value, 'name', 256);
      if (!_names.add(name) || _names.length > limits.maxSources) {
        _bad('Source names');
      }
      final excluded = _strings(value, 'excludedTopLevelLockFiles', 128, 4096);
      if (utf8.encode(jsonEncode(excluded)).length > 16 * 1024 ||
          jsonEncode(excluded) != jsonEncode(excluded.toList()..sort()) ||
          excluded.toSet().length != excluded.length) {
        _bad('Duplicate excluded');
      }
      for (final key in excluded) {
        _path(key);
        if (key.contains('/') || !key.endsWith('.lock')) _bad('Lock exclusion');
      }
      exclusions = excluded.toSet();
      _string(value, 'coordinationAliases', 1024);
      _paths.clear();
      _parents.clear();
      _spellings.clear();
      previousKey = null;
      sourceUnavailable = 0;
      sourceIncomplete = 0;
      phase = 'entry';
    } else if (phase == 'entry' && type == 'entry') {
      kind = _string(value, 'kind', 32);
      _schema(
        value,
        'type key kind${kind == 'file'
            ? ' length'
            : (kind == 'link' || kind == 'coordination-alias')
            ? ' target'
            : ''}',
      );
      final key = _string(value, 'key', 4096);
      _path(key);
      if (previousKey != null && previousKey!.compareTo(key) >= 0) {
        _bad('Entry order');
      }
      previousKey = key;
      final folded = key.toLowerCase();
      if (_paths.containsKey(folded) ||
          (_parents.contains(folded) &&
              kind != 'directory' &&
              kind != 'unavailable')) {
        _bad('Path collision');
      }
      final parts = folded.split('/');
      final originalParts = key.split('/');
      if (parts.length > 64) _bad('Path depth');
      for (var i = 1; i <= parts.length; i++) {
        final prefix = parts.take(i).join('/');
        final spelling = originalParts.take(i).join('/');
        final prior = _spellings[prefix];
        if (prior != null && prior != spelling) _bad('Path case collision');
        if (prior == null) {
          pathStorageBytes +=
              utf8.encode(prefix).length + utf8.encode(spelling).length;
          if (pathStorageBytes > limits.maxMetadataBytes) {
            _bad('Path storage limit');
          }
          _spellings[prefix] = spelling;
        }
      }
      for (var i = 1; i < parts.length; i++) {
        final parent = parts.take(i).join('/');
        if (_paths.containsKey(parent) &&
            _paths[parent] != 'directory' &&
            _paths[parent] != 'unavailable') {
          _bad('Non-directory ancestor');
        }
        _parents.add(parent);
      }
      _paths[folded] = kind;
      if (++entries > limits.maxEntries) _bad('Entry limit');
      count = 0;
      length = 0;
      fileHash = _Hash();
      switch (kind) {
        case 'file':
          if (exclusions.contains(key)) _bad('Excluded file payload');
          files++;
          length = _integer(value, 'length', limits.maxFileBytes);
        case 'directory':
          metadata++;
        case 'link':
        case 'coordination-alias':
          _string(value, 'target', 64 * 1024, empty: true);
          metadata++;
        case 'unavailable':
          break;
        default:
          _bad('Entry kind');
      }
      phase = kind == 'unavailable' ? 'unavailable' : 'content';
    } else if (phase == 'unavailable' && type == 'unavailable') {
      _schema(value, 'type');
      unavailable++;
      sourceUnavailable++;
      phase = 'entry';
    } else if (phase == 'content' && type == 'chunk' && kind == 'file') {
      _schema(value, 'type data');
      final data = _string(value, 'data', 65536);
      final bytes = base64Decode(data);
      if (bytes.isEmpty ||
          bytes.length > 49152 ||
          base64Encode(bytes) != data) {
        _bad('Chunk encoding');
      }
      count += bytes.length;
      payload += bytes.length;
      if (count > limits.maxFileBytes || payload > limits.maxPayloadBytes) {
        _bad('Payload limit');
      }
      fileHash!.addBytes(bytes);
    } else if (phase == 'content' && type == 'end_entry') {
      _schema(value, 'type bytes sha256 readable');
      if (_integer(value, 'bytes', limits.maxFileBytes) != count ||
          _digest(value) != fileHash!.finish()) {
        _bad('File integrity');
      }
      final readable = _boolean(value, 'readable');
      if (kind != 'file' && (!readable || count != 0)) _bad('Metadata payload');
      if (readable && count != length) _bad('File length');
      if (!readable) {
        incomplete++;
        sourceIncomplete++;
      }
      fileHash = null;
      phase = 'entry';
    } else if (phase == 'entry' && type == 'end_source') {
      _schema(value, 'type stableDuringRead');
      if (!_boolean(value, 'stableDuringRead')) {
        unstable++;
        _problems.add('$name: evidence changed or could not be rechecked.');
      }
      if (sourceUnavailable > 0) {
        _problems.add('$name: $sourceUnavailable entries unavailable.');
      }
      if (sourceIncomplete > 0) {
        _problems.add('$name: $sourceIncomplete entries incompletely read.');
      }
      phase = 'source';
    } else if (phase == 'source' && type == 'summary' && _names.isNotEmpty) {
      _schema(value, 'type complete entries problems');
      complete = _boolean(value, 'complete');
      final problems = _strings(value, 'problems', limits.maxSources * 3, 1024);
      if (_integer(value, 'entries', limits.maxEntries) != entries ||
          complete != _problems.isEmpty ||
          jsonEncode(problems) != jsonEncode(_problems)) {
        _bad('Summary');
      }
      phase = 'checksum';
    } else if (phase == 'checksum' && type == 'checksum') {
      _schema(value, 'type sha256');
      checksum = _digest(value);
      if (checksum != _hash.finish()) _bad('Stream integrity');
      phase = 'done';
      return;
    } else {
      _bad('Record order');
    }
    _hash.addBytes(raw);
    _hash.addBytes(const [10]);
  }

  LegacyRecoveryValidationResult result() => LegacyRecoveryValidationResult._(
    complete: complete,
    sources: _names.length,
    entries: entries,
    files: files,
    metadataOnlyEntries: metadata,
    unavailableEntries: unavailable,
    incompleteFiles: incomplete,
    unstableSources: unstable,
    payloadBytes: payload,
    sha256Digest: checksum,
  );
}

void _schema(Map<String, dynamic> m, String fields) {
  final keys = fields.split(' ').toSet();
  if (m.length != keys.length || !m.keys.every(keys.contains)) {
    _bad('Record schema');
  }
}

String _string(
  Map<String, dynamic> m,
  String k,
  int max, {
  bool empty = false,
}) {
  final v = m[k];
  if (v is! String || (!empty && v.isEmpty) || utf8.encode(v).length > max) {
    _bad('String field');
  }
  // Reject lone UTF-16 surrogates, which otherwise collapse on UTF-8 encoding.
  if (utf8.decode(utf8.encode(v)) != v) _bad('Unicode string');
  return v;
}

int _integer(Map<String, dynamic> m, String k, int max) {
  final v = m[k];
  if (v is! int || v < 0 || v > max) _bad('Integer field');
  return v;
}

bool _boolean(Map<String, dynamic> m, String k) {
  final v = m[k];
  if (v is! bool) _bad('Boolean field');
  return v;
}

List<String> _strings(Map<String, dynamic> m, String k, int max, int bytes) {
  final v = m[k];
  if (v is! List || v.length > max) _bad('Array field');
  return [
    for (final item in v) _string({'v': item}, 'v', bytes),
  ];
}

String _digest(Map<String, dynamic> m) {
  final s = _string(m, 'sha256', 64);
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(s)) _bad('Digest');
  return s;
}

void _path(String key) {
  if (key.contains(RegExp(r'[\\:\x00-\x1f\x7f]'))) _bad('Unsafe path');
  for (final part in key.split('/')) {
    if (part.isEmpty ||
        part == '.' ||
        part == '..' ||
        part.endsWith('.') ||
        part.endsWith(' ') ||
        part.contains(RegExp(r'[<>"|?*]')) ||
        RegExp(
          r'^(con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\.|$)',
          caseSensitive: false,
        ).hasMatch(part)) {
      _bad('Unsafe path');
    }
  }
}

/// A tiny structural gate, not a replacement JSON parser. Only top-level object
/// fields and flat arrays of strings are admitted. jsonDecode subsequently
/// checks scalar syntax, escapes, commas, and all remaining JSON grammar.
class _StrictRecord {
  final String text;
  _StrictRecord(this.text);
  Map<String, dynamic> read() {
    final keys = <String>{};
    var objectDepth = 0, arrayDepth = 0;
    var expectKey = false;
    for (var i = 0; i < text.length; i++) {
      final c = text[i];
      if (c == '"') {
        final start = i;
        for (i++; i < text.length; i++) {
          if (text[i] == '\\') {
            i++;
            continue;
          }
          if (text[i] == '"') break;
        }
        if (i >= text.length) _bad('JSON string');
        if (expectKey && arrayDepth == 0) {
          final key = jsonDecode(text.substring(start, i + 1));
          if (key is! String || !keys.add(key)) _bad('Duplicate JSON key');
          expectKey = false;
        }
      } else if (c == '-' || (c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57)) {
        // Dart's JS backend represents whole-valued doubles as int too. Gate
        // the original token so 2.0/2e0 cannot pass an integer schema there.
        // Restrict to the shared exact integer range before jsonDecode rounds.
        final start = i;
        while (i < text.length && !',]} \t\r\n'.contains(text[i])) {
          if (i - start >= 16) _bad('Noncanonical integer token');
          i++;
        }
        final token = text.substring(start, i);
        if (!RegExp(r'^(0|[1-9][0-9]*)$').hasMatch(token) ||
            (token.length == 16 && token.compareTo('9007199254740991') > 0)) {
          _bad('Noncanonical integer token');
        }
        i--;
      } else if (c == '{') {
        if (++objectDepth != 1 || arrayDepth != 0) _bad('Nested object');
        expectKey = true;
      } else if (c == '}') {
        objectDepth--;
      } else if (c == '[') {
        if (++arrayDepth != 1 || objectDepth != 1) _bad('Nested array');
      } else if (c == ']') {
        arrayDepth--;
      } else if (c == ',' && arrayDepth == 0) {
        expectKey = true;
      }
    }
    final decoded = jsonDecode(text);
    if (decoded is! Map<String, dynamic>) _bad('JSON record');
    return decoded;
  }
}

class _Hash implements Sink<Digest> {
  late final ByteConversionSink _sink = sha256.startChunkedConversion(this);
  Digest? _digest;
  void addBytes(List<int> bytes) => _sink.add(bytes);
  @override
  void add(Digest digest) => _digest = digest;
  @override
  void close() {}
  String finish() {
    _sink.close();
    return _digest!.toString();
  }
}
