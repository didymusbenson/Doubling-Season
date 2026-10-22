# Tripling Table

The separate tablet app developed from the Tripling Season iPad specifications.
“Tripling Table” is a development name, not a selected store name.

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
