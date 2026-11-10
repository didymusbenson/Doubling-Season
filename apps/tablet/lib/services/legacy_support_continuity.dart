import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Compatibility contract for a future update of the original native app.
/// It does not transfer purchases between separate apps or browser previews.
abstract final class LegacySupportContinuity {
  static const requested = bool.fromEnvironment(
    'TABLE_LEGACY_SUPPORT_CONTINUITY',
  );
  static const productIds = [
    'com.loosetie.doublingseason.thank_you',
    'com.loosetie.doublingseason.play',
    'com.loosetie.doublingseason.collector',
  ];
  static const purchaseKeys = [
    'purchased_thank_you',
    'purchased_play',
    'purchased_collector',
  ];
  static const heartStyleKey = 'collector_heart_style';

  /// Fail closed until both the original native identity and exact product
  /// configuration are present. A build flag alone is not proof of identity.
  static bool isCompatible({
    required bool requested,
    required bool isWeb,
    required TargetPlatform platform,
    required String storageNamespace,
    required String packageName,
    required List<String> configuredProductIds,
  }) =>
      requested &&
      !isWeb &&
      storageNamespace.isEmpty &&
      switch (platform) {
        TargetPlatform.android => packageName == 'com.loosetie.doublingseason',
        TargetPlatform.iOS => packageName == 'LooseTie.Doubling-Season',
        _ => false,
      } &&
      listEquals(configuredProductIds, productIds);

  static Set<String> cachedOwnership(SharedPreferences preferences) => {
    for (var i = 0; i < productIds.length; i++)
      if (preferences.get(purchaseKeys[i]) == true) productIds[i],
  };

  static String? cachedHeartStyle(SharedPreferences preferences) {
    final value = preferences.get(heartStyleKey);
    return value is String ? value : null;
  }

  static String? purchaseKeyFor(String productId) {
    final index = productIds.indexOf(productId);
    return index < 0 ? null : purchaseKeys[index];
  }
}
