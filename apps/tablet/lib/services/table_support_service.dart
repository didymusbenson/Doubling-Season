import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Optional, non-consumable cosmetic support. Product identifiers are supplied
/// by this app's release configuration, never borrowed from the phone product.
class TableSupportService extends ChangeNotifier {
  static final instance = TableSupportService._();
  TableSupportService._();
  static const productIds = [
    String.fromEnvironment('TABLE_SUPPORT_THANKS_ID'),
    String.fromEnvironment('TABLE_SUPPORT_PLAY_ID'),
    String.fromEnvironment('TABLE_SUPPORT_COLLECTOR_ID'),
  ];
  static const tierNames = ['Say thanks', 'Play Booster', 'Collector Booster'];
  final Set<String> owned = {};
  List<ProductDetails> products = [];
  bool loading = false, pending = false, available = false;
  String? message;
  int heartColor = 0xff93bd9b;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  Future<void>? _initialization;
  int get tier {
    for (var i = productIds.length - 1; i >= 0; i--) {
      if (productIds[i].isNotEmpty && owned.contains(productIds[i]))
        return i + 1;
    }
    return 0;
  }

  Future<void> initialize() => _initialization ??= _initialize();
  Future<void> _initialize() async {
    loading = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      owned.addAll(prefs.getStringList('tablet_support_owned_v1') ?? []);
      heartColor = prefs.getInt('tablet_support_heart_color') ?? heartColor;
      if (kIsWeb || productIds.any((id) => id.isEmpty)) {
        message =
            'Support purchases aren’t available in this build. All gameplay is included.';
        return;
      }
      available = await InAppPurchase.instance.isAvailable();
      if (!available) {
        message =
            'The store is unavailable. Your existing supporter badge is still available offline.';
        return;
      }
      _subscription ??= InAppPurchase.instance.purchaseStream.listen(
        _updates,
        onError: (Object e) {
          pending = false;
          message = 'The store could not finish this request. Try again later.';
          notifyListeners();
        },
      );
      final result = await InAppPurchase.instance.queryProductDetails(
        productIds.toSet(),
      );
      products = result.productDetails;
      if (result.error != null || products.length != productIds.length) {
        message =
            'Some support options are temporarily unavailable from the store.';
      }
    } catch (_) {
      message =
          'The store could not be opened. All gameplay remains available.';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> buy(ProductDetails product) async {
    if (pending || owned.contains(product.id)) return;
    pending = true;
    message = 'Waiting for the store…';
    notifyListeners();
    try {
      final started = await InAppPurchase.instance.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
      if (!started) {
        pending = false;
        message = 'The purchase did not start. Please try again.';
        notifyListeners();
      }
    } catch (_) {
      pending = false;
      message = 'The store could not start the purchase.';
      notifyListeners();
    }
  }

  Future<void> restore() async {
    if (!available) return;
    message = 'Checking the store for your support purchases…';
    notifyListeners();
    try {
      await InAppPurchase.instance.restorePurchases();
      message =
          'Restore requested. The store will return any purchases associated with this account.';
    } catch (_) {
      message =
          'Purchases could not be restored. Try again when the store is available.';
    }
    notifyListeners();
  }

  Future<void> _updates(List<PurchaseDetails> updates) async {
    for (final purchase in updates) {
      if (!productIds.contains(purchase.productID)) continue;
      pending = purchase.status == PurchaseStatus.pending;
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        try {
          owned.add(purchase.productID);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setStringList('tablet_support_owned_v1', owned.toList());
          message = 'Thank you for supporting Tripling Table.';
          if (purchase.pendingCompletePurchase)
            await InAppPurchase.instance.completePurchase(purchase);
        } catch (_) {
          message =
              'Your purchase was received, but its badge could not be saved. Use Restore purchases to retry.';
        }
      } else if (purchase.status == PurchaseStatus.error) {
        message = purchase.error?.message ?? 'The purchase was not completed.';
      } else if (purchase.status == PurchaseStatus.canceled) {
        message = 'Purchase canceled.';
      }
    }
    notifyListeners();
  }

  Future<void> setHeartColor(int color) async {
    if (tier < 3) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('tablet_support_heart_color', color);
    heartColor = color;
    notifyListeners();
  }
}
