# In-App Purchases — Tip Jar

## Overview

Implement a three-tier "tip jar" IAP system identical to French Vanilla's. Users can support the developer with one-time non-consumable purchases at three price points. Each tier unlocks a heart badge displayed in a credits/about screen.

**Reference implementation:** `/Users/didymusbenson/Documents/Repos/French-Vanilla/`

## Products

All three are **non-consumable** (one-time permanent purchase).

| Tier | Product ID | Badge | Approx Price |
|------|-----------|-------|-------------|
| Thank You | `com.loosetie.doublingseason.thank_you` | Red heart | ~$1.99 |
| Play | `com.loosetie.doublingseason.play` | Blue heart | ~$5.49 |
| Collector | `com.loosetie.doublingseason.collector` | Rainbow/customizable heart | ~$26.99 |

**Note:** Product IDs use the Android application ID prefix (`com.loosetie.doublingseason`). These must be created in both App Store Connect (under iOS bundle ID `LooseTie.Doubling-Season`) and Google Play Console (under `com.loosetie.doublingseason`).

## Architecture

### Dependency

Add to `pubspec.yaml`:
```yaml
in_app_purchase: ^3.2.0
```
(`shared_preferences` is already a project dependency.)

### Files to Create

| File | Role | Based On |
|------|------|----------|
| `lib/services/iap_service.dart` | Singleton service — all IAP logic | French Vanilla's `iap_service.dart` |
| `lib/widgets/purchase_menu.dart` | Modal bottom sheet for tier selection | French Vanilla's `purchase_menu.dart` |
| `lib/models/heart_style.dart` | Data model for heart badge styles (26 styles) | French Vanilla's `heart_style.dart` |
| `lib/widgets/heart_icon.dart` | Reusable gradient heart widget | French Vanilla's `heart_icon.dart` |
| `lib/screens/heart_customization_screen.dart` | Collector-only heart customization | French Vanilla's `heart_customization_screen.dart` |

### Integration Points

| Where | What |
|-------|------|
| `lib/main.dart` | Call `await IAPService().initialize()` before `runApp()` |
| `lib/main.dart` (root widget dispose) | Call `IAPService().dispose()` |
| Credits/About screen | Add heart badge display + "Support Doubling Season" button |

## IAPService Design

Singleton pattern (no Provider needed). Exact copy of French Vanilla's service with updated product IDs.

### Product ID Constants
```dart
static const String thankYouId = 'com.loosetie.doublingseason.thank_you';
static const String playId = 'com.loosetie.doublingseason.play';
static const String collectorId = 'com.loosetie.doublingseason.collector';
```

### SharedPreferences Keys
```dart
static const String _thankYouKey = 'purchased_thank_you';
static const String _playKey = 'purchased_play';
static const String _collectorKey = 'purchased_collector';
static const String _heartStyleKey = 'collector_heart_style';
```

### Initialization Flow
1. Check `_iap.isAvailable()`
2. Load cached purchases from SharedPreferences
3. Subscribe to `_iap.purchaseStream`
4. Call `restorePurchases()` to sync with platform
5. Set `_isInitialized = true`

### Purchase Flow
1. `PurchaseMenu` calls `getProducts()` in `initState` to load product details from store
2. User taps a tier card → `buyProduct(productId)` called
3. Platform shows native purchase UI
4. Result arrives via purchase stream → `_handlePurchaseUpdate()`
5. On success: `_verifyAndDeliverPurchase()` updates in-memory bools + saves to SharedPreferences
6. Always call `_iap.completePurchase()` for purchases with `pendingCompletePurchase`
7. UI shows success dialog, then dismisses purchase menu

### Tier Hierarchy
```dart
// Feature access — higher tiers include lower
canAccessThankYouFeatures() => _hasThankYou || _hasPlay || _hasCollector;
canAccessPlayFeatures()     => _hasPlay || _hasCollector;
canAccessCollectorFeatures() => _hasCollector;

// Badge display — exclusive to highest owned tier
shouldShowRedHeart()     => _hasThankYou && !_hasPlay && !_hasCollector;
shouldShowBlueHeart()    => _hasPlay && !_hasCollector;
shouldShowRainbowHeart() => _hasCollector;
```

### No Server-Side Verification
Trusts platform verification (same as French Vanilla). No backend receipt validation.

## Purchase Menu UI

Shown as a `showModalBottomSheet` with `DraggableScrollableSheet` (initial: 0.9, min: 0.5, max: 0.95).

### Layout
```
┌──────────────────────────────────┐
│         ── (drag handle)         │
│  Support Doubling Season         │  ← headlineSmall, bold
│  Help keep the app ad-free       │  ← bodyMedium, 70% opacity
│                                  │
│  ┌────────────────────────────┐  │
│  │ Say Thanks              $X │  │  ← tier card
│  │ ♥ Red Heart               │  │
│  │ Support the developer...  │  │
│  │ ✓ PURCHASED  (if owned)   │  │
│  └────────────────────────────┘  │
│  [Play tier card — same layout]  │
│  [Collector tier card]           │
│                                  │
│        Restore Purchases         │  ← TextButton at bottom
└──────────────────────────────────┘
```

### Tier Card Descriptions (adapt for Doubling Season)
- **Say Thanks**: "Support the developer and unlock the exclusive red heart badge."
- **Say Thanks with a Play Booster**: "Buy the developer a pack of cards and unlock the exclusive blue heart badge."
- **Say Thanks with a Collector Booster**: "Buy the developer a collector pack and unlock the exclusive customizable WUBRG heart badge. Get full supporter bragging rights!"

### UI States
- **Loading**: `CircularProgressIndicator` centered
- **Error**: "Nothing to see here" message with Retry button
- **Purchasing**: Inline spinner + "Processing..." on the active tier card
- **Owned**: Green checkmark + "PURCHASED" badge (60% opacity) on owned tier cards
- **Success**: `AlertDialog` → "Thank you for your support! You're now a [Tier] supporter."
- **Purchase error**: `SnackBar` with error message

### Highlighted Tier
Pass `scrollToTier` to highlight a specific tier card (elevation 4 + primary-colored border). Used when upgrading from credits screen.

## Heart Badge System

### HeartStyle Model
26 predefined styles using MTG color gradients:
- 5 mono colors (W, U, B, R, G)
- 10 guild (two-color) combos
- 10 tri-color combos
- 1 rainbow (WUBRG)

Each style has: `id`, `name`, `colors` (list of Color values for gradient).

### HeartIcon Widget
Renders a heart icon (`Icons.favorite`) with a `ShaderMask` + `LinearGradient` from the style's colors. Accepts `size` parameter.

### Heart Display Logic (Credits Screen)
- No purchases → empty heart outline (`Icons.favorite_border`)
- Thank You only → red heart
- Play (or Play + Thank You) → blue heart
- Collector → customizable heart (default rainbow, saved to SharedPreferences)

### Heart Customization Screen (Collector only)
Full-screen scaffold with:
- Large 128px heart preview
- Style name label
- Swatch grid sections: Mono Colors, Guild Colors, Tri-Color Combos, Special/Rainbow
- Each swatch is a 64×64 tappable container
- Sticky bottom bar with Cancel / Save buttons
- Unsaved changes trigger confirmation dialog on cancel
- Access-gated: checks `IAPService().hasCollectorTier()` on init

## Entry Point

### Credits/About Screen Integration
- Heart icon row on the credits card (tappable)
- "Support Doubling Season" `OutlinedButton.icon` opens `PurchaseMenu`
- On web: button links to Ko-fi instead
- Tap behavior depends on current tier:
  - No tier → opens purchase menu
  - Thank You → dialog offering upgrade to Play ($5.49)
  - Play → dialog offering upgrade to Collector ($26.99)
  - Collector → navigates to heart customization screen

## Platform Configuration

### iOS
- Enable "In-App Purchase" capability in Xcode (Signing & Capabilities)
- Create 3 non-consumable products in App Store Connect
- Test with sandbox accounts (App Store Connect → Users and Access → Sandbox)

### Android
- `com.android.vending.BILLING` permission added automatically by `in_app_purchase` plugin
- Create 3 one-time products in Google Play Console (Monetize → In-app products)
- Test with Internal Testing track + License Testers

### Web
- IAP not supported — show Ko-fi link instead of purchase button
- Use `kIsWeb` check to swap UI

## Implementation Order

1. Add `in_app_purchase` dependency
2. Create `IAPService` singleton (copy from French Vanilla, update product IDs)
3. Create `HeartStyle` model and `HeartIcon` widget
4. Create `PurchaseMenu` bottom sheet
5. Create `HeartCustomizationScreen`
6. Integrate into `main.dart` (init/dispose)
7. Add support button + heart display to credits/about screen
8. Configure products in App Store Connect and Google Play Console
9. Test purchase flow with sandbox/test accounts
