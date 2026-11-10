import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: implementation_imports
import 'package:hive/src/hive_impl.dart';
import 'package:tripling_table/storage/storage_namespace.dart';
import 'package:tripling_table/features/preset_service.dart';
import 'package:tripling_table/migration/legacy_migration.dart';
import 'package:tripling_table/migration/legacy_migration_coordinator.dart';
import 'package:tripling_table/migration/legacy_migration_journal.dart';
import 'package:tripling_table/migration/legacy_preferences_decode.dart';
import 'package:tripling_table/migration/legacy_source_reader.dart';

import 'support/table_fixture.dart';

class _Memory extends LegacyMigrationStorage {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> flush() async {}
}

Future<Map<String, String>> _hashes(Directory directory) async => {
  await for (final file in directory.list(recursive: true))
    if (file is File)
      file.path: sha256.convert(await file.readAsBytes()).toString(),
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final schema in ['3715778', 'd9e19b6']) {
    final root = Directory('test/fixtures/historical_hive/$schema');
    final copy = Directory('${root.path}/copy');
    final order = schema == '3715778' ? 0.0 : 8.5;
    LegacySourceLayout layout() => LegacySourceLayout(
      sourceId: 'synthetic-repository-$schema',
      sourceVersion: '$schema, not a shipped device capture',
      copyEvidence:
          'Fixed synthetic bytes generated with archived repository '
          'models and adapters; all fixture writers closed. See provenance.json.',
      capturedAt: DateTime.utc(2026, 11, 10),
      boxes: {
        for (final name in LegacyMigrationSnapshot.collections)
          name: ['items', 'decks'].contains(name) ? '$name.hive' : null,
      },
      preferencesPath: 'preferences.xml',
      preferencesFormat: LegacyPreferencesFormat.androidXml,
    );

    test(
      '$schema source archives and frozen fixture bytes match provenance',
      () async {
        final manifest = jsonDecode(
          await File('${root.path}/provenance.json').readAsString(),
        );
        expect(
          manifest['kind'],
          'synthetic-repository-history-not-shipped-device-capture',
        );
        for (final entry in (manifest['sourceSha256'] as Map).entries) {
          expect(
            sha256
                .convert(
                  await File(
                    '${root.path}/source/${entry.key}.txt',
                  ).readAsBytes(),
                )
                .toString(),
            entry.value,
            reason: '${entry.key}',
          );
        }
        expect(
          (manifest['fixtureSha256'] as Map).keys,
          unorderedEquals([
            for (final variant in ['copy', 'multi'])
              for (final name in [
                'items.hive',
                'decks.hive',
                'preferences.xml',
              ])
                '$variant/$name',
          ]),
        );
        for (final entry in (manifest['fixtureSha256'] as Map).entries) {
          expect(
            sha256
                .convert(await File('${root.path}/${entry.key}').readAsBytes())
                .toString(),
            entry.value,
            reason: '${entry.key}',
          );
        }
      },
    );

    test(
      '$schema copied reader defaults absent fields and retains exact originals',
      () async {
        final before = await _hashes(root);
        final recovery = _Memory();
        final source = await LegacySourceReader().acquireCopiedDirectory(
          directory: copy,
          layout: layout(),
          recoveryStorage: recovery,
        );
        final collections = source.snapshot.toJson()['collections'];
        final items = collections['items'] as List;
        expect(items, hasLength(1)); // Overwrite wins; tombstone stays deleted.
        expect(items.single['key'], 7);
        final item = items.single['value'];
        expect(item['amount'], 11);
        expect(item['tapped'], 3);
        expect(item['summoningSick'], 2);
        expect(item['counters'], [
          {'name': 'charge', 'amount': 4},
        ]);
        expect(item['order'], order);
        expect(item['type'], '');
        expect(item['artworkUrl'], isNull);
        expect(item['artworkOptions'], isNull);
        expect(item['plusOnePowerCounters'], 0);
        expect(item['plusOneToughnessCounters'], 0);
        final deck = collections['decks'][0]['value'];
        expect(deck['templates'][0]['order'], order);
        expect(deck['templates'][0]['artworkUrl'], isNull);
        expect(deck['trackerWidgets'], isNull);
        expect(deck['toggleWidgets'], isNull);
        expect(deck['customArtworkUrl'], isNull);
        for (final file in await copy.list().toList()) {
          if (file is! File) continue;
          final bytes = await file.readAsBytes();
          final saved = jsonDecode(
            recovery.values['raw_file_${sha256.convert(bytes)}']!,
          );
          expect(base64Decode(saved['bytes']), bytes);
        }
        expect(await _hashes(root), before);
      },
    );

    test(
      '$schema multi-record order is preserved or fails closed with exact retention',
      () async {
        final before = await _hashes(root);
        final multi = Directory('${root.path}/multi');
        final recovery = _Memory();
        Future<LegacyAcquiredSource> acquire() =>
            LegacySourceReader().acquireCopiedDirectory(
              directory: multi,
              layout: layout(),
              recoveryStorage: recovery,
            );
        if (schema == '3715778') {
          final refusal = throwsA(
            isA<FormatException>().having(
              (error) => error.message,
              'reason',
              contains('lacks explicit order'),
            ),
          );
          await expectLater(acquire(), refusal);
          await expectLater(acquire(), refusal);
          await expectLater(
            LegacySourceReader().openRetained(
              layout: layout(),
              recoveryStorage: recovery,
            ),
            refusal,
          );
          // A failed acquisition must never reach isolated promotion either.
          final coordinator =
              await LegacyMigrationCoordinator.createRehearsal();
          addTearDown(() => coordinator.directory.delete(recursive: true));
          await expectLater(
            coordinator.rehearse(sourceDirectory: multi, layout: layout()),
            refusal,
          );
          final hive = HiveImpl()..init(coordinator.directory.path);
          try {
            final aggregate = await hive.openBox<String>(
              TableStorageKeys.aggregate,
              crashRecovery: false,
            );
            expect(aggregate.get('current'), isNull);
          } finally {
            await hive.close();
          }
        } else {
          final source = await acquire();
          final prepared = await source.prepare(
            LegacyMigrationJournal(_Memory()),
          );
          expect(prepared.blockers, isEmpty);
          expect(
            prepared.state.session.players.first.tokens.map((t) => t.name),
            ['Earlier Spirit', 'Historical Goblin'],
          );
        }
        for (final file in await multi.list().toList()) {
          if (file is! File) continue;
          final bytes = await file.readAsBytes();
          final saved = jsonDecode(
            recovery.values['raw_file_${sha256.convert(bytes)}']!,
          );
          expect(base64Decode(saved['bytes']), bytes);
        }
        expect(await _hashes(root), before);
      },
    );

    test(
      '$schema coordinator preserves live state, fresh presets and retry identity',
      () async {
        final before = await _hashes(root);
        final coordinator = await LegacyMigrationCoordinator.createRehearsal();
        addTearDown(() => coordinator.directory.delete(recursive: true));
        final result = await coordinator.rehearse(
          sourceDirectory: copy,
          layout: layout(),
        );
        final player = result.state.session.players.first;
        expect(player.tokens, hasLength(1));
        expect(player.tokens.single.amount, 11);
        expect(player.tokens.single.tapped, 3);
        expect(player.tokens.single.summoningSick, 2);
        expect(player.tokens.single.counters['charge'], 4);
        expect(result.state.decks, hasLength(1));
        final fixture = TableFixture(result.state);
        await fixture.initialize();
        addTearDown(fixture.dispose);
        final originalLive = jsonEncode(fixture.player.toJson());
        final otherId = fixture.controller.session.players[1].id;
        await PresetService(
          fixture.controller,
          fixture.catalog,
        ).load(otherId, result.state.decks.single['id'] as String);
        final preset = fixture.controller.player(otherId).tokens.single;
        expect(preset.name, 'Historical Goblin');
        expect(preset.amount, 0);
        expect(preset.tapped, 0);
        expect(preset.summoningSick, 0);
        expect(preset.counters, isEmpty);
        expect(jsonEncode(fixture.player.toJson()), originalLive);
        final reopened = await LegacyMigrationCoordinator.reopenRehearsal(
          coordinator.directory,
        );
        final retry = await reopened.rehearse(layout: layout());
        expect(retry.alreadyPromoted, true);
        expect(retry.transactionId, result.transactionId);
        expect(retry.state.session.players.first.tokens.single.amount, 11);
        expect(await _hashes(root), before);
      },
    );
  }
}
