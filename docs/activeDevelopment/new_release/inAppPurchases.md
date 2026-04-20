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

---

## Implementation Status — Code Complete (2026-04-18)

### Files Added
- `lib/services/iap_service.dart` — singleton IAP service with product IDs `com.loosetie.doublingseason.{thank_you,play,collector}`, cached purchase bools in SharedPreferences, tier/feature/UI helpers.
- `lib/models/heart_style.dart` — 26 heart styles (5 mono + 10 guild + 10 tri-color + 1 rainbow) using official MTG frame colors embedded in the file (no new constants module).
- `lib/widgets/heart_icon.dart` — solid / gradient2 / gradient3 `ShaderMask` heart renderer.
- `lib/widgets/purchase_menu.dart` — `DraggableScrollableSheet` modal with three tier cards, Restore button, highlighted-tier support via `scrollToTier`, `kIsWeb` fallback message.
- `lib/screens/heart_customization_screen.dart` — Collector-only full-screen picker, Cancel/Save with unsaved-change confirmation, writes `collector_heart_style` to SharedPreferences.

### Files Modified
- `pubspec.yaml` — added `in_app_purchase: ^3.2.0` and `url_launcher: ^6.2.0` (Ko-fi fallback on web).
- `lib/main.dart` — `await IAPService().initialize()` before `runApp`; `IAPService().dispose()` in `_MyAppState.dispose()`.
- `lib/screens/about_screen.dart` — new "Support" card with tappable heart badge (outline when no tier, filled + gradient otherwise), tier-aware button label, tap behavior:
  - Web → opens `https://ko-fi.com/loosetie` via `url_launcher`.
  - No tier → `PurchaseMenu.show(context)`.
  - Thank You → upgrade dialog pointing to Play tier.
  - Play → upgrade dialog pointing to Collector tier.
  - Collector → navigates to `HeartCustomizationScreen`, reloads style on return.
  - Heart icon itself is only tappable when `hasCollectorTier()` to jump straight to customization.

### Deviations from Spec
- Support UI lives in its own "Support" card on the About screen (inserted between Features and Credits) rather than being merged into the Credits card — keeps the Credits legal/attribution text unmuddied.
- `IAPService.initialize()` still loads cached purchases even when `_iap.isAvailable()` returns false, so a previously-purchased user whose store is temporarily unreachable keeps their badge.
- Non-Collector tap on the heart icon itself is a no-op; the support button below is the single entry point for non-Collector tiers (avoids two controls that do the same thing).
- Ko-fi URL hard-coded to `https://ko-fi.com/loosetie` in `about_screen.dart`. Update if a different handle is preferred.

### Not Done (Out of Code Scope)
- App Store Connect product creation (3 non-consumables under `LooseTie.Doubling-Season`).
- Google Play Console product creation (3 one-time products under `com.loosetie.doublingseason`).
- Xcode "In-App Purchase" capability toggle on the Runner target.
- Sandbox / internal-testing purchase verification on a real device.

---

## Verifications for Didym to Review

### A. Dependency & Analyzer
- [ ] `pubspec.yaml` contains `in_app_purchase: ^3.2.0` and `url_launcher: ^6.2.0`. `flutter pub get` succeeds.
- [ ] `flutter analyze` reports no NEW issues touching `iap_service.dart`, `heart_style.dart`, `heart_icon.dart`, `purchase_menu.dart`, `heart_customization_screen.dart`, `about_screen.dart`, or `main.dart`. (Pre-existing warnings unrelated to IAP are expected.)

### B. Product IDs & Constants
- [ ] `IAPService.thankYouId == 'com.loosetie.doublingseason.thank_you'`
- [ ] `IAPService.playId == 'com.loosetie.doublingseason.play'`
- [ ] `IAPService.collectorId == 'com.loosetie.doublingseason.collector'`
- [ ] Matching products created in **App Store Connect** (under iOS bundle ID `LooseTie.Doubling-Season`) as **non-consumables** with the exact IDs above.
- [ ] Matching products created in **Google Play Console** (under `com.loosetie.doublingseason`) as **one-time products** with the exact IDs above.

### C. Platform Configuration
- [ ] Xcode: Runner target → Signing & Capabilities → "In-App Purchase" capability is enabled.
- [ ] Android: `com.android.vending.BILLING` permission is present in the merged manifest (automatically added by the plugin — verify in `build/app/outputs/logs/manifest-merger-*.txt` after a build).
- [ ] iOS build runs on a physical device with a sandbox Apple ID — purchase sheet shows real product titles + prices from App Store Connect.
- [ ] Android build runs on a device registered as a License Tester — purchase sheet shows real product titles + prices from Play Console.

### D. Runtime — About Screen
- [ ] Fresh install (no tiers owned): About → Support card shows **outline heart**, button reads **"Support Tripling Season"**, tapping the button opens the purchase menu.
- [ ] With Thank You only: heart badge is **red**, button reads **"Upgrade Tier"**, tap shows upgrade dialog offering Play.
- [ ] With Play (with or without Thank You): heart badge is **blue**, button reads **"Upgrade Tier"**, tap shows upgrade dialog offering Collector.
- [ ] With Collector: heart badge reflects saved style (defaults to rainbow), button reads **"Customize Heart Badge"**, tap opens `HeartCustomizationScreen`. Tapping the heart icon itself also opens the customization screen.
- [ ] Web build: button reads **"Support via Ko-fi"** and opens `https://ko-fi.com/loosetie` in a new tab.

### E. Runtime — Purchase Menu
- [ ] Drag handle visible; sheet opens at ~90% height, can drag down to ~50% and up to ~95%.
- [ ] Header reads **"Support Tripling Season"** / **"Help keep Tripling Season ad-free and buy a pack for the dev."**
- [ ] All three tier cards render with correct titles, localized prices, heart previews (red / blue / rainbow), and descriptions referencing Tripling Season.
- [ ] Tapping an unowned tier triggers the platform purchase sheet. On success: "Thank You!" dialog appears, tier card now shows **"PURCHASED"** with a check, modal dismisses when user taps Close.
- [ ] Tapping an already-owned tier shows a SnackBar ("You already own this tier!") with no charge.
- [ ] "Restore Purchases" button calls `restorePurchases()` and SnackBars success/failure. Ownership flags flip back to `true` if previously purchased on this Apple ID / Google account.
- [ ] If the store query fails, error state with "Nothing to see here" + Retry button appears; Retry reloads products.
- [ ] Purchase menu rendered on web shows "In-app purchases are not available on the web." (Note: the About screen routes to Ko-fi before this menu on web, but verify the menu itself is safe if reached.)

### F. Heart Customization Screen (Collector only)
- [ ] Opens only when user has Collector tier. A non-Collector user somehow reaching it sees the "Collector Tier Required" dialog and is popped back.
- [ ] Large 128px preview updates instantly when a swatch is tapped. Style name label updates.
- [ ] Four sections render: Mono Colors (5), Guild Colors (10), Tri-Color Combos (10 — shards then wedges), Special (1 rainbow).
- [ ] Each swatch is 64×64, highlighted with a primary-colored border when selected.
- [ ] **Cancel with no changes**: screen closes immediately.
- [ ] **Cancel with changes**: confirmation dialog appears; "Continue Editing" keeps the screen open; "Discard" closes and reverts (About screen still shows old style).
- [ ] **Save**: SnackBar confirms save, screen closes, About screen heart badge updates to the newly-chosen style without needing a restart.
- [ ] Kill app, reopen, About → heart still reflects the saved style (persistence via SharedPreferences key `collector_heart_style`).

### G. Tier Hierarchy Logic (spot-check `iap_service.dart`)
- [ ] `canAccessThankYouFeatures()` returns true for any tier.
- [ ] `canAccessPlayFeatures()` returns true for Play or Collector.
- [ ] `canAccessCollectorFeatures()` returns true only for Collector.
- [ ] `shouldShowRedHeart()` true only when Thank You owned and Play/Collector NOT owned.
- [ ] `shouldShowBlueHeart()` true only when Play owned and Collector NOT owned.
- [ ] `shouldShowRainbowHeart()` true iff Collector owned.

### H. Lifecycle & Edge Cases
- [ ] `IAPService().initialize()` is awaited in `main()` before `runApp` — splash still shows promptly (init should be fast when store is reachable).
- [ ] Airplane mode at launch: About still shows the correct heart based on cached SharedPreferences bools (no crash, no tier loss).
- [ ] Backgrounding the app during a purchase and returning does not duplicate delivery — confirm SnackBar/dialog only appear once and the tier card flips to "PURCHASED" exactly once.
- [ ] On app shutdown, no warnings about un-disposed streams (`IAPService().dispose()` is called from `_MyAppState.dispose()`).

### I. Store Listings / Copy
- [ ] App Store Connect product display names + descriptions match the tier card copy (or at least aren't contradictory).
- [ ] Google Play product display names + descriptions likewise.
- [ ] Prices in each store match the target price points (~$1.99 / ~$5.49 / ~$26.99). Localized currencies are acceptable.

### J. Sanity
- [ ] No Claude attribution in any commit made for this feature.
- [ ] No code comments mention the task, PR, or "added for X" rationale — code is clean of transient comments.
- [ ] `CLAUDE.md` still reflects accurate architecture notes; consider offering to update if IAPService should be mentioned alongside the other providers.
