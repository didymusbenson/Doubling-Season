import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tripling_table/domain/table_state.dart';
import 'package:tripling_table/features/preset_service.dart';
import 'package:tripling_table/migration/legacy_migration.dart';

import 'legacy_migration_test.dart' as migration_fixture;
import 'support/table_fixture.dart';

Map<String, dynamic> phoneDeck() => {
  'name': 'Saved colors',
  'colorIdentity': 'WUBRG',
  'createdAt': '2020-01-01T00:00:00Z',
  'lastModifiedAt': '2026-01-01T00:00:00Z',
  'order': 3.5,
  'customArtworkUrl': 'https://example.test/cover.png',
  'retainedFutureMetadata': {
    'nested': ['keep', 7],
  },
  'templates': [
    {
      'name': 'Saproling',
      'pt': '1/1',
      'colors': 'G',
      'abilities': '',
      'type': 'Creature',
      'order': 2.0,
      'artworkUrl': 'https://example.test/token.png',
      'artworkSet': 'TEST',
      'artworkOptions': [
        {
          'url': 'https://example.test/token.png',
          'set': 'TEST',
          'artist': 'Test artist',
        },
      ],
    },
  ],
  'trackerWidgets': [
    {
      'name': 'Custom tracker',
      'isCustom': true,
      'defaultValue': 3,
      'tapIncrement': 1,
      'longPressIncrement': 4,
      'colorIdentity': 'U',
      'order': 1.0,
    },
  ],
  'toggleWidgets': [
    {
      'name': 'Custom toggle',
      'isCustom': true,
      'onDescription': 'On',
      'offDescription': 'Off',
      'order': 0.0,
    },
  ],
};

void main() {
  late TableFixture f;
  late PresetService service;
  setUp(() async {
    f = TableFixture(stateWithTokens([sampleToken()]));
    await f.initialize();
    service = PresetService(f.controller, f.catalog);
  });
  tearDown(() => f.dispose());

  for (final schema in [1, 2, 3]) {
    test(
      'phone $schema retains raw deck metadata through v4 and phone export',
      () async {
        final deck = phoneDeck();
        final source = jsonEncode({'schemaVersion': schema, 'deck': deck});
        final boardBefore = cloneJson(f.controller.session.toJson());
        final imported = await service.importJson(source);
        expect(imported['legacy'], deck);
        expect(imported['imageUrl'], deck['customArtworkUrl']);
        expect((imported['utilities'] as List).map((u) => u['name']), [
          'Custom toggle',
          'Custom tracker',
        ]);
        expect(f.controller.session.toJson(), boardBefore);
        final beforeExport = cloneJson(f.controller.state.toJson());
        final portable = await service.exportJson(imported['id']);
        final phone =
            jsonDecode(
                  await service.exportJson(
                    imported['id'],
                    phoneCompatible: true,
                  ),
                )
                as Map;
        expect(phone['deck']['colorIdentity'], 'WUBRG');
        expect(f.controller.state.toJson(), beforeExport);
        expect(jsonDecode(source)['deck'], deck);
        final v4 = await service.importJson(portable);
        expect(v4['legacy'], deck);
        expect(v4['tokens'], imported['tokens']);
        expect(v4['utilities'], imported['utilities']);
        final back = await service.importJson(jsonEncode(phone));
        expect(back['legacy']['colorIdentity'], 'WUBRG');
        expect(back['tokens'], phone['deck']['templates']);
        // Raw provenance is detached from the editable/loadable mapped templates.
        imported['tokens'][0]['name'] = 'Changed mapped template';
        expect(imported['legacy']['templates'][0]['name'], 'Saproling');
        expect(v4['tokens'][0]['name'], 'Saproling');
      },
    );
  }

  test(
    'copied-installation preset color identity survives phone export',
    () async {
      final state = LegacyMigrationConverter()
          .convert(LegacyMigrationSnapshot(migration_fixture.fixture()))
          .state;
      final migrated = TableFixture(state);
      await migrated.initialize();
      addTearDown(migrated.dispose);
      final presets = PresetService(migrated.controller, migrated.catalog);
      final before = cloneJson(migrated.controller.state.toJson());
      for (final preset in presets.presets) {
        final exported = jsonDecode(
          await presets.exportJson(preset['id'], phoneCompatible: true),
        );
        expect(exported['deck']['colorIdentity'], 'UG');
      }
      expect(migrated.controller.state.toJson(), before);
    },
  );

  for (final hidden in [false, true]) {
    for (final mana in [false, true]) {
      test('phone omissions separate hidden=$hidden and mana=$mana', () async {
        final p = await service.save(f.playerId, 'Omissions');
        p['utilities'] = [
          {
            'name': 'Custom tracker',
            'kind': 'custom_tracker',
            'defaultValue': 0,
            'visible': !hidden,
            'configuration': {'type': 'tracker', 'isCustom': true},
          },
          if (mana) {'name': 'Mana', 'kind': 'mana_pool', 'visible': true},
        ];
        final before = cloneJson(p);
        final warnings = service.exportWarnings(p['id'], phoneCompatible: true);
        expect(warnings.any((w) => w.contains('visibility')), hidden);
        expect(warnings.any((w) => w.contains('mana pool')), mana);
        expect(service.exportWarnings(p['id']), isEmpty);
        final exported = jsonDecode(
          await service.exportJson(p['id'], phoneCompatible: true),
        );
        expect(exported['omissions'], warnings);
        expect(exported['deck']['trackerWidgets'], hasLength(1));
        expect(p, before);
        final back = await service.importJson(jsonEncode(exported));
        expect(back['utilities'][0]['visible'], true);
      });
    }
  }

  test('phone style and cover omissions do not imply v4 loss', () async {
    f.player.tokens.single.extra['artworkDisplayStyle'] = 'fadeout';
    final p = await service.save(
      f.playerId,
      'Styled',
      imageUrl: 'https://example.test/cover.png',
    );
    final before = cloneJson(p);
    final warnings = service.exportWarnings(p['id'], phoneCompatible: true);
    expect(warnings.any((w) => w.contains('display styles')), true);
    expect(warnings.any((w) => w.contains('cover image')), true);
    expect(service.exportWarnings(p['id']), isEmpty);
    final portable = await service.importJson(
      await service.exportJson(p['id']),
    );
    expect(portable['tokens'][0]['artworkDisplayStyle'], 'fadeout');
    expect(portable['imageUrl'], p['imageUrl']);
    expect(p, before);
  });

  test('new Table setup without legacy metadata still exports', () async {
    f.player.utilities.clear();
    final p = await service.save(f.playerId, 'New');
    final exported = jsonDecode(
      await service.exportJson(p['id'], phoneCompatible: true),
    );
    expect(exported['deck']['colorIdentity'], '');
    expect(exported['omissions'], isEmpty);
  });

  for (final version in [null, 0, -1, 5, '3', 3.5]) {
    test(
      'unsupported version $version refuses before library mutation',
      () async {
        final before = f.repository.encoded;
        await expectLater(
          service.importJson(
            jsonEncode({'schemaVersion': version, 'deck': phoneDeck()}),
          ),
          throwsFormatException,
        );
        expect(f.repository.encoded, before);
        expect(service.presets, isEmpty);
      },
    );
  }

  test(
    'wrong v4 product and malformed legacy color refuse unchanged',
    () async {
      final before = f.repository.encoded;
      await expectLater(
        service.importJson(
          jsonEncode({
            'schemaVersion': 4,
            'product': 'different-product',
            'deck': phoneDeck(),
          }),
        ),
        throwsFormatException,
      );
      await expectLater(
        service.importJson(
          jsonEncode({
            'schemaVersion': 3,
            'deck': phoneDeck()..['colorIdentity'] = 42,
          }),
        ),
        throwsFormatException,
      );
      expect(f.repository.encoded, before);
      expect(service.presets, isEmpty);
    },
  );
}
