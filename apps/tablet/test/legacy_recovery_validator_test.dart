import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/migration/legacy_recovery_export.dart';
import 'package:tripling_table/migration/legacy_recovery_files.dart';
import 'package:tripling_table/migration/legacy_recovery_validator.dart';

List<Map<String, Object?>> records() => [
  {
    'format': LegacyRecoveryExport.format,
    'version': 2,
    'capturedAt': '2026-11-10T00:00:00.000Z',
    'scope': 'inert evidence',
    'chunkBytes': 49152,
  },
  {
    'type': 'source',
    'name': 'source',
    'excludedTopLevelLockFiles': <String>[],
    'coordinationAliases': 'metadata',
  },
  {'type': 'entry', 'key': 'marker.json', 'kind': 'file', 'length': 3},
  {'type': 'chunk', 'data': 'AQID'},
  {
    'type': 'end_entry',
    'bytes': 3,
    'sha256': sha256.convert([1, 2, 3]).toString(),
    'readable': true,
  },
  {'type': 'end_source', 'stableDuringRead': true},
  {'type': 'summary', 'complete': true, 'entries': 1, 'problems': <String>[]},
];
List<int> seal(List<Map<String, Object?>> lines) =>
    sealText('${lines.map(jsonEncode).join('\n')}\n');
List<int> sealText(String body) {
  final bytes = utf8.encode(body);
  return [
    ...bytes,
    ...utf8.encode(
      '${jsonEncode({'type': 'checksum', 'sha256': sha256.convert(bytes).toString()})}\n',
    ),
  ];
}

Future<LegacyRecoveryValidationResult> validate(
  List<int> bytes, {
  LegacyRecoveryValidationLimits limits =
      const LegacyRecoveryValidationLimits(),
}) => LegacyRecoveryValidator.validate(Stream.value(bytes), limits: limits);

class _Partial extends LegacyRecoveryFiles {
  _Partial(super.directory) : super(name: 'partial');
  @override
  Stream<List<int>> readChunks(
    String key, {
    int chunkBytes = 48 * 1024,
    Map<String, String> coordinationFiles = const {},
  }) async* {
    yield [9];
    throw const FileSystemException('unreadable');
  }
}

class _Unstable extends LegacyRecoveryFiles {
  int reads = 0;
  _Unstable(super.directory) : super(name: 'unstable');
  @override
  Stream<List<int>> readChunks(
    String key, {
    int chunkBytes = 48 * 1024,
    Map<String, String> coordinationFiles = const {},
  }) async* {
    yield [++reads];
  }
}

void main() {
  test('independent valid bytes, arbitrary framing, inert marker', () async {
    final bytes = seal(records());
    final result = await LegacyRecoveryValidator.validate(
      Stream.fromIterable(bytes.map((b) => [b])),
    );
    expect(result.complete, isTrue);
    expect(result.files, 1);
    expect(result.payloadBytes, 3);
  });
  test(
    'real exporter round-trip with large file, links, aliases and opaque marker',
    () async {
      final root = await Directory.systemTemp.createTemp('validator-');
      addTearDown(() => root.delete(recursive: true));
      final source = await Directory('${root.path}/source').create();
      final output = await Directory('${root.path}/output').create();
      await Directory('${source.path}/folder').create();
      await File(
        '${source.path}/folder/unknown',
      ).writeAsBytes(List.generate(100000, (i) => i % 256));
      await File('${source.path}/marker.json').writeAsString('{not trusted');
      await File('${source.path}/lease.lock').writeAsString('coordination');
      await Link('${source.path}/link').create('/outside/../never-follow');
      final process = await Process.run('ln', [
        '${source.path}/lease.lock',
        '${source.path}/alias',
      ]);
      expect(process.exitCode, 0);
      final artifact = await LegacyRecoveryExport.write(
        sources: [
          LegacyRecoveryFiles(
            source,
            name: 'source',
            excludedTopLevelLockFiles: {'lease.lock'},
          ),
        ],
        options: LegacyRecoveryExportOptions(
          parent: output,
          budget: LegacyRecoveryExportBudget(
            availableBytes: (_) async => 1 << 40,
          ),
        ),
      );
      final result = await LegacyRecoveryValidator.validate(
        artifact.file.openRead(),
      );
      expect(result.complete, isTrue);
      expect(result.entries, 5);
      expect(result.metadataOnlyEntries, 3);
      expect(
        await File('${source.path}/lease.lock').readAsString(),
        'coordination',
      );
    },
    skip:
        Platform.isWindows, // Uses POSIX ln for a real coordination hard link.
  );
  test('real partial and unstable exporter artifacts remain partial', () async {
    final root = await Directory.systemTemp.createTemp('validator-partial-');
    addTearDown(() => root.delete(recursive: true));
    final source = await Directory('${root.path}/source').create();
    final output = await Directory('${root.path}/output').create();
    await File('${source.path}/data').writeAsBytes([1]);
    for (final input in [_Partial(source), _Unstable(source)]) {
      final artifact = await LegacyRecoveryExport.write(
        sources: [input],
        options: LegacyRecoveryExportOptions(
          parent: output,
          budget: LegacyRecoveryExportBudget(
            availableBytes: (_) async => 1 << 40,
          ),
        ),
      );
      final result = await LegacyRecoveryValidator.validate(
        artifact.file.openRead(),
      );
      expect(result.complete, isFalse);
      if (input is _Partial) expect(result.incompleteFiles, 1);
      if (input is _Unstable) expect(result.unstableSources, 1);
    }
  });
  test(
    'unavailable, metadata only, and longer partial file classify independently',
    () async {
      final lines = records();
      lines[2]['length'] = 1;
      lines[4]['readable'] = false;
      lines.insertAll(5, [
        {'type': 'entry', 'key': 'zmissing', 'kind': 'unavailable'},
        {'type': 'unavailable'},
        {
          'type': 'entry',
          'key': 'zzlink',
          'kind': 'link',
          'target': '../../outside',
        },
        {
          'type': 'end_entry',
          'bytes': 0,
          'sha256': sha256.convert([]).toString(),
          'readable': true,
        },
      ]);
      lines.last.addAll({
        'entries': 3,
        'complete': false,
        'problems': [
          'source: 1 entries unavailable.',
          'source: 1 entries incompletely read.',
        ],
      });
      final result = await validate(seal(lines));
      expect(result.unavailableEntries, 1);
      expect(result.metadataOnlyEntries, 1);
      expect(result.incompleteFiles, 1);
    },
  );
  test(
    'unavailable directory ancestors remain valid partial evidence',
    () async {
      final r = records();
      r.removeRange(2, 5);
      r.insertAll(2, [
        {'type': 'entry', 'key': 'a', 'kind': 'unavailable'},
        {'type': 'unavailable'},
        {'type': 'entry', 'key': 'a/b', 'kind': 'unavailable'},
        {'type': 'unavailable'},
      ]);
      r.last.addAll({
        'entries': 2,
        'complete': false,
        'problems': ['source: 2 entries unavailable.'],
      });
      final result = await validate(seal(r));
      expect(result.unavailableEntries, 2);
      expect(result.complete, false);
    },
  );
  test('maximum escaped link metadata remains bounded and inert', () async {
    final r = records();
    r[2] = {
      'type': 'entry',
      'key': 'link',
      'kind': 'link',
      'target': '\u0000' * 65536,
    };
    r.removeAt(3);
    r[3] = {
      'type': 'end_entry',
      'bytes': 0,
      'sha256': sha256.convert([]).toString(),
      'readable': true,
    };
    expect((await validate(seal(r))).metadataOnlyEntries, 1);
  });
  test(
    'entry/source/path-depth limits and path storage amplification',
    () async {
      final r = records();
      r.insertAll(5, [
        {'type': 'entry', 'key': 'z', 'kind': 'directory'},
        {
          'type': 'end_entry',
          'bytes': 0,
          'sha256': sha256.convert([]).toString(),
          'readable': true,
        },
      ]);
      r.last['entries'] = 2;
      await expectLater(
        validate(
          seal(r),
          limits: const LegacyRecoveryValidationLimits(maxEntries: 1),
        ),
        throwsFormatException,
      );
      final sources = records();
      sources.insertAll(6, [
        {...sources[1], 'name': 'other'},
        sources[5],
      ]);
      await expectLater(
        validate(
          seal(sources),
          limits: const LegacyRecoveryValidationLimits(maxSources: 1),
        ),
        throwsFormatException,
      );
      final deep = records();
      deep[2]['key'] = List.filled(65, 'a').join('/');
      await expectLater(validate(seal(deep)), throwsFormatException);
      final prefixes = records();
      prefixes[2]['key'] = List.filled(60, 'abcdefghij').join('/');
      await expectLater(
        validate(
          seal(prefixes),
          limits: const LegacyRecoveryValidationLimits(maxMetadataBytes: 4096),
        ),
        throwsFormatException,
      );
    },
  );
  test(
    'checksum corruption, chunk bound, exclusion bounds and invalid byte',
    () async {
      final bytes = seal(records());
      final footerStart = bytes.lastIndexOf(10, bytes.length - 2) + 1;
      final footer =
          jsonDecode(utf8.decode(bytes.sublist(footerStart)))
              as Map<String, dynamic>;
      footer['sha256'] = '0' * 64;
      await expectLater(
        validate([
          ...bytes.take(footerStart),
          ...utf8.encode('${jsonEncode(footer)}\n'),
        ]),
        throwsFormatException,
      );
      final oversized = records();
      oversized[3]['data'] = base64Encode(List.filled(49153, 0));
      await expectLater(validate(seal(oversized)), throwsFormatException);
      for (final exclusions in [
        ['b.lock', 'a.lock'],
        ['a.lock', 'a.lock'],
        List.generate(
          128,
          (i) => '${i.toString().padLeft(3, '0')}${'a' * 130}.lock',
        ),
      ]) {
        final r = records();
        r[1]['excludedTopLevelLockFiles'] = exclusions;
        await expectLater(validate(seal(r)), throwsFormatException);
      }
      await expectLater(validate([-1]), throwsFormatException);
      await expectLater(validate([256]), throwsFormatException);
    },
  );
  test('pre-cancelled token and source errors fail without result', () async {
    final cancellation = LegacyRecoveryValidationCancellation()..cancel();
    await expectLater(
      LegacyRecoveryValidator.validate(
        Stream.value(seal(records())),
        cancellation: cancellation,
      ),
      throwsA(isA<LegacyRecoveryValidationCancelled>()),
    );
    await expectLater(
      LegacyRecoveryValidator.validate(
        Stream.error(StateError('source failed')),
      ),
      throwsStateError,
    );
    await expectLater(
      validate(
        seal(records()),
        limits: const LegacyRecoveryValidationLimits(maxEntries: 0),
      ),
      throwsArgumentError,
    );
  });
  test('every truncated prefix and changed metadata fails integrity', () async {
    final bytes = seal(records());
    for (var i = 0; i < bytes.length; i++) {
      await expectLater(validate(bytes.sublist(0, i)), throwsFormatException);
    }
    final changed = utf8.encode(
      utf8.decode(bytes).replaceFirst('inert evidence', 'other evidence'),
    );
    await expectLater(
      validate(changed),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'reason',
          contains('Stream integrity'),
        ),
      ),
    );
  });
  test('excluded exact lock cannot carry regular file bytes', () async {
    final r = records();
    r[1]['excludedTopLevelLockFiles'] = ['lease.lock'];
    r[2]['key'] = 'lease.lock';
    await expectLater(validate(seal(r)), throwsFormatException);
  });
  test(
    'raw integer tokens are canonical and exact on VM and JavaScript',
    () async {
      final body = '${records().map(jsonEncode).join('\n')}\n';
      for (final substitution in [
        ('"version":2', '"version":2.0'),
        ('"version":2', '"version":2e0'),
        ('"version":2', '"version":2E+0'),
        ('"chunkBytes":49152', '"chunkBytes":49152.0'),
        ('"length":3', '"length":3.0'),
        ('"length":3', '"length":3e0'),
        ('"length":3', '"length":-0'),
        ('"length":3', '"length":03'),
        ('"length":3', '"length":9007199254740992'),
        ('"length":3', '"length":9007199254740993'),
        ('"length":3', '"length":12345678901234567890'),
        ('"bytes":3', '"bytes":3.0'),
        ('"entries":1', '"entries":1e0'),
      ]) {
        expect(body, contains(substitution.$1));
        await expectLater(
          validate(
            sealText(body.replaceFirst(substitution.$1, substitution.$2)),
          ),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'reason',
              contains('Noncanonical integer token'),
            ),
          ),
        );
      }
      final r = records();
      r[0]['scope'] = '2.0 2e0 -0 9007199254740993';
      expect((await validate(seal(r))).complete, true);
    },
  );
  final mutations = <String, void Function(List<Map<String, Object?>>)>{
    'unknown field': (r) => r[2]['extra'] = true,
    'invalid calendar date': (r) =>
        r[0]['capturedAt'] = '2026-02-30T00:00:00.000Z',
    'noncanonical date': (r) => r[0]['capturedAt'] = '2026-11-10T00:00:00Z',
    'wrong version': (r) => r[0]['version'] = 3,
    'float version': (r) => r[0]['version'] = 2.0,
    'wrong chunk size': (r) => r[0]['chunkBytes'] = 1,
    'negative length': (r) => r[2]['length'] = -1,
    'float length': (r) => r[2]['length'] = 3.0,
    'file length mismatch': (r) => r[2]['length'] = 4,
    'file bytes mismatch': (r) => r[4]['bytes'] = 4,
    'file hash mismatch': (r) => r[4]['sha256'] = '0' * 64,
    'summary count': (r) => r.last['entries'] = 2,
    'summary complete': (r) => r.last['complete'] = false,
    'summary fabricated problems': (r) => r.last['problems'] = ['fake'],
    'reordered': (r) => r.insert(3, r.removeAt(4)),
    'no source': (r) => r.removeAt(1),
    'missing end source': (r) => r.removeAt(5),
    'nested object': (r) => r[0]['scope'] = {'x': 1},
    'nested array': (r) => r[1]['excludedTopLevelLockFiles'] = [
      ['x'],
    ],
    'noncanonical base64': (r) => r[3]['data'] = 'AQI',
    'empty chunk': (r) => r[3]['data'] = '',
    'metadata bytes': (r) {
      r[2].remove('length');
      r[2]['kind'] = 'directory';
    },
    'duplicate source': (r) {
      r.insertAll(6, [r[1], r[5]]);
    },
  };
  for (final mutation in mutations.entries) {
    test('reject ${mutation.key} even with recomputed checksum', () async {
      final r = records();
      mutation.value(r);
      await expectLater(validate(seal(r)), throwsFormatException);
    });
  }
  for (final key in [
    '../data',
    '/absolute',
    'a\\b',
    'a:b',
    'a//b',
    'a/./b',
    'NUL.txt',
    'a.',
    'a ',
    'a\u0000b',
  ]) {
    test('reject unsafe path ${jsonEncode(key)}', () async {
      final r = records();
      r[2]['key'] = key;
      await expectLater(validate(seal(r)), throwsFormatException);
    });
  }
  for (final pair in [
    ('a', 'A'),
    ('a', 'a/b'),
    ('a/b', 'a'),
    ('Folder/a', 'folder/b'),
  ]) {
    test('reject path collision $pair', () async {
      final r = records();
      r[2]['key'] = pair.$1;
      r.insertAll(5, [
        {'type': 'entry', 'key': pair.$2, 'kind': 'directory'},
        {
          'type': 'end_entry',
          'bytes': 0,
          'sha256': sha256.convert([]).toString(),
          'readable': true,
        },
      ]);
      r.last['entries'] = 2;
      // a/b then directory a is legitimate, use a file instead for this case.
      if (pair.$1 == 'a/b') {
        r[5]['kind'] = 'link';
        r[5]['target'] = 'any';
      }
      await expectLater(validate(seal(r)), throwsFormatException);
    });
  }
  test(
    'duplicate decoded JSON keys, invalid UTF8, nesting and exact EOF',
    () async {
      final body = '${records().map(jsonEncode).join('\n')}\n';
      for (final bytes in [
        sealText(
          body.replaceFirst('"version":2', '"version":2,"vers\\u0069on":2'),
        ),
        sealText(
          body.replaceFirst(
            '"scope":"inert evidence"',
            '"scope":${'[' * 10000}0${']' * 10000}',
          ),
        ),
        [255, ...seal(records())],
        [...seal(records()), 10],
        [...seal(records()), 32],
        seal(records()).sublist(0, seal(records()).length - 1),
        sealText('\n$body'),
        sealText(
          body.replaceFirst('"scope":"inert evidence"', '"scope":"\\ud800"'),
        ),
      ]) {
        await expectLater(validate(bytes), throwsFormatException);
      }
      final damaged = seal(records());
      damaged[0] = 32;
      await expectLater(validate(damaged), throwsFormatException);
    },
  );
  test('bounds fail closed before parsing and while streaming', () async {
    for (final limits in [
      const LegacyRecoveryValidationLimits(maxLineBytes: 20),
      const LegacyRecoveryValidationLimits(maxStreamBytes: 100),
      const LegacyRecoveryValidationLimits(maxMetadataBytes: 100),
      const LegacyRecoveryValidationLimits(maxFileBytes: 2),
      const LegacyRecoveryValidationLimits(maxPayloadBytes: 2),
    ]) {
      await expectLater(
        validate(seal(records()), limits: limits),
        throwsFormatException,
      );
    }
    await expectLater(
      LegacyRecoveryValidator.validate(
        Stream.fromIterable([[], [], []]),
        limits: const LegacyRecoveryValidationLimits(maxStreamEvents: 2),
      ),
      throwsFormatException,
    );
  });
  test(
    'cancellation and deadline interrupt stalled input and hostile cleanup',
    () async {
      final cancellation = LegacyRecoveryValidationCancellation();
      final never = Completer<void>();
      final controller = StreamController<List<int>>(
        onCancel: () => never.future,
      );
      final future = LegacyRecoveryValidator.validate(
        controller.stream,
        cancellation: cancellation,
      );
      cancellation.cancel();
      await expectLater(
        future,
        throwsA(isA<LegacyRecoveryValidationCancelled>()),
      );
      final idle = StreamController<List<int>>();
      await expectLater(
        LegacyRecoveryValidator.validate(
          idle.stream,
          limits: const LegacyRecoveryValidationLimits(
            timeout: Duration(milliseconds: 10),
          ),
        ),
        throwsA(isA<TimeoutException>()),
      );
      await idle.close();
      never.complete();
      await controller.close();
    },
  );
}
