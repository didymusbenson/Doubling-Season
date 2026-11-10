import '../storage/storage_namespace.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:doubling_season/models/heart_style.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'legacy_support_continuity.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Optional, non-consumable cosmetic support. Product identifiers are supplied
/// by this app's release configuration. Original purchase continuity is dormant
/// unless explicitly requested in a verified same-app native update.
class TableSupportService extends ChangeNotifier {
  static final instance = TableSupportService._();
  TableSupportService._()
    : _storeOverride = null,
      _productIds = productIds,
      _legacyContinuityRequested = LegacySupportContinuity.requested,
      _packageNameLoader = _installedPackageName;

  @visibleForTesting
  TableSupportService.forTesting({
    required InAppPurchase store,
    required List<String> configuredProductIds,
    bool legacyContinuityRequested = false,
    Future<String> Function()? packageNameLoader,
  }) : _storeOverride = store,
       _productIds = configuredProductIds,
       _legacyContinuityRequested = legacyContinuityRequested,
       _packageNameLoader = packageNameLoader ?? _installedPackageName;
  static const productIds = [
    String.fromEnvironment('TABLE_SUPPORT_THANKS_ID'),
    String.fromEnvironment('TABLE_SUPPORT_PLAY_ID'),
    String.fromEnvironment('TABLE_SUPPORT_COLLECTOR_ID'),
  ];
  static const tierNames = ['Say thanks', 'Play Booster', 'Collector Booster'];
  final InAppPurchase? _storeOverride;
  final List<String> _productIds;
  final bool _legacyContinuityRequested;
  final Future<String> Function() _packageNameLoader;
  bool _legacyContinuityEnabled = false;
  String? _legacyHeartStyleId;
  bool _hasTableHeartColor = false;

  static Future<String> _installedPackageName() async =>
      (await PackageInfo.fromPlatform()).packageName;

  /// Preserve original tier colors and named/gradient collector badges. An
  /// explicit Table collector color choice takes priority over the old style.
  HeartStyle? get legacyHeartStyle {
    if (!_legacyContinuityEnabled || tier == 0) return null;
    if (tier == 1) return HeartStyle.red();
    if (tier == 2) return HeartStyle.blue();
    if (_hasTableHeartColor) return null;
    return HeartStyle.getAllStyles().firstWhere(
      (style) => style.id == _legacyHeartStyleId,
      orElse: HeartStyle.rainbow,
    );
  }

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
  Future<void> _updateQueue = Future<void>.value();
  bool _disposed = false;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

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
    _notify();
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedOwnership = prefs.get(TableStorageKeys.supportOwned);
      if (savedOwnership is List) {
        owned.addAll(savedOwnership.whereType<String>());
      }
      final savedColor = prefs.get(TableStorageKeys.supportColor);
      _hasTableHeartColor = savedColor is int;
      if (savedColor is int) heartColor = savedColor;
      if (_legacyContinuityRequested) {
        _legacyContinuityEnabled = LegacySupportContinuity.isCompatible(
          requested: true,
          isWeb: kIsWeb,
          platform: defaultTargetPlatform,
          storageNamespace: tableStorageNamespace,
          packageName: kIsWeb || tableStorageNamespace.isNotEmpty
              ? ''
              : await _packageNameLoader(),
          configuredProductIds: _productIds,
        );
        if (!_legacyContinuityEnabled) {
          available = false;
          products = [];
          _setMessage(
            'Original support purchases require the verified original app and product configuration. Purchases are disabled in this build.',
          );
          return;
        }
        owned.addAll(LegacySupportContinuity.cachedOwnership(prefs));
        _legacyHeartStyleId = LegacySupportContinuity.cachedHeartStyle(prefs);
      }
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
        (updates) {
          // Purchase callbacks can overlap while preference writes are pending.
          // Serialize them so a later tier never overwrites an earlier one.
          _updateQueue = _updateQueue.then((_) => _updates(updates));
        },
        onError: (Object e) {
          pending = false;
          _setMessage(
            'The store could not finish this request. Try again later.',
          );
          _notify();
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
      _notify();
    }
  }

  Future<void> buy(ProductDetails product) async {
    if (!available ||
        loading ||
        pending ||
        restoring ||
        owned.contains(product.id) ||
        !_productIds.contains(product.id) ||
        !products.any((candidate) => candidate.id == product.id)) {
      return;
    }
    pending = true;
    _setMessage(null);
    _notify();
    try {
      final started = await _store.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
      if (!started) {
        pending = false;
        _setMessage('The purchase did not start. Please try again.');
        _notify();
      }
    } catch (_) {
      pending = false;
      _setMessage('The store could not start the purchase.');
      _notify();
    }
  }

  Future<void> restore() async {
    if (!available || pending || restoring) return;
    restoring = true;
    _setMessage(null);
    _notify();
    try {
      await _store.restorePurchases();
    } catch (_) {
      _setMessage(
        'Purchases could not be restored. Try again when the store is available.',
      );
    } finally {
      restoring = false;
    }
    _notify();
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
          final prefs = await SharedPreferences.getInstance();
          final updatedOwned = {...owned, purchase.productID};
          if (!await prefs.setStringList(
            TableStorageKeys.supportOwned,
            updatedOwned.toList(),
          )) {
            throw StateError('Support ownership was not persisted');
          }
          if (_legacyContinuityEnabled) {
            final key = LegacySupportContinuity.purchaseKeyFor(
              purchase.productID,
            )!;
            // Keep the original cache usable if the previous version is opened
            // again. Never clear another tier or claim a different product ID.
            if (!await prefs.setBool(key, true)) {
              throw StateError('Original support ownership was not persisted');
            }
          }
          owned.add(purchase.productID);
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
    _notify();
  }

  Future<void> setHeartColor(int color) async {
    if (tier < 3) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setInt(TableStorageKeys.supportColor, color)) {
        throw StateError('Support color was not persisted');
      }
      heartColor = color;
      _hasTableHeartColor = true;
    } catch (_) {
      _setMessage('Your badge color could not be saved. Please try again.');
    }
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
