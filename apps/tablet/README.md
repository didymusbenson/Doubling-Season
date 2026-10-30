# Tripling Table

The separate tablet app developed from the Tripling Season iPad specifications.
“Tripling Table” is a development name, not a selected store name.

**Current work (2026-10-30): centered two-player shared controls.**
The [two-player correction](../../docs/activeDevelopment/in_progress_features/ipad_edition/centered_two_player_controls_2026-10-30.md)
restores Dice, Menu and Day/Night to the central player seam while retaining the
horizontal reveal. The first token's content gains internal clearance beneath
the controls; its artwork remains flush with the lane edge, with no blank outer
margin. Three/four-player layout and behavior are unchanged.

The [follow-up](../../docs/activeDevelopment/in_progress_features/ipad_edition/attached_controls_and_two_player_reveal_2026-10-30.md)
attaches navigation to short drawer content, matches cutouts to the themed
surface, exposes inline player-counter chips, and includes commander names in
their full stepper hit areas. Two-player mode uses a horizontal reveal and full
token widths; lane controls overlay without a reserved top band.

The preceding [composition refinement](../../docs/activeDevelopment/in_progress_features/ipad_edition/drawer_composition_refinement_2026-10-30.md)
moves the whole Menu handle to the right wall, gives game workflows deliberate
content layouts, and centers the commander ledger when no counter summary is
present. Active summaries use only their actual width; the shared placement and
ink geometry remain aligned.

The [game drawer work](../../docs/activeDevelopment/in_progress_features/ipad_edition/game_drawer_ink_tooltips_2026-10-30.md)
embeds shared game workflows in a center channel beneath the sliding life and
utility rails. Player/token editors retain focused dialogs; commander damage and
player counters share a content-sized popup. Life feedback avoids painting over
the on-chip summaries while retaining full tap regions. Controls preserve explicit
accessibility labels without hover/hold tooltip bubbles. Canonical saves and
History remain durable. Native hands-on acceptance is recorded separately from
automated and browser checks.

Earlier [compact hub and inline-token correction](../../docs/activeDevelopment/in_progress_features/ipad_edition/compact_hub_life_tools_2026-10-22.md)
records the preceding design history rather than the current branch status.

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

### App icons

The tablet's original 2048px artwork is `assets/AppIconSource.png`, copied
unchanged from the supplied `app_icon.png`. It is separate from the root phone
app's source and branding. On macOS, regenerate and validate the platform icons:

```sh
python3 tool/generate_app_icons.py
python3 tool/generate_app_icons.py --check
```

The generator uses `sips` for all resizing: the existing iOS AppIcon catalog
(including 167px iPad Pro and 1024px marketing icons), five Android launcher
densities, and the web icons/favicon. A native ImageIO helper first removes the
alpha channel losslessly into a temporary RGB PNG, following the phone app's
`remove_alpha_ios` precedent. The source file is preserved; transparent source
pixels composite onto the existing cream brand background. Validation checks
every output's dimensions/alpha and the catalog/manifest references.

### Direct iPad testing

Use this app's `ios/Runner.xcworkspace`, bundle `LooseTie.Tripling-Table` and
team `84W8Q8DV3S`. Check the intended physical iPad's current device identifier,
pairing, Developer Mode and provisioning before building. A simulator build
does not establish device signing or Release readiness.

Once development provisioning covers the iPad, build from this directory with
`flutter build ios --release`. For a data-preserving installation, use
`xcrun devicectl device install app --device <ipad-id> build/ios/iphoneos/Runner.app`
and launch `LooseTie.Tripling-Table` with `devicectl device process launch`.
Check the installed version/build and actual launch before reporting success.
Do not uninstall an existing app: Flutter 3.41's `flutter install` attempts to
uninstall an existing copy by default. This flow is a development-signed Release
test and does not upload to TestFlight or change the phone app.

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

This is a browser inspection build; the focused inline-keyboard repair passed independent live-browser retesting in the preceding batch.
It does not establish native iPad/Android acceptance or store readiness.

## UI feedback review branch — 2026-10-22

The next UI batch preserves the corrected token object while tightening token
headers, corner overlays, player dividers, game-control placement, fixed utility
editors, status badges and directly adjustable commander trackers. See the
[batch checklist and validation limits](../../docs/activeDevelopment/in_progress_features/ipad_edition/ui_feedback_batch_2026-10-22.md).
The focused web q→a repair passed independent live retesting. The current correction branch is for review and preserves the root app.
