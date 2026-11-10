import 'package:doubling_season/models/deck.dart';
import 'package:doubling_season/models/item.dart';
import 'package:doubling_season/models/token_template.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tripling_table/features/preset_service.dart';
import 'package:tripling_table/migration/legacy_migration.dart';
import 'package:tripling_table/migration/legacy_migration_journal.dart';
import 'package:tripling_table/migration/legacy_snapshot_capture.dart';
import 'package:tripling_table/services/legacy_support_continuity.dart';
import 'package:tripling_table/services/table_support_service.dart';
import 'package:tripling_table/storage/storage_namespace.dart';

import 'support/table_fixture.dart';

class _FixtureStorage extends LegacyMigrationStorage {
  final records = <String, String>{};

  @override
  Future<String?> read(String key) async => records[key];
  @override
  Future<void> write(String key, String value) async => records[key] = value;
  @override
  Future<void> flush() async {}
}

class _OfflineStore extends Fake implements InAppPurchase {
  int availabilityChecks = 0;

  @override
  Future<bool> isAvailable() async {
    availabilityChecks++;
    return false;
  }
}

LegacyMigrationSnapshot _snapshot(Map<String, dynamic> preferences) {
  final item = Item(
    name: 'Original Saproling',
    pt: '1/1',
    abilities: '',
    colors: 'G',
    type: 'Creature',
    amount: 9,
    tapped: 3,
    summoningSick: 2,
    plusOneCounters: 4,
  );
  return LegacyMigrationSnapshot(
    LegacySnapshotCapture.capture(
      sourceId: 'combined-safety-fixture',
      sourceVersion: 'repository-0273043-not-shipped-evidence',
      capturedAt: DateTime.utc(2026, 11, 10),
      items: {1: item},
      decks: {
        1: Deck(
          name: 'Original setup',
          templates: [TokenTemplate.fromItem(item)],
        ),
      },
      trackerWidgets: {},
      toggleWidgets: {},
      artworkPreferences: {},
      customTokens: {},
      tokenRules: {},
      preferences: preferences,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  });
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test(
    'captured live state and saved setup remain separate through commit',
    () async {
      final journal = LegacyMigrationJournal(_FixtureStorage());
      final staged = await journal.prepare(
        _snapshot({'artworkDisplayStyle': 'fadeout'}),
        localMedia: {},
      );
      expect(staged.blockers, isEmpty);
      await journal.commit(staged.transactionId);
      final reopened = (await journal.openCommitted())!;
      final fixture = TableFixture(reopened.state);
      await fixture.initialize();
      addTearDown(fixture.dispose);
      final live = fixture.player.tokens.single;
      expect(
        [live.amount, live.tapped, live.summoningSick, live.plusOneCounters],
        [9, 3, 2, 4],
      );
      final other = fixture.controller.session.players[1].id;
      await PresetService(
        fixture.controller,
        fixture.catalog,
      ).load(other, reopened.state.decks.single['id'] as String);
      final fresh = fixture.controller.player(other).tokens.single;
      expect(
        [
          fresh.amount,
          fresh.tapped,
          fresh.summoningSick,
          fresh.plusOneCounters,
        ],
        [0, 0, 0, 0],
      );
      expect(fresh.extra['artworkDisplayStyle'], 'fadeout');
      expect(fixture.player.tokens.single.id, live.id);
      expect(fixture.player.tokens.single.amount, 9);
    },
  );

  test(
    'retained supporter evidence never imports ownership into local preferences',
    () async {
      final archive = {
        'purchased_collector': true,
        'collector_heart_style': 'azorius',
        TableStorageKeys.supportOwned: LegacySupportContinuity.productIds,
      };
      final journal = LegacyMigrationJournal(_FixtureStorage());
      final staged = await journal.prepare(_snapshot(archive), localMedia: {});
      final committed = await journal.commit(staged.transactionId);
      expect(committed.state.library['legacyPreferences'], archive);
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getKeys(), isEmpty);
      final store = _OfflineStore();
      final service = TableSupportService.forTesting(
        store: store,
        configuredProductIds: LegacySupportContinuity.productIds,
        legacyContinuityRequested: true,
        packageNameLoader: () async => 'com.loosetie.doublingseason',
      );
      addTearDown(service.dispose);
      await service.initialize();
      expect(service.owned, isEmpty);
      expect(service.tier, 0);
      expect(preferences.getKeys(), isEmpty);
    },
  );

  test(
    'older retained evidence cannot revoke current offline ownership',
    () async {
      SharedPreferences.setMockInitialValues({
        'purchased_collector': true,
        'collector_heart_style': 'azorius',
        'unrelated': 'preserved',
      });
      final journal = LegacyMigrationJournal(_FixtureStorage());
      final snapshot = _snapshot({'purchased_collector': false});
      final staged = await journal.prepare(snapshot, localMedia: {});
      await journal.commit(staged.transactionId);
      final store = _OfflineStore();
      final service = TableSupportService.forTesting(
        store: store,
        configuredProductIds: LegacySupportContinuity.productIds,
        legacyContinuityRequested: true,
        packageNameLoader: () async => 'com.loosetie.doublingseason',
      );
      addTearDown(service.dispose);
      await service.initialize();
      await journal.prepare(snapshot, localMedia: {});
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getBool('purchased_collector'), isTrue);
      expect(preferences.getString('collector_heart_style'), 'azorius');
      expect(preferences.getString('unrelated'), 'preserved');
      if (tableStorageNamespace.isEmpty) {
        expect(service.tier, 3);
        expect(service.legacyHeartStyle?.id, 'azorius');
        expect(store.availabilityChecks, 1);
      } else {
        expect(service.tier, 0);
        expect(service.legacyHeartStyle, isNull);
        expect(store.availabilityChecks, 0);
      }
    },
  );
}
