import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tripling_table/services/table_support_service.dart';

const _productId = 'test.support';
final _product = ProductDetails(
  id: _productId,
  title: 'Support',
  description: 'Test cosmetic badge',
  price: 'Test price',
  rawPrice: 1,
  currencyCode: 'USD',
);

class _Store extends Fake implements InAppPurchase {
  final updates = StreamController<List<PurchaseDetails>>.broadcast();
  Completer<void>? restoreCompletion;
  Completer<void>? purchaseCompletion;
  int completionFailures = 0;
  bool available = true;
  bool startsPurchase = true;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => updates.stream;

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> ids) async =>
      ProductDetailsResponse(productDetails: [_product], notFoundIDs: []);

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async =>
      startsPurchase;

  @override
  Future<void> restorePurchases({String? applicationUserName}) async {
    await restoreCompletion?.future;
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    await purchaseCompletion?.future;
    if (completionFailures > 0) {
      completionFailures--;
      throw StateError('test completion failed');
    }
  }

  void emit(
    PurchaseStatus status, {
    String? error,
    bool needsCompletion = false,
  }) {
    final purchase = PurchaseDetails(
      purchaseID: 'test-purchase',
      productID: _productId,
      verificationData: PurchaseVerificationData(
        localVerificationData: '',
        serverVerificationData: '',
        source: 'test',
      ),
      transactionDate: null,
      status: status,
    )..pendingCompletePurchase = needsCompletion;
    if (error != null) {
      purchase.error = IAPError(source: 'test', code: 'test', message: error);
    }
    updates.add([purchase]);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Store store;
  late TableSupportService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = _Store();
    service = TableSupportService.forTesting(
      store: store,
      configuredProductIds: [_productId],
    );
    await service.initialize();
  });

  tearDown(() async {
    service.dispose();
    await store.updates.close();
  });

  Future<void> flushUpdates() => Future<void>.delayed(Duration.zero);

  for (final status in [PurchaseStatus.purchased, PurchaseStatus.restored]) {
    test(
      '$status updates the saved badge without acknowledgement text',
      () async {
        await service.buy(_product);
        expect(service.pending, isTrue);
        expect(service.message, 'Waiting for the store…');
        store.emit(status);
        await flushUpdates();
        expect(service.pending, isFalse);
        expect(service.message, isNull);
        expect(service.tier, 1);
        final preferences = await SharedPreferences.getInstance();
        expect(preferences.getStringList('tablet_support_owned_v1'), [
          _productId,
        ]);
      },
    );
  }

  test('cancellation ends progress without acknowledgement text', () async {
    await service.buy(_product);
    store.emit(PurchaseStatus.canceled);
    await flushUpdates();
    expect(service.pending, isFalse);
    expect(service.message, isNull);
    expect(service.owned, isEmpty);
  });

  test(
    'a successful completion retry clears only its resolved failure',
    () async {
      store.completionFailures = 1;
      store.emit(PurchaseStatus.purchased, needsCompletion: true);
      await flushUpdates();
      expect(service.message, contains('could not be saved'));
      store.emit(PurchaseStatus.purchased, needsCompletion: true);
      await flushUpdates();
      expect(service.message, isNull);
      expect(service.tier, 1);
    },
  );

  test('completion retry preserves a newer unrelated store failure', () async {
    store.completionFailures = 1;
    store.emit(PurchaseStatus.purchased, needsCompletion: true);
    await flushUpdates();
    store.purchaseCompletion = Completer<void>();
    store.emit(PurchaseStatus.purchased, needsCompletion: true);
    await flushUpdates();
    store.updates.addError(StateError('test store unavailable'));
    await flushUpdates();
    store.purchaseCompletion!.complete();
    await flushUpdates();
    expect(
      service.message,
      'The store could not finish this request. Try again later.',
    );
    expect(service.tier, 1);
  });

  test('restore shows progress only while the request is active', () async {
    store.restoreCompletion = Completer<void>();
    final restoring = service.restore();
    expect(service.restoring, isTrue);
    expect(service.message, contains('Checking the store'));
    store.restoreCompletion!.complete();
    await restoring;
    expect(service.restoring, isFalse);
    expect(service.message, isNull);
  });

  test('restore completion preserves a newer transaction failure', () async {
    store.restoreCompletion = Completer<void>();
    final restoring = service.restore();
    store.emit(
      PurchaseStatus.error,
      error: 'The store could not verify this purchase.',
    );
    await flushUpdates();
    store.restoreCompletion!.complete();
    await restoring;
    expect(service.restoring, isFalse);
    expect(service.message, 'The store could not verify this purchase.');
    expect(service.owned, isEmpty);
  });

  test('restore completion preserves a newer stream failure', () async {
    store.restoreCompletion = Completer<void>();
    final restoring = service.restore();
    store.updates.addError(StateError('test store unavailable'));
    await flushUpdates();
    store.restoreCompletion!.complete();
    await restoring;
    expect(
      service.message,
      'The store could not finish this request. Try again later.',
    );
    expect(service.restoring, isFalse);
  });

  test(
    'failed start remains a contextual error without pending progress',
    () async {
      store.startsPurchase = false;
      await service.buy(_product);
      expect(service.pending, isFalse);
      expect(service.message, 'The purchase did not start. Please try again.');
    },
  );

  test('failed restore remains a contextual error', () async {
    store.restoreCompletion = Completer<void>();
    final restoring = service.restore();
    store.restoreCompletion!.completeError(
      StateError('test store unavailable'),
    );
    await restoring;
    expect(service.restoring, isFalse);
    expect(service.message, contains('Purchases could not be restored'));
  });

  test('unavailable store retains its explanation', () async {
    service.dispose();
    await store.updates.close();
    store = _Store()..available = false;
    service = TableSupportService.forTesting(
      store: store,
      configuredProductIds: [_productId],
    );
    await service.initialize();
    expect(service.available, isFalse);
    expect(service.message, contains('The store is unavailable'));
  });
}
