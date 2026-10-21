# Billing update — 1.11

User confirmed on 2026-09-27 that the pricing/billing fix belongs in the same
1.11 release as the board-order, artwork, and Brudiclad fixes.

## Included changes

- `in_app_purchase`: 3.2.3 → 3.3.1 in the lockfile; constraint ^3.3.0.
- `in_app_purchase_android`: 0.4.0+10 → 0.5.0; local plugin build configuration
  declares Google Play Billing 8.0.0.
- Dart minimum: 3.10.0. Both plugins require Dart ^3.10.0 / Flutter >=3.38.0.
- GitHub Pages build uses Flutter 3.38.x instead of 3.35.x.
- Release remains 1.11.0+19. Store prices and product identifiers are unchanged.

## Validation

The September 27 analysis, iOS Simulator build and Android debug build included
these dependency changes in the working tree and passed.

The first combined Android release AAB attempt with `--no-pub` failed because
the generated Java plugin registrant referenced the development-only splash
plugin absent from the release classpath. `flutter clean`, `flutter pub get`, and a normal `flutter build appbundle
--release` resolved it without source changes to the generated registrant.

The combined release AAB passed on Flutter 3.41.2 / Dart 3.11.0 and is at
`build/app/outputs/bundle/release/app-release.aab` (48.0 MB). Its merged manifest
confirms `com.loosetie.doublingseason`, version 1.11.0 / build 19, minimum API 24,
target API 36, and BillingClient metadata 8.0.0. No store upload was performed.
The CI minimum 3.38.x matches the installed plugins' declared requirement;
this local build does not claim an executed GitHub Actions run.

Store-backed purchase/restore acceptance and store submission are separate
release gates, not established by compilation.
