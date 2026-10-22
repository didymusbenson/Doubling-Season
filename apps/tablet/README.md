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

Repository policy requires manual functional validation; do not add an automated
test suite. Temporary external UI-driving flows may be used and discarded.
