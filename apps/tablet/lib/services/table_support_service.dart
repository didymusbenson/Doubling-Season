import '../storage/storage_namespace.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Optional, non-consumable cosmetic support. Product identifiers are supplied
/// by this app's release configuration, never borrowed from the phone product.
class TableSupportService extends ChangeNotifier {
  static final instance = TableSupportService._();
  TableSupportService._() : _storeOverride = null, _productIds = productIds;

  @visibleForTesting
  TableSupportService.forTesting({
    required InAppPurchase store,
    required List<String> configuredProductIds,
  }) : _storeOverride = store,
       _productIds = configuredProductIds;
  static const productIds = [
    String.fromEnvironment('TABLE_SUPPORT_THANKS_ID'),
    String.fromEnvironment('TABLE_SUPPORT_PLAY_ID'),
    String.fromEnvironment('TABLE_SUPPORT_COLLECTOR_ID'),
  ];
  static const tierNames = ['Say thanks', 'Play Booster', 'Collector Booster'];
  final InAppPurchase? _storeOverride;
  final List<String> _productIds;
  InAppPurchase get _store => _storeOverride ?? InAppPurchase.instance;
  final Set<String> owned = {};
  List<ProductDetails> products = [];
  bool loading = false, pending = false, restoring = false, available = false;
  String? _message;
  (String, String?)? _messagePurchase;
  int _messageGeneration = 0;
  String? get message =>
      _message ??
      (pending
          ? 'Waiting for the store…'
          : restoring
          ? 'Checking the store for your support purchases…'
          : null);
  int heartColor = 0xff93bd9b;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  Future<void>? _initialization;

  void _setMessage(String? value, {PurchaseDetails? purchase}) {
    _message = value;
    _messagePurchase = purchase == null
        ? null
        : (purchase.productID, purchase.purchaseID);
    _messageGeneration++;
  }

  int get tier {
    for (var i = _productIds.length - 1; i >= 0; i--) {
      if (_productIds[i].isNotEmpty && owned.contains(_productIds[i])) {
        return i + 1;
      }
    }
    return 0;
  }

  Future<void> initialize() {
    if (_initialization != null) return _initialization!;
    if (available && products.length == _productIds.length) {
      return Future<void>.value();
    }
    return _initialization = _initialize().whenComplete(() {
      _initialization = null;
    });
  }

  Future<void> _initialize() async {
    loading = true;
    _setMessage(null);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      owned.addAll(prefs.getStringList(TableStorageKeys.supportOwned) ?? []);
      heartColor = prefs.getInt(TableStorageKeys.supportColor) ?? heartColor;
      if (kIsWeb || _productIds.any((id) => id.isEmpty)) {
        _setMessage(
          'Support purchases aren’t available in this build. All gameplay is included.',
        );
        return;
      }
      available = await _store.isAvailable();
      if (!available) {
        _setMessage(
          'The store is unavailable. Your existing supporter badge is still available offline.',
        );
        return;
      }
      _subscription ??= _store.purchaseStream.listen(
        _updates,
        onError: (Object e) {
          pending = false;
          _setMessage(
            'The store could not finish this request. Try again later.',
          );
          notifyListeners();
        },
      );
      final result = await _store.queryProductDetails(_productIds.toSet());
      products = result.productDetails;
      if (result.error != null || products.length != _productIds.length) {
        _setMessage(
          'Some support options are temporarily unavailable from the store.',
        );
      }
    } catch (_) {
      _setMessage(
        'The store could not be opened. All gameplay remains available.',
      );
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> buy(ProductDetails product) async {
    if (pending || restoring || owned.contains(product.id)) return;
    pending = true;
    _setMessage(null);
    notifyListeners();
    try {
      final started = await _store.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
      if (!started) {
        pending = false;
        _setMessage('The purchase did not start. Please try again.');
        notifyListeners();
      }
    } catch (_) {
      pending = false;
      _setMessage('The store could not start the purchase.');
      notifyListeners();
    }
  }

  Future<void> restore() async {
    if (!available || pending || restoring) return;
    restoring = true;
    _setMessage(null);
    notifyListeners();
    try {
      await _store.restorePurchases();
    } catch (_) {
      _setMessage(
        'Purchases could not be restored. Try again when the store is available.',
      );
    } finally {
      restoring = false;
    }
    notifyListeners();
  }

  Future<void> _updates(List<PurchaseDetails> updates) async {
    for (final purchase in updates) {
      if (!_productIds.contains(purchase.productID)) continue;
      pending = purchase.status == PurchaseStatus.pending;
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        final previousMessageGeneration = _messageGeneration;
        final resolvesPreviousError =
            _messagePurchase == (purchase.productID, purchase.purchaseID);
        try {
          owned.add(purchase.productID);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setStringList(TableStorageKeys.supportOwned, owned.toList());
          if (purchase.pendingCompletePurchase) {
            await _store.completePurchase(purchase);
          }
          if (resolvesPreviousError &&
              _messageGeneration == previousMessageGeneration) {
            _setMessage(null);
          }
        } catch (_) {
          _setMessage(
            'Your purchase was received, but its badge could not be saved. Use Restore purchases to retry.',
            purchase: purchase,
          );
        }
      } else if (purchase.status == PurchaseStatus.error) {
        _setMessage(
          purchase.error?.message ?? 'The purchase was not completed.',
          purchase: purchase,
        );
      }
    }
    notifyListeners();
  }

  Future<void> setHeartColor(int color) async {
    if (tier < 3) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(TableStorageKeys.supportColor, color);
    heartColor = color;
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
