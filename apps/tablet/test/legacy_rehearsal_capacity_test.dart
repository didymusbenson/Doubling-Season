import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/migration/legacy_migration.dart';
import 'package:tripling_table/migration/legacy_migration_coordinator.dart';
import 'package:tripling_table/migration/legacy_migration_recovery.dart';
import 'package:tripling_table/migration/legacy_preferences_decode.dart';
import 'package:tripling_table/migration/legacy_recovery_export.dart';
import 'package:tripling_table/migration/legacy_rehearsal_capacity.dart';
import 'package:tripling_table/migration/legacy_source_reader.dart';

LegacySourceLayout _layout() => LegacySourceLayout(
  sourceId: 'rehearsal-capacity-fixture',
  sourceVersion: 'repository fixture, not shipped',
  copyEvidence: 'All fixture writers closed before capture.',
  capturedAt: DateTime.utc(2026, 11, 10),
  boxes: {for (final name in LegacyMigrationSnapshot.collections) name: null},
  preferencesPath: 'preferences.xml',
  preferencesFormat: LegacyPreferencesFormat.androidXml,
);
Future<Map<String, String>> _files(Directory directory) async => {
  await for (final entry in directory.list())
    if (entry is File) entry.path: base64Encode(await entry.readAsBytes()),
};
Matcher _failure(LegacyRecoveryCapacityFailure reason) => throwsA(
  isA<LegacyRecoveryCapacityException>().having(
    (e) => e.reason,
    'reason',
    reason,
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory parent;
  late Directory source;
  final rehearsals = <LegacyMigrationCoordinator>[];
  int? available = 10000000;
  var throwsProbe = false;
  final destinations = <String>[];
  LegacyRehearsalCapacity budget({int maximum = 1000000}) =>
      LegacyRehearsalCapacity(
        availableBytes: (directory) async {
          destinations.add(directory.path);
          if (throwsProbe) throw StateError('Unavailable');
          return available;
        },
        maxRetainedBytes: maximum,
        safetyReserveBytes: 100,
      );
  Future<LegacyMigrationCoordinator> create({
    LegacyRehearsalCapacity? capacity,
  }) async {
    final result = await LegacyMigrationCoordinator.createRehearsal(
      capacity: capacity ?? budget(),
    );
    rehearsals.add(result);
    return result;
  }

  setUp(() async {
    parent = Directory(
      await (await Directory.systemTemp.createTemp(
        'rehearsal-capacity-test-',
      )).resolveSymbolicLinks(),
    );
    source = await Directory('${parent.path}/source').create();
    await File('${source.path}/preferences.xml').writeAsString('<map/>');
    available = 10000000;
    throwsProbe = false;
    destinations.clear();
  });
  tearDown(() async {
    for (final rehearsal in rehearsals) {
      if (await rehearsal.directory.exists()) {
        await rehearsal.directory.delete(recursive: true);
      }
    }
    rehearsals.clear();
    await parent.delete(recursive: true);
  });

  test('explicit bounded limits and exact measured boundaries', () async {
    for (final invalid in [0, -1, 8 * 1024 * 1024 * 1024 + 1]) {
      expect(() => budget(maximum: invalid), throwsArgumentError);
      expect(
        () => LegacyRehearsalCapacity(
          availableBytes: (_) async => 1000,
          maxRetainedBytes: 1000,
          safetyReserveBytes: invalid,
        ),
        throwsArgumentError,
      );
    }
    available = 110;
    await budget(maximum: 10).checkCreation(parent, 10);
    available = 109;
    await expectLater(
      budget(maximum: 10).checkCreation(parent, 10),
      _failure(LegacyRecoveryCapacityFailure.insufficient),
    );
    available = 1000;
    await expectLater(
      budget(maximum: 9).checkCreation(parent, 10),
      _failure(LegacyRecoveryCapacityFailure.outputLimit),
    );
    await File('${source.path}/retained').writeAsBytes(List.filled(20, 0));
    // Preferences are already six bytes. Physical files, not logical records.
    await budget(maximum: 30).checkWrite(source, 4);
    await expectLater(
      budget(maximum: 30).checkWrite(source, 5),
      _failure(LegacyRecoveryCapacityFailure.outputLimit),
    );
  });

  test(
    'unknown and failing probes refuse creation before creating an attempt',
    () async {
      for (final value in [null, -1, 0x8000000000000000]) {
        available = value;
        await expectLater(
          LegacyMigrationCoordinator.createRehearsal(capacity: budget()),
          _failure(LegacyRecoveryCapacityFailure.unknown),
        );
      }
      throwsProbe = true;
      await expectLater(
        LegacyMigrationCoordinator.createRehearsal(capacity: budget()),
        _failure(LegacyRecoveryCapacityFailure.unknown),
      );
    },
  );

  test(
    'restart requires exact policy and fresh probe, without silent adoption',
    () async {
      final c = await create();
      final original = await _files(c.directory);
      final readOnly = await LegacyMigrationCoordinator.reopenRehearsal(
        c.directory,
      );
      await expectLater(
        readOnly.rehearse(sourceDirectory: source, layout: _layout()),
        throwsStateError,
      );
      await expectLater(
        readOnly.inspectRehearsal(sourceDirectory: source, layout: _layout()),
        throwsStateError,
      );
      expect(await _files(c.directory), original);
      await expectLater(
        LegacyMigrationCoordinator.reopenRehearsal(
          c.directory,
          capacity: budget(maximum: 999999),
        ),
        throwsStateError,
      );
      final reopened = await LegacyMigrationCoordinator.reopenRehearsal(
        c.directory,
        capacity: budget(),
      );
      expect(
        (await reopened.rehearse(
          sourceDirectory: source,
          layout: _layout(),
        )).alreadyPromoted,
        false,
      );
      final unbudgeted = await LegacyMigrationCoordinator.createRehearsal();
      rehearsals.add(unbudgeted);
      await expectLater(
        LegacyMigrationCoordinator.reopenRehearsal(
          unbudgeted.directory,
          capacity: budget(),
        ),
        throwsStateError,
      );
    },
  );

  for (final boundary in [
    'captured',
    'staged',
    'intent',
    'promotion_before_write',
    'promotion_written',
    'promotion_flushed',
  ]) {
    test('capacity loss at $boundary preserves evidence and retries', () async {
      final c = await create();
      final sourceBefore = await _files(source);
      await expectLater(
        c.rehearse(
          sourceDirectory: source,
          layout: _layout(),
          onBoundary: (at) async {
            if (at == boundary) available = 99;
          },
        ),
        _failure(LegacyRecoveryCapacityFailure.insufficient),
      );
      final retained = await _files(c.directory);
      expect(retained.keys.any((key) => key.endsWith('.hive')), true);
      available = 10000000;
      final retry = await c.rehearse(layout: _layout());
      expect(
        retry.alreadyPromoted,
        boundary == 'promotion_written' || boundary == 'promotion_flushed',
      );
      expect(await _files(source), sourceBefore);
    });
  }

  test('retained Hive bytes count toward ceiling on every retry', () async {
    final c = await create(capacity: budget(maximum: 700));
    await expectLater(
      c.rehearse(sourceDirectory: source, layout: _layout()),
      _failure(LegacyRecoveryCapacityFailure.outputLimit),
    );
    final before = await _files(c.directory);
    await expectLater(
      c.rehearse(sourceDirectory: source, layout: _layout()),
      _failure(LegacyRecoveryCapacityFailure.outputLimit),
    );
    expect(await _files(c.directory), before);
  });

  for (final missing in [false, true]) {
    test(
      'damaged policy (missing=$missing) blocks semantic use but permits physical export',
      () async {
        final c = await create();
        final policy = File('${c.directory.path}/capacity-policy.json');
        if (missing) {
          await policy.delete();
        } else {
          await policy.writeAsString('{broken');
        }
        final before = await _files(c.directory);
        await expectLater(
          LegacyMigrationCoordinator.reopenRehearsal(c.directory),
          throwsA(anything),
        );
        await expectLater(
          c.rehearse(sourceDirectory: source, layout: _layout()),
          throwsA(anything),
        );
        final recovery = await LegacyMigrationCoordinator.reopenForRecovery(
          c.directory,
        );
        await expectLater(
          recovery.rehearse(sourceDirectory: source, layout: _layout()),
          throwsStateError,
        );
        await expectLater(
          recovery.inspectRehearsal(sourceDirectory: source, layout: _layout()),
          throwsStateError,
        );
        final options = LegacyRecoveryExportOptions(
          parent: parent,
          budget: LegacyRecoveryExportBudget(
            availableBytes: (_) async => 10000000,
            reserveBytes: 100,
          ),
        );
        expect(
          (await recovery.exportRecoveryBackup(options: options)).complete,
          true,
        );
        expect((await c.exportRecoveryBackup(options: options)).complete, true);
        expect(await _files(c.directory), before);
      },
    );
  }

  test('stale handles refuse replacement of their policy or marker', () async {
    final c = await create();
    await File(
      '${c.directory.path}/capacity-policy.json',
    ).writeAsString(canonicalMigrationJson(budget(maximum: 999999).toJson()));
    await expectLater(
      c.rehearse(sourceDirectory: source, layout: _layout()),
      throwsStateError,
    );
    final old = await LegacyMigrationCoordinator.createRehearsal();
    rehearsals.add(old);
    await File('${old.directory.path}/rehearsal.txt').writeAsString(
      await File('${c.directory.path}/rehearsal.txt').readAsString(),
    );
    await File(
      '${old.directory.path}/capacity-policy.json',
    ).writeAsString(canonicalMigrationJson(budget().toJson()));
    await expectLater(
      old.rehearse(sourceDirectory: source, layout: _layout()),
      throwsStateError,
    );
  });

  test(
    'inspection guards actual clone destination without modifying retained files',
    () async {
      late LegacyMigrationCoordinator c;
      var restrictClone = false;
      final capacity = LegacyRehearsalCapacity(
        availableBytes: (destination) async {
          if (restrictClone &&
              destination.path != c.directory.path &&
              destination.path != c.directory.parent.path &&
              await File(
                '${destination.path}/${LegacyMigrationCoordinator.rawBoxName}.hive',
              ).exists()) {
            return 100;
          }
          return 10000000;
        },
        maxRetainedBytes: 1000000,
        safetyReserveBytes: 100,
      );
      c = await create(capacity: capacity);
      await c.rehearse(sourceDirectory: source, layout: _layout());
      final before = await _files(c.directory);
      restrictClone = true;
      await expectLater(
        c.inspectRehearsal(layout: _layout()),
        _failure(LegacyRecoveryCapacityFailure.insufficient),
      );
      expect(await _files(c.directory), before);
      restrictClone = false;
      expect(
        (await c.inspectRehearsal(layout: _layout())).alreadyPromoted,
        true,
      );
      expect(await _files(c.directory), before);
    },
  );

  test(
    'canonical root and trailing separators work; final directory links refuse',
    () async {
      final c = await create();
      expect(c.directory.path, await c.directory.resolveSymbolicLinks());
      await LegacyMigrationCoordinator.reopenRehearsal(
        Directory('${c.directory.path}/'),
        capacity: budget(),
      );
      final link = Link('${parent.path}/alias');
      await link.create(c.directory.path);
      await expectLater(
        LegacyMigrationCoordinator.reopenRehearsal(
          Directory('${link.path}/'),
          capacity: budget(),
        ),
        throwsStateError,
      );
      expect(destinations, contains(c.directory.path));
    },
  );

  for (final control in ['capacity-policy.json', 'rehearsal.txt']) {
    test(
      '$control coordination hard-link alias refuses before read',
      () async {
        final c = await create();
        final file = File('${c.directory.path}/$control');
        await file.delete();
        final result = await Process.run('ln', [
          '${c.directory.path}/coordinator.lock',
          file.path,
        ]);
        expect(result.exitCode, 0);
        await expectLater(
          LegacyMigrationCoordinator.reopenRehearsal(
            c.directory,
            capacity: budget(),
          ),
          throwsStateError,
        );
      },
      skip: Platform.isWindows,
    );
  }
}
