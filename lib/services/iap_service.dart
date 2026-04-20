import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Singleton managing the three-tier "tip jar" IAP system.
///
/// Tiers are non-consumable purchases. The highest-owned tier determines the
/// heart badge shown on the About screen. Purchase state is cached in
/// SharedPreferences so the UI has instant access offline.
class IAPService {
  static final IAPService _instance = IAPService._internal();
  factory IAPService() => _instance;
  IAPService._internal();

  static const String thankYouId = 'com.loosetie.doublingseason.thank_you';
  static const String playId = 'com.loosetie.doublingseason.play';
  static const String collectorId = 'com.loosetie.doublingseason.collector';

  static const String _thankYouKey = 'purchased_thank_you';
  static const String _playKey = 'purchased_play';
  static const String _collectorKey = 'purchased_collector';
  static const String heartStyleKey = 'collector_heart_style';

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;

  bool _hasThankYou = false;
  bool _hasPlay = false;
  bool _hasCollector = false;

  List<ProductDetails> _products = [];

  final _purchaseController = StreamController<PurchaseDetails>.broadcast();
  Stream<PurchaseDetails> get purchaseStream => _purchaseController.stream;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      final available = await _iap.isAvailable();
      if (!available) {
        debugPrint('IAP not available on this device');
        // Still load cached state so previously-purchased users see their tier.
        await _loadCachedPurchases();
        return false;
      }

      await _loadCachedPurchases();

      _purchaseSubscription = _iap.purchaseStream.listen(
        _handlePurchaseUpdate,
        onDone: () => _purchaseSubscription?.cancel(),
        onError: (error) => debugPrint('Purchase stream error: $error'),
      );

      await restorePurchases();

      _isInitialized = true;
      debugPrint('IAP service initialized successfully');
      return true;
    } catch (e) {
      debugPrint('Error initializing IAP: $e');
      return false;
    }
  }

  Future<bool> isAvailable() async {
    return await _iap.isAvailable();
  }

  Future<List<ProductDetails>> getProducts() async {
    try {
      final Set<String> productIds = {thankYouId, playId, collectorId};
      final ProductDetailsResponse response =
          await _iap.queryProductDetails(productIds);

      if (response.error != null) {
        debugPrint('Error querying products: ${response.error}');
        return [];
      }

      if (response.notFoundIDs.isNotEmpty) {
        debugPrint('Products not found: ${response.notFoundIDs}');
      }

      _products = response.productDetails;
      return _products;
    } catch (e) {
      debugPrint('Error getting products: $e');
      return [];
    }
  }

  Future<void> buyProduct(String productId) async {
    ProductDetails? product;
    try {
      product = _products.firstWhere((p) => p.id == productId);
    } catch (e) {
      throw Exception('Product not found: $productId');
    }

    final PurchaseParam purchaseParam = PurchaseParam(
      productDetails: product,
      applicationUserName: null,
    );

    try {
      await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      debugPrint('Error buying product: $e');
      rethrow;
    }
  }

  Future<void> restorePurchases() async {
    try {
      await _iap.restorePurchases();
      debugPrint('Restore purchases initiated');
    } catch (e) {
      debugPrint('Error restoring purchases: $e');
      rethrow;
    }
  }

  void _handlePurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) {
    for (final PurchaseDetails purchase in purchaseDetailsList) {
      if (purchase.status == PurchaseStatus.pending) {
        debugPrint('Purchase pending: ${purchase.productID}');
      } else if (purchase.status == PurchaseStatus.error) {
        debugPrint('Purchase error: ${purchase.error}');
      } else if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        _verifyAndDeliverPurchase(purchase);
      } else if (purchase.status == PurchaseStatus.canceled) {
        debugPrint('Purchase canceled: ${purchase.productID}');
      }

      if (purchase.pendingCompletePurchase) {
        _iap.completePurchase(purchase);
      }

      _purchaseController.add(purchase);
    }
  }

  Future<void> _verifyAndDeliverPurchase(PurchaseDetails purchase) async {
    final String productId = purchase.productID;
    debugPrint('Delivering purchase: $productId');

    switch (productId) {
      case thankYouId:
        _hasThankYou = true;
        await _savePurchase(_thankYouKey, true);
        break;
      case playId:
        _hasPlay = true;
        await _savePurchase(_playKey, true);
        break;
      case collectorId:
        _hasCollector = true;
        await _savePurchase(_collectorKey, true);
        break;
      default:
        debugPrint('Unknown product ID: $productId');
    }
  }

  Future<void> _loadCachedPurchases() async {
    final prefs = await SharedPreferences.getInstance();
    _hasThankYou = prefs.getBool(_thankYouKey) ?? false;
    _hasPlay = prefs.getBool(_playKey) ?? false;
    _hasCollector = prefs.getBool(_collectorKey) ?? false;
    debugPrint(
      'Loaded cached purchases - Thank You: $_hasThankYou, Play: $_hasPlay, Collector: $_hasCollector',
    );
  }

  Future<void> _savePurchase(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  bool hasThankYouTier() => _hasThankYou;
  bool hasPlayTier() => _hasPlay;
  bool hasCollectorTier() => _hasCollector;

  bool canAccessThankYouFeatures() =>
      _hasThankYou || _hasPlay || _hasCollector;
  bool canAccessPlayFeatures() => _hasPlay || _hasCollector;
  bool canAccessCollectorFeatures() => _hasCollector;

  bool hasAnyTier() => _hasThankYou || _hasPlay || _hasCollector;

  bool shouldShowRedHeart() =>
      _hasThankYou && !_hasPlay && !_hasCollector;
  bool shouldShowBlueHeart() => _hasPlay && !_hasCollector;
  bool shouldShowRainbowHeart() => _hasCollector;

  void dispose() {
    _purchaseSubscription?.cancel();
    _purchaseController.close();
  }
}
