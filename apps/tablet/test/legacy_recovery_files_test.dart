import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/migration/legacy_migration_recovery.dart';
import 'package:tripling_table/migration/legacy_migration.dart';
import 'package:tripling_table/migration/legacy_migration_journal.dart';
import 'package:tripling_table/migration/legacy_preferences_decode.dart';
import 'package:tripling_table/migration/legacy_source_archive.dart';
import 'package:tripling_table/migration/legacy_source_reader.dart';
import 'package:tripling_table/migration/legacy_recovery_files.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory parent;
  late Directory directory;
  late LegacyRecoveryFiles files;
  setUp(() async {
    parent = await Directory.systemTemp.createTemp('physical-recovery-test-');
    directory = await Directory('${parent.path}/records').create();
    files = LegacyRecoveryFiles(
      directory,
      name: 'physical-fixture',
      excludedTopLevelLockFiles: {'archive.lock'},
    );
  });
  tearDown(() async => parent.delete(recursive: true));

  test('retains unknown, corrupt, pending and nested bytes exactly', () async {
    await Directory('${directory.path}/nested').create();
    await File('${directory.path}/unknown.record').writeAsBytes([0, 255, 128]);
    await File('${directory.path}/pending.part').writeAsString('incomplete');
    await File('${directory.path}/nested/art.bin').writeAsBytes([3, 2, 1]);
    expect(await files.keys(), [
      'nested',
      'nested/art.bin',
      'pending.part',
      'unknown.record',
    ]);
    expect(jsonDecode((await files.read('nested'))!), {'kind': 'directory'});
    final value = jsonDecode((await files.read('unknown.record'))!) as Map;
    expect(value['kind'], 'file');
    expect(base64Decode(value['bytes'] as String), [0, 255, 128]);
    final backup = await LegacyRecoveryBackup.capture([files]);
    expect(backup.complete, isTrue);
    expect(backup.problems, isEmpty);
  });

  test('excludes only named top-level regular lock files', () async {
    await Directory('${directory.path}/nested').create();
    for (final path in [
      'archive.lock',
      'unknown.lock',
      'nested/archive.lock',
    ]) {
      await File('${directory.path}/$path').writeAsString('evidence');
    }
    expect(await files.keys(), [
      'nested',
      'nested/archive.lock',
      'unknown.lock',
    ]);
    expect(await files.read('archive.lock'), isNull);
    expect(await files.read('nested/archive.lock'), isNotNull);
  });

  test(
    'retains literal link targets and never descends through links',
    () async {
      final outside = await Directory('${parent.path}/outside').create();
      await File('${outside.path}/private').writeAsString('not in backup');
      await Link('${directory.path}/linked').create(outside.path);
      await Link(
        '${directory.path}/archive.lock',
      ).create('${outside.path}/private');
      expect(await files.keys(), ['archive.lock', 'linked']);
      expect(jsonDecode((await files.read('linked'))!), {
        'kind': 'link',
        'target': outside.path,
      });
      expect(jsonDecode((await files.read('archive.lock'))!)['kind'], 'link');
      await expectLater(files.read('linked/private'), throwsFormatException);
      final backup = await LegacyRecoveryBackup.capture([files]);
      expect(backup.complete, isTrue);
      expect(utf8.decode(backup.bytes), isNot(contains('not in backup')));
    },
  );

  test('rejects link roots and linked ancestors', () async {
    final alias = Link('${parent.path}/alias');
    await alias.create(directory.path);
    await Directory('${directory.path}/nested').create();
    for (final path in [alias.path, '${alias.path}/nested']) {
      final source = LegacyRecoveryFiles(Directory(path), name: 'alias');
      await expectLater(source.keys(), throwsFormatException);
      await expectLater(source.read('file'), throwsFormatException);
    }
  });

  test('rejects invalid relative paths and lock exclusions', () async {
    for (final key in [
      '',
      '/root',
      '../file',
      'a/../b',
      'a//b',
      'a/./b',
      r'a\b',
      'C:file',
      'bad\u0000path',
    ]) {
      await expectLater(files.read(key), throwsFormatException, reason: key);
    }
    expect(await files.read('missing'), isNull);
    for (final key in ['../archive.lock', 'nested/archive.lock', 'data']) {
      expect(
        () => LegacyRecoveryFiles(
          directory,
          name: 'bad',
          excludedTopLevelLockFiles: {key},
        ),
        throwsArgumentError,
      );
    }
    expect(() => LegacyRecoveryFiles(directory, name: ''), throwsArgumentError);
  });

  test('refuses oversized files before allocating their contents', () async {
    final file = File('${directory.path}/oversized');
    final handle = await file.open(mode: FileMode.write);
    try {
      await handle.truncate(LegacyRecoveryFiles.maxFileBytes + 1);
    } finally {
      await handle.close();
    }
    await expectLater(files.read('oversized'), throwsFormatException);
    final backup = await LegacyRecoveryBackup.capture([files]);
    expect(backup.complete, isFalse);
    expect(backup.problems, ['physical-fixture: 1 records unavailable.']);
  });

  test(
    'matching detects content and inventory changes without mutation',
    () async {
      final file = File('${directory.path}/first');
      await file.writeAsString('first');
      final records = {'first': (await files.read('first'))!};
      expect(await files.matches(records), isTrue);
      await file.writeAsString('changed');
      expect(await files.matches(records), isFalse);
      await file.writeAsString('first');
      await File('${directory.path}/second').writeAsString('second');
      expect(await files.matches(records), isFalse);
      expect(await file.readAsString(), 'first');
    },
  );

  test(
    'archive creation rejects normalized symlink root before target writes',
    () async {
      final alias = Link('${parent.path}/archive-parent-alias');
      await alias.create(directory.path);
      final before = await _physicalBytes(directory);
      final normalized = Directory.fromUri(
        Directory(alias.path).absolute.uri.normalizePath(),
      );
      await expectLater(
        LegacySourceArchive.createIn(normalized),
        throwsStateError,
      );
      expect(
        await _physicalBytes(directory),
        before,
        reason: 'Refusal must precede creation of any archive child or marker.',
      );
    },
  );

  test(
    'archive reopen rejects normalized symlink root without target writes',
    () async {
      final archive = await LegacySourceArchive.createIn(directory);
      final alias = Link('${parent.path}/tripling-retained-source-alias');
      await alias.create(archive.directory.path);
      final before = await _physicalBytes(directory);
      final normalized = Directory.fromUri(
        Directory(alias.path).absolute.uri.normalizePath(),
      );
      await expectLater(
        LegacySourceArchive.reopen(normalized),
        throwsStateError,
      );
      expect(await _physicalBytes(directory), before);
    },
  );

  test(
    'copied source rejects normalized symlink root before retention',
    () async {
      await File('${directory.path}/prefs.xml').writeAsString('<map/>');
      final alias = Link('${parent.path}/source-alias');
      await alias.create(directory.path);
      final before = await _physicalBytes(directory);
      final recovery = _MemoryRecovery();
      final normalized = Directory.fromUri(
        Directory(alias.path).absolute.uri.normalizePath(),
      );
      await expectLater(
        LegacySourceReader().acquireCopiedDirectory(
          directory: normalized,
          layout: LegacySourceLayout(
            sourceId: 'symlink-fixture',
            sourceVersion: 'synthetic',
            copyEvidence: 'Closed offline test fixture.',
            capturedAt: DateTime.utc(2026, 11, 10),
            boxes: {
              for (final name in LegacyMigrationSnapshot.collections)
                name: null,
            },
            preferencesPath: 'prefs.xml',
            preferencesFormat: LegacyPreferencesFormat.androidXml,
          ),
          recoveryStorage: recovery,
        ),
        throwsFormatException,
      );
      expect(
        recovery.values,
        isEmpty,
        reason: 'No source records may be retained through a rejected root.',
      );
      expect(await _physicalBytes(directory), before);
    },
  );
}

Future<Map<String, List<int>>> _physicalBytes(Directory directory) async => {
  await for (final entity in directory.list(
    recursive: true,
    followLinks: false,
  ))
    if (entity is File) entity.path: await entity.readAsBytes(),
};

class _MemoryRecovery extends LegacyMigrationStorage {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> flush() async {}
}
