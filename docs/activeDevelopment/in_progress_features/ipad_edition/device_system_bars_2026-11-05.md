# Device system bars while playing (2026-11-05)

The user clarified that “hide app bar and suppress notifications” refers to the
device status/navigation bars and system notification banners, not app controls.

## Implementation

The loaded table is wrapped in `GameSystemUi`. Native fullscreen is requested
only while that widget is mounted and the app is resumed. Startup/loading/error
screens keep normal chrome. Leaving the foreground or disposing the table
restores visible bars; resuming the table requests fullscreen again. Android
keyboard dismissal schedules one cancellable retry after 1.1 seconds, respecting
the platform's one-second restriction. Internal table controls are unchanged.

- iOS: Flutter `SystemUiMode.immersiveSticky` requests a hidden status bar and
  auto-hidden home indicator. iOS retains final control of the home indicator,
  system gestures, multitasking affordances and transient system UI.
- Android API 30+: a tablet-only method channel uses `WindowInsetsController`
  to hide status/navigation bars and allow transient reveal by edge swipe.
  This avoids Flutter's documented target-SDK-36 limitation on its legacy
  `SystemUiMode` path. The target SDK is unchanged, edge-to-edge is not opted out,
  and no dependency or permission is added. Older Android uses immersive-sticky
  view flags. Leaving immersive mode restores the previous bar behavior/flags.
  Desktop-window caption bars and system-controlled taskbars may remain visible.
- Browser/desktop: no system chrome request. A web page cannot promise to hide
  device bars or browser chrome. This change does not invoke browser fullscreen.

## Notifications and user control

Hiding system bars does **not** block notification banners, calls, alarms or
emergency alerts. This implementation neither requests notification-policy
access nor changes Focus/Do Not Disturb. iOS does not expose a public API for an
ordinary app to switch the user's system Focus on. Android notification-policy
access is a separate user-granted capability; changing it is not part of this
patch.

For quiet play, the user can enable Focus/Do Not Disturb in Control Center or
Android Quick Settings before playing. On iPad, Settings > Focus supports an
app-based schedule for Tripling Table. Allowed people/apps, time-sensitive
notifications and system exceptions remain controlled by the user's settings;
“all notifications suppressed” is not a guarantee.

## Validation

`test/game_system_ui_test.dart` checks native channel selection, foreground and
background transitions, disposal restoration, keyboard-dismiss retry/cancellation,
and the desktop no-op. All six focused tests pass. The combined tablet suite
passes 1,164 tests with 7 intentional skips; analyzer and release web build
pass. Mocked Flutter tests verify requested calls, not actual OS-rendered bars.
Browser smoke was blocked before app launch by the execution environment's
Chrome profile-socket restriction. Firebase distribution is delayed at the
user's request while they batch feedback from their last installed iPad build.

Native acceptance remains required on an iPad and Android tablet: cold launch,
resume from Home and app switcher, open/dismiss a native keyboard and photo
picker, rotate, swipe to temporarily reveal system bars, leave the app, and
verify saved game/input remains intact. Check Android API 30+ including API 36,
a legacy supported Android device where available, and iPad multitasking.
No claim of OS notification suppression or native hands-on acceptance is made.

## References

- Flutter mode limitations: https://api.flutter.dev/flutter/services/SystemChrome/setEnabledSystemUIMode.html
- iOS behavior: https://api.flutter.dev/flutter/services/SystemUiMode.html
- Android immersive UI: https://developer.android.com/develop/ui/views/layout/immersive
- Apple Focus setup: https://support.apple.com/guide/ipad/set-up-a-focus-ipad2789f181/ipados
