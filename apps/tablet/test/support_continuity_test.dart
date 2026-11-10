import 'dart:async';

import 'package:doubling_season/models/heart_style.dart';
import 'package:doubling_season/services/iap_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:tripling_table/services/legacy_support_continuity.dart';
import 'package:tripling_table/services/table_support_service.dart';
import 'package:tripling_table/storage/storage_namespace.dart';

class _Store extends Fake implements InAppPurchase {
  final updates = StreamController<List<PurchaseDetails>>.broadcast();
  bool available = true;
  Object? availabilityError;
  int queries = 0, restores = 0, purchases = 0;
  final completed = <String>[];
  Future<void> Function(PurchaseDetails)? beforeCompletion;

  @override
  Future<bool> isAvailable() async {
    if (availabilityError != null) throw availabilityError!;
    return available;
  }

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => updates.stream;

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> ids) async {
    queries++;
    return ProductDetailsResponse(
      productDetails: ids.map(_product).toList(),
      notFoundIDs: [],
    );
  }

  @override
  Future<void> restorePurchases({String? applicationUserName}) async {
    restores++;
  }

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    purchases++;
    return true;
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    await beforeCompletion?.call(purchase);
    completed.add(purchase.productID);
  }

  void emit(String id, PurchaseStatus status, {bool complete = true}) {
    updates.add([
      PurchaseDetails(
        productID: id,
        purchaseID: 'transaction-$id',
        verificationData: PurchaseVerificationData(
          localVerificationData: '',
          serverVerificationData: '',
          source: 'test',
        ),
        transactionDate: null,
        status: status,
      )..pendingCompletePurchase = complete,
    ]);
  }
}

class _FailingPreferences extends InMemorySharedPreferencesStore {
  _FailingPreferences(super.data) : super.withData();
  String? failedKey;
  bool throws = false;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (key == failedKey) {
      if (throws) throw StateError('test write failed');
      return false;
    }
    return super.setValue(valueType, key, value);
  }
}

ProductDetails _product(String id) => ProductDetails(
  id: id,
  title: id,
  description: 'Support',
  price: 'Test price',
  rawPrice: 1,
  currencyCode: 'USD',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const ids = LegacySupportContinuity.productIds;
  const keys = LegacySupportContinuity.purchaseKeys;
  late _Store store;
  final services = <TableSupportService>[];

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    store = _Store();
  });

  tearDown(() async {
    for (final service in services) {
      service.dispose();
    }
    services.clear();
    await store.updates.close();
    debugDefaultTargetPlatformOverride = null;
  });

  Future<TableSupportService> create({
    bool requested = true,
    String packageName = 'com.loosetie.doublingseason',
    List<String> configuredIds = ids,
  }) async {
    final service = TableSupportService.forTesting(
      store: store,
      configuredProductIds: configuredIds,
      legacyContinuityRequested: requested,
      packageNameLoader: () async => packageName,
    );
    services.add(service);
    await service.initialize();
    return service;
  }

  Future<void> flush() => Future<void>.delayed(Duration.zero);

  test('compatibility contract matches the original IAP implementation', () {
    expect(ids, [
      IAPService.thankYouId,
      IAPService.playId,
      IAPService.collectorId,
    ]);
    expect(LegacySupportContinuity.heartStyleKey, IAPService.heartStyleKey);
  });

  test('guard admits only explicit matching original native identities', () {
    bool permitted({
      bool requested = true,
      bool web = false,
      TargetPlatform platform = TargetPlatform.android,
      String namespace = '',
      String package = 'com.loosetie.doublingseason',
      List<String> products = ids,
    }) => LegacySupportContinuity.isCompatible(
      requested: requested,
      isWeb: web,
      platform: platform,
      storageNamespace: namespace,
      packageName: package,
      configuredProductIds: products,
    );
    expect(permitted(), isTrue);
    expect(
      permitted(
        platform: TargetPlatform.iOS,
        package: 'LooseTie.Doubling-Season',
      ),
      isTrue,
    );
    expect(permitted(requested: false), isFalse);
    expect(permitted(web: true), isFalse);
    expect(permitted(namespace: 'phone_preview_v1'), isFalse);
    expect(permitted(package: 'com.loosetie.triplingtable'), isFalse);
    expect(permitted(platform: TargetPlatform.linux), isFalse);
    expect(permitted(products: ids.reversed.toList()), isFalse);
    expect(permitted(products: ['thanks', 'play', 'collector']), isFalse);
    expect(permitted(products: ['', '', '']), isFalse);
  });

  test(
    'ordinary tablet mode never reads original purchase or cosmetic cache',
    () async {
      SharedPreferences.setMockInitialValues({
        keys[2]: true,
        LegacySupportContinuity.heartStyleKey: 'azorius',
      });
      final service = await create(requested: false);
      expect(service.owned, isEmpty);
      expect(service.tier, 0);
      expect(service.legacyHeartStyle, isNull);
    },
  );

  test(
    'wrong identity or product mapping disables purchase and restore',
    () async {
      SharedPreferences.setMockInitialValues({keys[2]: true});
      for (final configuration in [
        ('com.loosetie.triplingtable', ids),
        ('com.loosetie.doublingseason', ['thanks', 'play', 'collector']),
      ]) {
        final service = await create(
          packageName: configuration.$1,
          configuredIds: configuration.$2,
        );
        expect(service.available, isFalse);
        expect(service.owned, isEmpty);
        expect(service.message, contains('Purchases are disabled'));
        await service.restore();
        await service.buy(_product(configuration.$2.first));
      }
      expect(store.queries, 0);
      expect(store.restores, 0);
      expect(store.purchases, 0);
    },
  );

  test(
    'explicit preview cannot read original preferences or contact store',
    () async {
      SharedPreferences.setMockInitialValues({keys[2]: true});
      final service = await create();
      expect(service.owned, isEmpty);
      expect(service.available, isFalse);
      expect(store.queries, 0);
    },
    skip: tableStorageNamespace.isEmpty,
  );

  group('verified original update', () {
    for (var tier = 0; tier < ids.length; tier++) {
      test(
        'tier ${tier + 1} survives offline without writing or erasing preferences',
        () async {
          final initial = <String, Object>{
            keys[tier]: true,
            LegacySupportContinuity.heartStyleKey: 'temur',
            'unrelated_setting': 'preserve',
          };
          SharedPreferences.setMockInitialValues(initial);
          store.available = false;
          final service = await create();
          expect(service.owned, {ids[tier]});
          expect(service.tier, tier + 1);
          expect(service.legacyHeartStyle!.id, ['red', 'blue', 'temur'][tier]);
          expect(service.available, isFalse);
          final prefs = await SharedPreferences.getInstance();
          expect({
            for (final key in prefs.getKeys()) key: prefs.get(key),
          }, initial);
        },
      );
    }

    test(
      'malformed Table cache does not hide valid original ownership',
      () async {
        SharedPreferences.setMockInitialValues({
          keys[2]: true,
          TableStorageKeys.supportOwned: 'invalid-old-cache',
          TableStorageKeys.supportColor: 'invalid-old-color',
          LegacySupportContinuity.heartStyleKey: 'simic',
        });
        final service = await create();
        expect(service.tier, 3);
        expect(service.legacyHeartStyle!.id, 'simic');
        final preferences = await SharedPreferences.getInstance();
        expect(
          preferences.get(TableStorageKeys.supportOwned),
          'invalid-old-cache',
        );
        expect(
          preferences.get(TableStorageKeys.supportColor),
          'invalid-old-color',
        );
      },
    );

    test(
      'explicit Table color replaces displayed legacy style only after save',
      () async {
        SharedPreferences.setMockInitialValues({
          keys[2]: true,
          LegacySupportContinuity.heartStyleKey: 'azorius',
        });
        final service = await create();
        expect(service.legacyHeartStyle!.id, 'azorius');
        await service.setHeartColor(0xff010203);
        expect(service.heartColor, 0xff010203);
        expect(service.legacyHeartStyle, isNull);
        final reopened = await create();
        expect(reopened.legacyHeartStyle, isNull);
        final preferences = await SharedPreferences.getInstance();
        expect(
          preferences.getString(LegacySupportContinuity.heartStyleKey),
          'azorius',
        );
      },
    );

    test('a store exception cannot remove cached ownership', () async {
      SharedPreferences.setMockInitialValues({keys[2]: true});
      store.availabilityError = StateError('offline');
      final service = await create();
      expect(service.tier, 3);
      expect(service.owned, {ids[2]});
    });

    test(
      'legacy and existing table ownership are combined, never downgraded',
      () async {
        SharedPreferences.setMockInitialValues({
          keys[0]: true,
          TableStorageKeys.supportOwned: [ids[2], 'unknown-retained-id'],
        });
        final service = await create();
        expect(service.tier, 3);
        expect(service.owned, {ids[0], ids[2], 'unknown-retained-id'});
        await service.restore();
        await flush();
        expect(
          service.tier,
          3,
        ); // An empty restore is not evidence of revocation.
        await service.buy(_product(ids[0]));
        expect(
          store.purchases,
          0,
        ); // Do not sell the same non-consumable twice.
      },
    );

    test(
      'malformed legacy values cannot fabricate ownership or break boot',
      () async {
        SharedPreferences.setMockInitialValues({
          keys[0]: 'true',
          keys[1]: 1,
          keys[2]: false,
          LegacySupportContinuity.heartStyleKey: 42,
        });
        final service = await create();
        expect(service.tier, 0);
        expect(service.owned, isEmpty);
      },
    );

    for (final style in HeartStyle.getAllStyles()) {
      test('preserves original ${style.id} collector style', () async {
        SharedPreferences.setMockInitialValues({
          keys[2]: true,
          LegacySupportContinuity.heartStyleKey: style.id,
        });
        final service = await create();
        expect(service.legacyHeartStyle!.id, style.id);
        expect(service.legacyHeartStyle!.type, style.type);
        expect(service.legacyHeartStyle!.colors, style.colors);
        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getString(LegacySupportContinuity.heartStyleKey),
          style.id,
        );
      });
    }

    test(
      'unknown style uses original rainbow fallback without replacing raw value',
      () async {
        SharedPreferences.setMockInitialValues({
          keys[2]: true,
          LegacySupportContinuity.heartStyleKey: 'future-style',
        });
        final service = await create();
        expect(service.legacyHeartStyle!.id, 'rainbow');
        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getString(LegacySupportContinuity.heartStyleKey),
          'future-style',
        );
      },
    );

    test(
      'existing or explicit Table color wins without rewriting original style',
      () async {
        SharedPreferences.setMockInitialValues({
          keys[2]: true,
          LegacySupportContinuity.heartStyleKey: 'azorius',
          TableStorageKeys.supportColor: 0xff010203,
        });
        final service = await create();
        expect(service.heartColor, 0xff010203);
        expect(service.legacyHeartStyle, isNull);
        await service.setHeartColor(0xff040506);
        final reopened = await create();
        expect(reopened.heartColor, 0xff040506);
        expect(reopened.legacyHeartStyle, isNull);
        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getString(LegacySupportContinuity.heartStyleKey),
          'azorius',
        );
      },
    );

    for (final status in [PurchaseStatus.purchased, PurchaseStatus.restored]) {
      test(
        '$status persists exact original IDs before store completion',
        () async {
          SharedPreferences.setMockInitialValues({keys[0]: true});
          final service = await create();
          store.beforeCompletion = (purchase) async {
            final prefs = await SharedPreferences.getInstance();
            expect(prefs.getBool(keys[2]), isTrue);
            expect(
              prefs.getStringList(TableStorageKeys.supportOwned),
              containsAll([ids[0], ids[2]]),
            );
          };
          store.emit(ids[2], status);
          await flush();
          expect(service.tier, 3);
          expect(store.completed, [ids[2]]);
          final reopened = await create();
          expect(reopened.tier, 3);
          final prefs = await SharedPreferences.getInstance();
          expect(prefs.getBool(keys[0]), isTrue);
          expect(prefs.containsKey(keys[1]), isFalse);
        },
      );
    }

    for (final throws in [false, true]) {
      for (final failedKey in [TableStorageKeys.supportOwned, keys[2]]) {
        test(
          'failed $failedKey write (throws: $throws) never completes a purchase',
          () async {
            final persistence =
                _FailingPreferences({'flutter.${keys[0]}': true})
                  ..failedKey = 'flutter.$failedKey'
                  ..throws = throws;
            SharedPreferencesStorePlatform.instance = persistence;
            final service = await create();
            store.emit(ids[2], PurchaseStatus.restored);
            await flush();
            expect(service.tier, 1);
            expect(service.owned, {ids[0]});
            expect(store.completed, isEmpty);
            expect(service.message, contains('could not be saved'));
            persistence.failedKey = null;
            store.emit(ids[2], PurchaseStatus.restored);
            await flush();
            expect(service.tier, 3);
            expect(store.completed, [ids[2]]);
            expect(service.message, isNull);
            final preferences = await SharedPreferences.getInstance();
            await preferences.reload();
            expect(preferences.getBool(keys[2]), isTrue);
            expect(
              preferences.getStringList(TableStorageKeys.supportOwned),
              containsAll([ids[0], ids[2]]),
            );
          },
        );
      }

      test(
        'failed color write (throws: $throws) preserves the displayed legacy style',
        () async {
          final persistence =
              _FailingPreferences({
                  'flutter.${keys[2]}': true,
                  'flutter.${LegacySupportContinuity.heartStyleKey}': 'temur',
                })
                ..failedKey = 'flutter.${TableStorageKeys.supportColor}'
                ..throws = throws;
          SharedPreferencesStorePlatform.instance = persistence;
          final service = await create();
          await service.setHeartColor(0xff010203);
          expect(service.legacyHeartStyle!.id, 'temur');
          expect(service.message, contains('could not be saved'));
          final preferences = await SharedPreferences.getInstance();
          await preferences.reload();
          expect(
            preferences.containsKey(TableStorageKeys.supportColor),
            isFalse,
          );
          expect(
            preferences.getString(LegacySupportContinuity.heartStyleKey),
            'temur',
          );
        },
      );
    }

    test('overlapping restore events retain every original tier', () async {
      final service = await create();
      final completion = Completer<void>();
      store.beforeCompletion = (_) => completion.future;
      store.emit(ids[0], PurchaseStatus.restored);
      store.emit(ids[2], PurchaseStatus.restored);
      await flush();
      completion.complete();
      await flush();
      expect(service.owned, {ids[0], ids[2]});
      expect(service.tier, 3);
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getStringList(TableStorageKeys.supportOwned),
        containsAll([ids[0], ids[2]]),
      );
    });

    test(
      'unknown, canceled, pending and failed purchases never grant ownership',
      () async {
        final service = await create();
        store.emit('different.app.collector', PurchaseStatus.restored);
        for (final status in [
          PurchaseStatus.pending,
          PurchaseStatus.canceled,
          PurchaseStatus.error,
        ]) {
          store.emit(ids[2], status, complete: false);
        }
        await flush();
        expect(service.owned, isEmpty);
        expect(store.completed, isEmpty);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getKeys(), isEmpty);
      },
    );
  }, skip: tableStorageNamespace.isNotEmpty);
}
