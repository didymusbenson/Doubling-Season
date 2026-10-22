# Tripling Table

The separate tablet app developed from the Tripling Season iPad specifications.
“Tripling Table” is a development name, not a selected store name.

**Checkpoint status (2026-10-22): positioning and stepper correction in progress.**
The previous UI batch is deployed at main `9c3b926`. The new
[centered-controls/full-half stepper correction](../../docs/activeDevelopment/in_progress_features/ipad_edition/centered_controls_and_half_steppers_2026-10-22.md)
fixes the reported bottom-seat toolbar anchoring and direct life input. Independent browser review passed on `2b0b916`; publication is authorized after
checking the requested utility stripe-only follow-up. Native hands-on acceptance
remains outstanding.

## Run

From this directory, use Flutter 3.41 or later:

```sh
flutter pub get
flutter run -d chrome
flutter run -d <ipad-or-android-tablet>
```

Build the targets independently of the phone app:

```sh
flutter build web --release
flutter build ios --simulator
flutter build apk --release
```

Development identities are `LooseTie.Tripling-Table` (iPad) and
`com.loosetie.triplingtable` (Android). The phone application's identifiers,
Hive boxes, adapters and entry point are untouched. No store submission or
production signing is configured by the first implementation.

The app reuses the root package's catalog, token/rule definitions and supporting
Dart primitives through a path dependency. It never initializes the phone
providers or its Hive setup. Multiplayer state has a separate versioned store.

The authoritative specification is in
[the iPad dossier](../../docs/activeDevelopment/in_progress_features/ipad_edition/README.md).
Implementation details and measured validation are recorded beside it.

The user authorized tablet regression tests for the 2026-10-22 corrective
iteration. From this directory, run `flutter analyze` and `flutter test`.
Manual visual and functional validation remains required, including actual
small-tablet native checks. Browser-only evidence does not establish native
acceptance. Temporary external UI-driving flows may be used and discarded.
See the [corrective review tracker](../../docs/activeDevelopment/in_progress_features/ipad_edition/corrective_iteration.md)
for the source-backed token inventory, measured checks and remaining gaps.

## Release configuration

All gameplay is free and works without a store connection. Optional supporter
cosmetics use this product's own three non-consumable store products. Supply
`TABLE_SUPPORT_THANKS_ID`, `TABLE_SUPPORT_PLAY_ID`, and
`TABLE_SUPPORT_COLLECTOR_ID` through Flutter `--dart-define` build arguments after
creating the products in the store accounts. The app reads prices from the store;
it does not reuse phone-app purchase IDs or claim cross-app entitlements. Without
those definitions, the support page clearly reports purchases unavailable.

Android release builds currently use development signing for installation and
validation. Configure a private release keystore outside source control before
store submission. The iPad target uses the existing Apple development team with
its separate bundle identifier; provisioning and store metadata still require
the product owner's account setup.

The tablet CI workflow analyzes the app and builds web, Android and the iPad
simulator for relevant pull requests. It does not deploy or publish either app.

## Web preview on GitHub Pages

The existing Pages site serves both apps from one deployment artifact:

- Original app: https://didymusbenson.github.io/Doubling-Season/
- Tablet preview: https://didymusbenson.github.io/Doubling-Season/tablet/

On pushes to `main`, `.github/workflows/deploy.yml` builds the original app
with Flutter 3.38.x and `/Doubling-Season/`, then the tablet app with Flutter
3.41.2 and `/Doubling-Season/tablet/`. It copies the tablet output into the
original build's `tablet/` directory and uploads the combined site once. Never
deploy the tablet artifact alone: Pages replaces the entire site on deployment.
`/Doubling-Season/deployment.json` records the deployed source commit.

To reproduce the tablet Pages build from this directory:

```sh
flutter build web --release --base-href /Doubling-Season/tablet/ --pwa-strategy=none
```

The tablet preview does not register a service worker or create Flutter offline
caches; the original app's service worker and build settings are unchanged.
Paths on the same origin share browser storage, so isolation depends on distinct
names, not the URL alone. Tablet Hive boxes use `tripling_season_tablet_*` and
`tripling_table_media_v1`; its preferences use `tablet_support_*`. The tablet
entry point does not initialize the original app's Hive providers or settings.
No storage migration or reset is part of publishing this preview. Do not clear
site data to switch between apps, since that would delete both apps' saved state.

This is a browser inspection build; the focused inline-keyboard P1 repair awaits independent live-browser retest.
It does not establish native iPad/Android acceptance or store readiness.

## UI feedback review branch — 2026-10-22

The next UI batch preserves the corrected token object while tightening token
headers, corner overlays, player dividers, game-control placement, fixed utility
editors, status badges and directly adjustable commander trackers. See the
[batch checklist and validation limits](../../docs/activeDevelopment/in_progress_features/ipad_edition/ui_feedback_batch_2026-10-22.md).
The focused web q→a repair is documented separately and awaits live-browser retest. This branch is for
review; it is not merged or deployed and does not change the root app.
