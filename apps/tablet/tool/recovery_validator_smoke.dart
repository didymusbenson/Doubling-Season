// Standalone VM/JavaScript regression harness for the dormant validator API.
// From apps/tablet, with dependencies already resolved:
// dart compile js --packages=.dart_tool/package_config.json \
//   tool/recovery_validator_smoke.dart -o /tmp/recovery_validator_smoke.js
// node -e "globalThis.self=globalThis;require('/tmp/recovery_validator_smoke.js')"
// All artifacts are in-memory. This never opens stores or activates migration.
import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:tripling_table/migration/legacy_recovery_validator.dart';

List<Map<String, Object?>> _records({bool partial = false}) => [
  {
    'format': 'tripling-season-migration-recovery-stream',
    'version': 2,
    'capturedAt': '2026-11-10T00:00:00.000Z',
    'scope': 'inert evidence',
    'chunkBytes': 49152,
  },
  {
    'type': 'source',
    'name': 'isolated',
    'excludedTopLevelLockFiles': <String>[],
    'coordinationAliases': 'metadata only',
  },
  {
    'type': 'entry',
    'key': 'marker.json',
    'kind': 'file',
    'length': partial ? 1 : 3,
  },
  {'type': 'chunk', 'data': 'AQID'},
  {
    'type': 'end_entry',
    'bytes': 3,
    'sha256': sha256.convert([1, 2, 3]).toString(),
    'readable': !partial,
  },
  {'type': 'end_source', 'stableDuringRead': true},
  {
    'type': 'summary',
    'complete': !partial,
    'entries': 1,
    'problems': partial
        ? ['isolated: 1 entries incompletely read.']
        : <String>[],
  },
];

List<int> _seal(List<Map<String, Object?>> records) =>
    _sealText('${records.map(jsonEncode).join('\n')}\n');

List<int> _sealText(String body) => utf8.encode(
  '$body${jsonEncode({'type': 'checksum', 'sha256': sha256.convert(utf8.encode(body)).toString()})}\n',
);

void _require(bool condition, String name) {
  if (!condition) throw StateError(name);
}

Future<void> _refuses(
  List<int> data,
  String name, {
  String? reason,
  LegacyRecoveryValidationLimits limits =
      const LegacyRecoveryValidationLimits(),
}) async {
  try {
    await LegacyRecoveryValidator.validate(Stream.value(data), limits: limits);
  } on FormatException catch (error) {
    _require(
      reason == null || error.message.contains(reason),
      '$name: wrong rejection reason',
    );
    return;
  }
  throw StateError('Accepted $name');
}

Future<void> main() async {
  var checks = 0;
  final original = _seal(_records());
  final complete = await LegacyRecoveryValidator.validate(
    Stream.fromIterable(original.map((byte) => [byte])),
  );
  _require(
    complete.complete && complete.entries == 1 && complete.payloadBytes == 3,
    'complete',
  );
  checks++;
  final partial = await LegacyRecoveryValidator.validate(
    Stream.value(_seal(_records(partial: true))),
  );
  _require(
    !partial.complete &&
        partial.incompleteFiles == 1 &&
        partial.payloadBytes == 3,
    'partial growth',
  );
  checks++;
  await _refuses([...original, 10], 'trailing bytes', reason: 'Trailing bytes');
  checks++;
  await _refuses(
    utf8.encode(
      utf8.decode(original).replaceFirst('inert evidence', 'other evidence'),
    ),
    'whole-stream digest',
    reason: 'Stream integrity',
  );
  checks++;
  final badDigest = _records();
  badDigest[4]['sha256'] = '0' * 64;
  await _refuses(_seal(badDigest), 'file digest', reason: 'File integrity');
  checks++;
  final traversal = _records();
  traversal[2]['key'] = '../active';
  await _refuses(_seal(traversal), 'traversal', reason: 'Unsafe path');
  checks++;
  await _refuses(
    original,
    'line limit',
    limits: const LegacyRecoveryValidationLimits(maxLineBytes: 10),
    reason: 'Line limit',
  );
  checks++;
  final cancellation = LegacyRecoveryValidationCancellation();
  final stalled = StreamController<List<int>>();
  final pending = LegacyRecoveryValidator.validate(
    stalled.stream,
    cancellation: cancellation,
  );
  cancellation.cancel();
  try {
    await pending;
    throw StateError('Cancellation failed');
  } on LegacyRecoveryValidationCancelled {
    checks++;
  } finally {
    await stalled.close();
  }

  // Dart on JS can consider 2.0/2e0 integers and round unsafe large values.
  // Build raw tokens, never jsonEncode(double), to exercise the original syntax.
  final body = '${_records().map(jsonEncode).join('\n')}\n';
  for (final field in {
    'version': 2,
    'chunkBytes': 49152,
    'length': 3,
    'bytes': 3,
    'entries': 1,
  }.entries) {
    final needle = '"${field.key}":${field.value}';
    _require(body.contains(needle), 'Missing numeric fixture ${field.key}');
    for (final token in [
      '${field.value}.0',
      '${field.value}e0',
      '-0',
      '9007199254740992',
      '9007199254740993',
      '0${field.value}',
    ]) {
      await _refuses(
        _sealText(body.replaceFirst(needle, '"${field.key}":$token')),
        '${field.key}=$token',
        reason: 'Noncanonical integer token',
      );
      checks++;
    }
  }
  final inert = _records();
  inert[0]['scope'] = '2.0 2e0 -0 9007199254740993';
  _require(
    (await LegacyRecoveryValidator.validate(
      Stream.value(_seal(inert)),
    )).complete,
    'numeric strings remain inert',
  );
  checks++;
  // CLI harness output must also work in compiled JavaScript without dart:io.
  // ignore: avoid_print
  print('PASS: $checks standalone recovery validator checks');
}
