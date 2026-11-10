import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
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

final _root = Directory('test/fixtures/historical_hive/fa577ac');
final _copy = Directory('${_root.path}/copy');
LegacySourceLayout _layout() => LegacySourceLayout(
  sourceId: 'synthetic-repository-fa577ac',
  sourceVersion: 'fa577ac; not a shipped device capture',
  copyEvidence:
      'Frozen synthetic bytes from exact historical adapters, closed writer.',
  capturedAt: DateTime.utc(2026, 11, 10),
  boxes: {
    for (final name in LegacyMigrationSnapshot.collections)
      name: name == 'customTokens' ? null : '${name.toLowerCase()}.hive',
  },
  preferencesPath: 'preferences.xml',
  preferencesFormat: LegacyPreferencesFormat.androidXml,
);
Future<Map<String, String>> _hashes() async => {
  await for (final file in _root.list(recursive: true))
    if (file is File)
      file.path: sha256.convert(await file.readAsBytes()).toString(),
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('later frozen sources, driver and bytes match provenance', () async {
    final manifest = jsonDecode(
      await File('${_root.path}/provenance.json').readAsString(),
    );
    expect(
      manifest['kind'],
      'synthetic-repository-history-not-shipped-device-capture',
    );
    expect(manifest['commit'], startsWith('fa577ac'));
    expect(manifest['writerRuntime']['resolvedHiveVersion'], '2.2.3');
    expect(
      (manifest['fixtureSha256'] as Map).keys,
      unorderedEquals([
        'copy/items.hive',
        'copy/decks.hive',
        'copy/trackerwidgets.hive',
        'copy/togglewidgets.hive',
        'copy/artworkpreferences.hive',
        'copy/tokenrules.hive',
        'copy/preferences.xml',
      ]),
    );
    expect(
      (manifest['sourceSha256'] as Map).keys,
      unorderedEquals([
        for (final name in [
          'item',
          'token_counter',
          'deck',
          'token_template',
          'token_definition',
          'token_artwork_preference',
          'tracker_widget',
          'toggle_widget',
          'tracker_widget_template',
          'toggle_widget_template',
          'token_rule',
          'rule_trigger',
          'rule_outcome',
        ]) ...['lib/models/$name.dart', 'lib/models/$name.g.dart'],
        'lib/utils/constants.dart',
        'pubspec.lock',
      ]),
    );
    for (final entry in (manifest['sourceSha256'] as Map).entries) {
      expect(
        sha256
            .convert(
              await File('${_root.path}/source/${entry.key}.txt').readAsBytes(),
            )
            .toString(),
        entry.value,
      );
    }
    for (final entry in (manifest['fixtureSha256'] as Map).entries) {
      expect(
        sha256
            .convert(await File('${_root.path}/${entry.key}').readAsBytes())
            .toString(),
        entry.value,
      );
    }
    expect(
      sha256
          .convert(
            await File(
              'tool/historical_later_fixture_writer.dart.txt',
            ).readAsBytes(),
          )
          .toString(),
      manifest['writerSha256'],
    );
  });
  test(
    'later reader preserves artwork and utilities and defaults new schema fields',
    () async {
      final before = await _hashes();
      final recovery = _Memory();
      final source = await LegacySourceReader().acquireCopiedDirectory(
        directory: _copy,
        layout: _layout(),
        recoveryStorage: recovery,
      );
      final collections = source.snapshot.toJson()['collections'];
      dynamic value(String name) => collections[name][0]['value'];
      for (final name in ['items', 'trackerWidgets', 'toggleWidgets']) {
        expect(value(name)['artworkOptions'], [
          {
            'set': 'OLD',
            'url': 'https://example.invalid/historical.png',
            'artist': '',
          },
        ]);
        expect(value(name)['artworkSet'], 'OLD');
      }
      expect(value('trackerWidgets')['currentValue'], 17);
      expect(value('trackerWidgets')['defaultValue'], 4);
      expect(value('trackerWidgets')['actionOnly'], false);
      expect(value('toggleWidgets')['isActive'], true);
      expect(value('tokenRules')['count'], 1);
      expect(value('tokenRules')['enabled'], false);
      expect(value('tokenRules')['outcomes'][0]['multiplier'], 3);
      expect(value('decks')['trackerWidgets'][0]['actionOnly'], false);
      expect(
        value('artworkPreferences')['lastUsedArtwork'],
        'https://example.invalid/historical.png',
      );
      for (final file in await _copy.list().toList()) {
        if (file is! File) continue;
        final bytes = await file.readAsBytes();
        expect(
          base64Decode(
            jsonDecode(
              recovery.values['raw_file_${sha256.convert(bytes)}']!,
            )['bytes'],
          ),
          bytes,
        );
      }
      final retained = await LegacySourceReader().openRetained(
        layout: _layout(),
        recoveryStorage: recovery,
      );
      expect(retained!.snapshot.toJson(), source.snapshot.toJson());
      expect(await _hashes(), before);
    },
  );
  test(
    'later coordinator preserves live utility state, fresh presets and reopen',
    () async {
      final before = await _hashes();
      final coordinator = await LegacyMigrationCoordinator.createRehearsal();
      addTearDown(() => coordinator.directory.delete(recursive: true));
      final result = await coordinator.rehearse(
        sourceDirectory: _copy,
        layout: _layout(),
      );
      final player = result.state.session.players.first;
      expect(player.tokens.single.amount, 11);
      expect(player.tokens.single.counters['charge'], 4);
      expect(player.tokens.single.artworkOptions.single['artist'], '');
      expect(player.utilities.first.value, 17);
      expect(player.utilities.first.defaultValue, 4);
      expect(player.utilities.last.isActive, true);
      expect(player.rules.single.count, 1);
      expect(player.rules.single.enabled, false);
      expect(player.rules.single.global, false);
      expect(result.state.library['legacyArtworkPreferences'], hasLength(1));
      final fixture = TableFixture(result.state);
      await fixture.initialize();
      addTearDown(fixture.dispose);
      final liveBefore = jsonEncode(fixture.player.toJson());
      final otherId = fixture.controller.session.players[1].id;
      await PresetService(
        fixture.controller,
        fixture.catalog,
      ).load(otherId, result.state.decks.single['id'] as String);
      final fresh = fixture.controller.player(otherId);
      expect(fresh.tokens.single.amount, 0);
      expect(fresh.utilities.first.value, 4);
      expect(fresh.utilities.last.isActive, false);
      expect(jsonEncode(fixture.player.toJson()), liveBefore);
      final reopened = await LegacyMigrationCoordinator.reopenRehearsal(
        coordinator.directory,
      );
      final retry = await reopened.rehearse(layout: _layout());
      expect(retry.alreadyPromoted, true);
      expect(retry.transactionId, result.transactionId);
      expect(retry.state.toJson(), result.state.toJson());
      expect(await _hashes(), before);
    },
  );
}
