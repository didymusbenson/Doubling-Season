import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/migration/legacy_archive_capacity.dart';
import 'package:tripling_table/migration/legacy_migration.dart';
import 'package:tripling_table/migration/legacy_migration_coordinator.dart';
import 'package:tripling_table/migration/legacy_migration_recovery.dart';
import 'package:tripling_table/migration/legacy_preferences_decode.dart';
import 'package:tripling_table/migration/legacy_recovery_export.dart';
import 'package:tripling_table/migration/legacy_source_archive.dart';
import 'package:tripling_table/migration/legacy_source_reader.dart';

LegacySourceLayout _layout() => LegacySourceLayout(
  sourceId: 'capacity-fixture',
  sourceVersion: 'repository fixture, not shipped',
  copyEvidence: 'All fixture writers closed before capture.',
  capturedAt: DateTime.utc(2026, 11, 10),
  boxes: {for (final name in LegacyMigrationSnapshot.collections) name: null},
  preferencesPath: 'preferences.xml',
  preferencesFormat: LegacyPreferencesFormat.androidXml,
);

Future<Map<String, List<int>>> _files(Directory root) async => {
  await for (final file in root.list(recursive: true))
    if (file is File) file.path: await file.readAsBytes(),
};

Matcher _capacityFailure(LegacyRecoveryCapacityFailure reason) => throwsA(
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
  var available = 1024 * 1024;
  final probed = <String>[];
  LegacyArchiveCapacity budget({int maximum = 100000}) => LegacyArchiveCapacity(
    availableBytes: (directory) async {
      probed.add(directory.path);
      return available;
    },
    maxArchiveBytes: maximum,
    safetyReserveBytes: 100,
    conversionReserveBytes: 200,
  );

  setUp(() async {
    final temporary = await Directory.systemTemp.createTemp(
      'archive-capacity-',
    );
    parent = Directory(await temporary.resolveSymbolicLinks());
    source = await Directory('${parent.path}/source').create();
    await File('${source.path}/preferences.xml').writeAsString('<map/>');
    available = 1024 * 1024;
    probed.clear();
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

  test('requires explicit bounded positive capture and conversion budgets', () {
    for (final value in [0, -1, LegacyArchiveCapacity.maxBudgetBytes + 1]) {
      expect(() => budget(maximum: value), throwsArgumentError);
      expect(
        () => LegacyArchiveCapacity(
          availableBytes: (_) async => available,
          maxArchiveBytes: 10000,
          conversionReserveBytes: value,
        ),
        throwsArgumentError,
      );
      expect(
        () => LegacyArchiveCapacity(
          availableBytes: (_) async => available,
          maxArchiveBytes: 10000,
          conversionReserveBytes: 100,
          safetyReserveBytes: value,
        ),
        throwsArgumentError,
      );
    }
  });

  test(
    'checks exact boundary including separate conversion and safety reserves',
    () async {
      available = 350;
      await budget().checkCreation(parent, 50);
      await expectLater(
        budget().checkCreation(parent, 51),
        _capacityFailure(LegacyRecoveryCapacityFailure.insufficient),
      );
      await expectLater(
        budget().checkCreation(parent, -1),
        throwsArgumentError,
      );
      expect(await parent.list().toList(), hasLength(1));
    },
  );

  test(
    'unknown, negative and failing probes refuse before archive creation',
    () async {
      final before = await _files(parent);
      for (final probe in <Future<int?> Function(Directory)>[
        (_) async => null,
        (_) async => -1,
        (_) async => throw StateError('unavailable'),
      ]) {
        await expectLater(
          LegacySourceArchive.createIn(
            parent,
            capacity: LegacyArchiveCapacity(
              availableBytes: probe,
              maxArchiveBytes: 10000,
              conversionReserveBytes: 200,
              safetyReserveBytes: 100,
            ),
          ),
          _capacityFailure(LegacyRecoveryCapacityFailure.unknown),
        );
        expect(await _files(parent), before);
        expect(await parent.list().toList(), hasLength(1));
      }
    },
  );

  test(
    'insufficient creation capacity and maximum do not create attempts',
    () async {
      available = 300;
      await expectLater(
        LegacySourceArchive.createIn(parent, capacity: budget()),
        _capacityFailure(LegacyRecoveryCapacityFailure.insufficient),
      );
      available = 1024 * 1024;
      await expectLater(
        LegacySourceArchive.createIn(parent, capacity: budget(maximum: 1)),
        _capacityFailure(LegacyRecoveryCapacityFailure.outputLimit),
      );
      expect(await parent.list().toList(), hasLength(1));
    },
  );

  test(
    'persists policy, measures destination, and captures without changing source',
    () async {
      final before = await _files(source);
      final archive = await LegacySourceArchive.createIn(
        parent,
        capacity: budget(),
      );
      final policy = jsonDecode(
        await File(
          '${archive.directory.path}/capacity-policy.json',
        ).readAsString(),
      );
      expect(policy, budget().toJson());
      final captured = await archive.captureCopiedDirectory(
        source: source,
        layout: _layout(),
      );
      expect(captured.snapshot.toJson()['preferences'], isEmpty);
      expect(await _files(source), before);
      expect(probed.first, parent.path);
      expect(probed.skip(1), everyElement(archive.directory.path));
      final reopened = await LegacySourceArchive.reopen(
        archive.directory,
        capacity: budget(),
      );
      expect(
        (await reopened.openRetained(layout: _layout()))!.snapshot.digest,
        captured.snapshot.digest,
      );
    },
  );

  test(
    'a budgeted archive cannot reopen for capture without its exact policy',
    () async {
      final archive = await LegacySourceArchive.createIn(
        parent,
        capacity: budget(),
      );
      await archive.captureCopiedDirectory(source: source, layout: _layout());
      final before = await _files(archive.directory);
      final readOnly = await LegacySourceArchive.reopen(archive.directory);
      expect(await readOnly.openRetained(layout: _layout()), isNotNull);
      await expectLater(
        readOnly.captureCopiedDirectory(source: source, layout: _layout()),
        throwsStateError,
      );
      await expectLater(
        LegacySourceArchive.reopen(
          archive.directory,
          capacity: budget(maximum: 200000),
        ),
        throwsStateError,
      );
      expect(await _files(archive.directory), before);
    },
  );

  test(
    'cannot silently apply policy to existing unbudgeted evidence',
    () async {
      final archive = await LegacySourceArchive.createIn(parent);
      final before = await _files(archive.directory);
      await expectLater(
        LegacySourceArchive.reopen(archive.directory, capacity: budget()),
        throwsStateError,
      );
      expect(await _files(archive.directory), before);
    },
  );

  test(
    'missing and malformed policies fail closed and preserve evidence',
    () async {
      for (final policy in ['', '{}', '{"version":2}', 'x' * 1025]) {
        final archive = await LegacySourceArchive.createIn(
          parent,
          capacity: budget(),
        );
        final file = File('${archive.directory.path}/capacity-policy.json');
        if (policy.isEmpty) {
          await file.rename('${parent.path}/removed-policy');
        } else {
          await file.writeAsString(policy);
        }
        final before = await _files(archive.directory);
        await expectLater(
          LegacySourceArchive.reopen(archive.directory, capacity: budget()),
          throwsA(anything),
        );
        expect(await _files(archive.directory), before);
      }
    },
  );

  test(
    'capacity loss before a write refuses, keeps empty attempt, and resumes',
    () async {
      final archive = await LegacySourceArchive.createIn(
        parent,
        capacity: budget(),
      );
      final original = await _files(source);
      await expectLater(
        archive.captureCopiedDirectory(
          source: source,
          layout: _layout(),
          onBoundary: (boundary) async {
            if (boundary.startsWith('archive_before_write:raw_file_')) {
              available = 300;
            }
          },
        ),
        _capacityFailure(LegacyRecoveryCapacityFailure.insufficient),
      );
      expect(await archive.openRetained(layout: _layout()), isNull);
      final before = await _files(archive.directory);
      expect(before.keys.where((p) => p.endsWith('.part')), hasLength(1));
      available = 1024 * 1024;
      await archive.captureCopiedDirectory(source: source, layout: _layout());
      final after = await _files(archive.directory);
      for (final entry in before.entries) {
        expect(after[entry.key], entry.value);
      }
      expect(await _files(source), original);
    },
  );

  test(
    'capacity loss after flush cannot publish inventory; retry retains attempts',
    () async {
      final archive = await LegacySourceArchive.createIn(
        parent,
        capacity: budget(),
      );
      await expectLater(
        archive.captureCopiedDirectory(
          source: source,
          layout: _layout(),
          onBoundary: (boundary) async {
            if (boundary ==
                'archive_verified:${LegacySourceReader.inventoryKey}') {
              available = 299;
            }
          },
        ),
        _capacityFailure(LegacyRecoveryCapacityFailure.insufficient),
      );
      expect(await archive.openRetained(layout: _layout()), isNull);
      final before = await _files(archive.directory);
      expect(before.keys.where((p) => p.endsWith('.part')), hasLength(1));
      available = 1024 * 1024;
      final restarted = await LegacySourceArchive.reopen(
        archive.directory,
        capacity: budget(),
      );
      await restarted.captureCopiedDirectory(source: source, layout: _layout());
      final after = await _files(archive.directory);
      for (final entry in before.entries) {
        expect(after[entry.key], entry.value);
      }
    },
  );

  test(
    'failed attempts count toward retained-byte ceiling on every retry',
    () async {
      final archive = await LegacySourceArchive.createIn(
        parent,
        capacity: budget(maximum: 1000),
      );
      final part = File(
        '${archive.directory.path}/pending_11111111-1111-1111-1111-111111111111.part',
      );
      await part.writeAsBytes(List.filled(900, 1));
      final before = await _files(archive.directory);
      for (var attempt = 0; attempt < 2; attempt++) {
        await expectLater(
          archive.captureCopiedDirectory(source: source, layout: _layout()),
          _capacityFailure(LegacyRecoveryCapacityFailure.outputLimit),
        );
        expect(await _files(archive.directory), before);
      }
    },
  );

  test(
    'policy and pending files survive recovery export without fresh capture capacity',
    () async {
      final archive = await LegacySourceArchive.createIn(
        parent,
        capacity: budget(),
      );
      await archive.captureCopiedDirectory(source: source, layout: _layout());
      final original = await _files(archive.directory);
      final readOnly = await LegacySourceArchive.reopen(archive.directory);
      final output = await Directory('${parent.path}/exports').create();
      final exported = await readOnly.exportRecoveryBackup(
        options: LegacyRecoveryExportOptions(
          parent: output,
          budget: LegacyRecoveryExportBudget(
            availableBytes: (_) async => 1000000,
            reserveBytes: 100,
            maxOutputBytes: 100000,
          ),
        ),
      );
      expect(exported.complete, isTrue);
      expect(await _files(archive.directory), original);
      expect(
        await exported.file.readAsString(),
        contains('capacity-policy.json'),
      );
    },
  );

  test(
    'fresh forensic recovery exports malformed/missing policy without enabling capture',
    () async {
      for (final damaged in [true, false]) {
        final archive = await LegacySourceArchive.createIn(
          parent,
          capacity: budget(),
        );
        await archive.captureCopiedDirectory(source: source, layout: _layout());
        final policy = File('${archive.directory.path}/capacity-policy.json');
        if (damaged) {
          await policy.writeAsString('{"partial":');
        } else {
          await policy.rename('${parent.path}/saved-policy');
        }
        final before = await _files(archive.directory);
        final recovery = await LegacySourceArchive.reopenForRecovery(
          archive.directory,
        );
        await expectLater(
          recovery.captureCopiedDirectory(source: source, layout: _layout()),
          throwsStateError,
        );
        await expectLater(
          recovery.openRetained(layout: _layout()),
          throwsStateError,
        );
        final backup = await recovery.createRecoveryBackup();
        expect(backup.complete, isTrue);
        final output = await Directory(
          '${parent.path}/exports-$damaged',
        ).create();
        final options = LegacyRecoveryExportOptions(
          parent: output,
          budget: LegacyRecoveryExportBudget(
            availableBytes: (_) async => 1000000,
            reserveBytes: 100,
            maxOutputBytes: 100000,
          ),
        );
        final exported = await recovery.exportRecoveryBackup(options: options);
        expect(exported.complete, isTrue);
        // An already-open ordinary archive must also keep its forensic route.
        expect(
          (await archive.exportRecoveryBackup(options: options)).complete,
          isTrue,
        );
        expect(await _files(archive.directory), before);
      }
    },
  );

  test(
    'valid budgeted archive transfers read-only to isolated rehearsal',
    () async {
      final archive = await LegacySourceArchive.createIn(
        parent,
        capacity: budget(),
      );
      await archive.captureCopiedDirectory(source: source, layout: _layout());
      final before = await _files(archive.directory);
      final readOnly = await LegacySourceArchive.reopen(archive.directory);
      final coordinator = await LegacyMigrationCoordinator.createRehearsal();
      addTearDown(() => coordinator.directory.delete(recursive: true));
      final promoted = await coordinator.rehearse(
        sourceArchive: readOnly,
        layout: _layout(),
      );
      expect(promoted.alreadyPromoted, isFalse);
      final repeated = await coordinator.rehearse(
        sourceArchive: readOnly,
        layout: _layout(),
      );
      expect(repeated.alreadyPromoted, isTrue);
      expect(await _files(archive.directory), before);
    },
  );

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    test(
      'opt-in $platform location uses platform Application Support, not temporary fallback',
      () async {
        debugDefaultTargetPlatformOverride = platform;
        final support = await Directory(
          '${parent.path}/application-support',
        ).create();
        var calls = 0;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('plugins.flutter.io/path_provider'),
              (call) async {
                calls++;
                expect(call.method, 'getApplicationSupportDirectory');
                return support.path;
              },
            );
        final archive = await LegacySourceArchive.createInApplicationSupport(
          capacity: budget(),
        );
        expect(archive.directory.parent.path, support.path);
        expect(calls, 1);
        expect(probed.first, support.path);
      },
    );
  }

  test(
    'native support rejects symlink roots including trailing separators',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final support = await Directory('${parent.path}/real-support').create();
      final alias = await Link(
        '${parent.path}/support-link',
      ).create(support.path);
      for (final path in [alias.path, '${alias.path}/']) {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('plugins.flutter.io/path_provider'),
              (_) async => path,
            );
        await expectLater(
          LegacySourceArchive.createInApplicationSupport(capacity: budget()),
          throwsStateError,
        );
      }
      expect(await support.list().toList(), isEmpty);
      expect(probed, isEmpty);
    },
  );

  test(
    'budgeted policy cannot alias archive coordination inode',
    () async {
      final archive = await LegacySourceArchive.createIn(
        parent,
        capacity: budget(),
      );
      final policy = File('${archive.directory.path}/capacity-policy.json');
      await policy.rename('${parent.path}/saved-policy');
      final linked = await Process.run('ln', [
        '${archive.directory.path}/archive.lock',
        policy.path,
      ]);
      expect(linked.exitCode, 0);
      final before = await _files(archive.directory);
      await expectLater(
        LegacySourceArchive.reopen(archive.directory, capacity: budget()),
        throwsStateError,
      );
      expect(await _files(archive.directory), before);
    },
    skip: !Platform.isLinux && !Platform.isMacOS,
  );

  test(
    'policy alias to held external coordination is rejected before decoding',
    () async {
      final archive = await LegacySourceArchive.createIn(
        parent,
        capacity: budget(),
      );
      final policy = File('${archive.directory.path}/capacity-policy.json');
      final external = File('${parent.path}/external.lock');
      await external.writeAsBytes(await policy.readAsBytes());
      await policy.rename('${parent.path}/saved-policy');
      expect(
        (await Process.run('ln', [external.path, policy.path])).exitCode,
        0,
      );
      await expectLater(
        LegacySourceArchive.reopen(
          archive.directory,
          capacity: budget(),
          heldCoordinationPaths: [external.path],
        ),
        throwsStateError,
      );
      final forensic = await LegacySourceArchive.reopenForRecovery(
        archive.directory,
        heldCoordinationPaths: [external.path],
      );
      // Opening for forensic use never reads or validates the aliased policy.
      await expectLater(
        forensic.captureCopiedDirectory(source: source, layout: _layout()),
        throwsStateError,
      );
    },
    skip: !Platform.isLinux && !Platform.isMacOS,
  );

  test(
    'interrupted archive creation keeps its partial control files',
    () async {
      var calls = 0;
      final capacity = LegacyArchiveCapacity(
        availableBytes: (_) async => ++calls == 1 ? 100000 : null,
        maxArchiveBytes: 10000,
        conversionReserveBytes: 200,
        safetyReserveBytes: 100,
      );
      await expectLater(
        LegacySourceArchive.createIn(parent, capacity: capacity),
        _capacityFailure(LegacyRecoveryCapacityFailure.unknown),
      );
      final children = (await parent.list().toList())
          .whereType<Directory>()
          .toList();
      expect(children, hasLength(2));
      final interrupted = children.singleWhere((d) => d.path != source.path);
      expect(await File('${interrupted.path}/archive.lock').exists(), isTrue);
      expect(await File('${interrupted.path}/archive.txt').exists(), isFalse);
      await expectLater(
        LegacySourceArchive.reopen(interrupted, capacity: capacity),
        throwsStateError,
      );
    },
  );

  test('unsupported platform never asks for support location', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    await expectLater(
      LegacySourceArchive.createInApplicationSupport(capacity: budget()),
      throwsUnsupportedError,
    );
    expect(probed, isEmpty);
  });

  test(
    'support-location failure has no temporary-directory fallback',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => null,
          );
      await expectLater(
        LegacySourceArchive.createInApplicationSupport(capacity: budget()),
        throwsA(anything),
      );
      expect(probed, isEmpty);
      expect(await parent.list().toList(), hasLength(1));
    },
  );
}
