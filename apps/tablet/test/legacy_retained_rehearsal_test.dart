import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: implementation_imports
import 'package:hive/src/hive_impl.dart';
import 'package:tripling_table/migration/legacy_migration.dart';
import 'package:tripling_table/migration/legacy_migration_coordinator.dart';
import 'package:tripling_table/migration/legacy_preferences_decode.dart';
import 'package:tripling_table/migration/legacy_rehearsal_capacity.dart';
import 'package:tripling_table/migration/legacy_rehearsal_recovery_actions.dart';
import 'package:tripling_table/migration/legacy_source_reader.dart';
import 'package:tripling_table/storage/table_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory parent;
  late Directory source;
  var calls = 0;
  int? failAt;
  final budget = LegacyRehearsalCapacity(
    availableBytes: (_) async => ++calls == failAt ? null : 10000000,
    maxRetainedBytes: 1000000,
    safetyReserveBytes: 100,
  );
  final layout = LegacySourceLayout(
    sourceId: 'retained-fixture',
    sourceVersion: 'repository fixture, not shipped',
    copyEvidence: 'Closed fixture writers.',
    capturedAt: DateTime.utc(2026, 11, 10),
    boxes: {for (final name in LegacyMigrationSnapshot.collections) name: null},
    preferencesPath: 'preferences.xml',
    preferencesFormat: LegacyPreferencesFormat.androidXml,
  );
  Future<Map<String, String>> bytes(Directory root) async => {
    await for (final entry in root.list())
      if (entry is File) entry.path: base64Encode(await entry.readAsBytes()),
  };
  Future<LegacyMigrationCoordinator> create() =>
      LegacyMigrationCoordinator.createRetainedIn(parent, capacity: budget);
  void supportPath(String? path) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async {
            expect(call.method, 'getApplicationSupportDirectory');
            return path;
          },
        );
  }

  setUp(() async {
    parent = Directory(
      await (await Directory.systemTemp.createTemp(
        'retained-test-',
      )).resolveSymbolicLinks(),
    );
    source = await Directory('${parent.path}/source').create();
    await File('${source.path}/preferences.xml').writeAsString('<map/>');
    calls = 0;
    failAt = null;
  });
  tearDown(() async {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    await parent.delete(recursive: true);
  });

  test(
    'unique children never adopt parent; modes cannot cross reopen or stale handles',
    () async {
      final sentinel = await File(
        '${parent.path}/existing-app-data',
      ).writeAsString('keep');
      final first = await create();
      final second = await create();
      expect(first.isRetained, true);
      expect(first.directory.parent.path, parent.path);
      expect(first.directory.path, isNot(second.directory.path));
      expect(await sentinel.readAsString(), 'keep');
      await expectLater(
        LegacyMigrationCoordinator.reopenRetained(parent, capacity: budget),
        throwsStateError,
      );
      await expectLater(
        LegacyMigrationCoordinator.reopenRehearsal(
          first.directory,
          capacity: budget,
        ),
        throwsStateError,
      );
      await expectLater(
        LegacyMigrationCoordinator.reopenForRecovery(first.directory),
        throwsStateError,
      );
      final temporary = await LegacyMigrationCoordinator.createRehearsal(
        capacity: budget,
      );
      try {
        expect(temporary.isRetained, false);
        await expectLater(
          LegacyMigrationCoordinator.reopenRetained(
            temporary.directory,
            capacity: budget,
          ),
          throwsStateError,
        );
        await expectLater(
          LegacyMigrationCoordinator.reopenRetainedForRecovery(
            temporary.directory,
          ),
          throwsStateError,
        );
        await File('${first.directory.path}/rehearsal.txt').writeAsString(
          await File(
            '${temporary.directory.path}/rehearsal.txt',
          ).readAsString(),
        );
        await expectLater(first.createRecoveryBackup(), throwsStateError);
        await expectLater(
          first.rehearse(sourceDirectory: source, layout: layout),
          throwsStateError,
        );
      } finally {
        await temporary.directory.delete(recursive: true);
      }
    },
  );

  for (final control in ['capacity-policy.json', 'rehearsal.txt']) {
    test(
      'creation verifies $control readback and retains a refused child',
      () async {
        Directory? attempted;
        final corrupting = LegacyRehearsalCapacity(
          availableBytes: (root) async {
            final marker = File('${root.path}/rehearsal.txt');
            if (await marker.exists()) {
              attempted = root;
              await File(
                '${root.path}/$control',
              ).writeAsString('damaged', flush: true);
            }
            return 10000000;
          },
          maxRetainedBytes: 1000000,
          safetyReserveBytes: 100,
        );
        await expectLater(
          LegacyMigrationCoordinator.createRetainedIn(
            parent,
            capacity: corrupting,
          ),
          throwsA(anything),
        );
        expect(attempted, isNotNull);
        expect(await attempted!.exists(), true);
        expect(
          await File('${attempted!.path}/$control').readAsString(),
          'damaged',
        );
        expect(
          await File('${attempted!.path}/coordinator.lock').exists(),
          true,
        );
      },
    );
  }

  test(
    'failed creation keeps its partial child and refuses to adopt it',
    () async {
      failAt = 2;
      await expectLater(create(), throwsA(anything));
      final child = (await parent.list().toList())
          .whereType<Directory>()
          .singleWhere((d) => d.path != source.path);
      expect(await File('${child.path}/coordinator.lock').exists(), true);
      await expectLater(
        LegacyMigrationCoordinator.reopenRetainedForRecovery(child),
        throwsStateError,
      );
      failAt = null;
      expect((await create()).directory.path, isNot(child.path));
      expect(await child.exists(), true);
    },
  );

  test(
    'restart preserves later gameplay and temporary inspection leaves bytes intact',
    () async {
      final first = await create();
      await first.rehearse(sourceDirectory: source, layout: layout);
      final hive = HiveImpl()..init(first.directory.path);
      try {
        final repo = TableRepository.forTesting(
          openBox: (name) => hive.openBox<String>(name),
        );
        final state = (await repo.open()).state;
        state.session.players.first.life = 17;
        await repo.save(state);
      } finally {
        await hive.close();
      }
      final before = await bytes(first.directory);
      final reopened = await LegacyMigrationCoordinator.reopenRetained(
        first.directory,
        capacity: budget,
      );
      final inspection = await LegacyRehearsalRecoveryActions(
        coordinator: reopened,
        layout: layout,
      ).inspect();
      expect(
        inspection.warnings.join(' '),
        contains('isolated retained rehearsal'),
      );
      expect(inspection.warnings.join(' '), isNot(contains('temporary files')));
      expect(await bytes(first.directory), before);
      final retry = await reopened.rehearse(layout: layout);
      expect(retry.alreadyPromoted, true);
      expect(retry.state.session.players.first.life, 17);
      expect(await bytes(first.directory), before);
    },
  );

  test('caller parent aliases and foreign content fail closed', () async {
    final alias = await Link('${parent.path}/alias').create(source.path);
    await expectLater(
      LegacyMigrationCoordinator.createRetainedIn(
        Directory(alias.path),
        capacity: budget,
      ),
      throwsStateError,
    );
    final child = await Directory('${source.path}/child').create();
    await expectLater(
      LegacyMigrationCoordinator.createRetainedIn(
        Directory('${alias.path}/child'),
        capacity: budget,
      ),
      throwsStateError,
    );
    expect(await child.list().toList(), isEmpty);
    final c = await create();
    await File('${c.directory.path}/foreign').writeAsString('preserve');
    final before = await bytes(c.directory);
    await expectLater(
      c.rehearse(sourceDirectory: source, layout: layout),
      throwsStateError,
    );
    expect(await bytes(c.directory), before);
  });

  test(
    'retained containment and linked Hive content refuse without changing evidence',
    () async {
      final c = await create();
      final before = await bytes(c.directory);
      for (final sourceRoot in [c.directory, parent]) {
        await expectLater(
          c.rehearse(sourceDirectory: sourceRoot, layout: layout),
          throwsStateError,
        );
        expect(await bytes(c.directory), before);
      }
      final target = await File(
        '${parent.path}/external',
      ).writeAsString('keep');
      await Link(
        '${c.directory.path}/${LegacyMigrationCoordinator.rawBoxName}.hive',
      ).create(target.path);
      await expectLater(
        c.rehearse(sourceDirectory: source, layout: layout),
        throwsStateError,
      );
      expect(await target.readAsString(), 'keep');
    },
  );

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    test(
      '$platform uses fresh support root and canonicalizes only trusted ancestors',
      () async {
        debugDefaultTargetPlatformOverride = platform;
        final alias = await Link('${parent.path}/alias').create(source.path);
        final support = await Directory('${source.path}/support').create();
        supportPath('${alias.path}/support');
        final c =
            await LegacyMigrationCoordinator.createRetainedInApplicationSupport(
              capacity: budget,
            );
        expect(c.directory.parent.path, support.path);
        supportPath(source.path);
        final next =
            await LegacyMigrationCoordinator.createRetainedInApplicationSupport(
              capacity: budget,
            );
        expect(next.directory.parent.path, source.path);
        supportPath('${alias.path}/');
        await expectLater(
          LegacyMigrationCoordinator.createRetainedInApplicationSupport(
            capacity: budget,
          ),
          throwsStateError,
        );
      },
    );
  }
  test('unsupported or unavailable support roots never fall back', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    await expectLater(
      LegacyMigrationCoordinator.createRetainedInApplicationSupport(
        capacity: budget,
      ),
      throwsUnsupportedError,
    );
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    for (final path in [null, 'relative', '${parent.path}/missing']) {
      supportPath(path);
      await expectLater(
        LegacyMigrationCoordinator.createRetainedInApplicationSupport(
          capacity: budget,
        ),
        throwsA(anything),
      );
    }
    expect(calls, 0);
    expect(await parent.list().toList(), hasLength(1));
  });
}
