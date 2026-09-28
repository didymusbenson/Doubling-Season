# Android update compatibility investigation

2026-09-25: User reports their Android device cannot update to the latest
Tripling Season and asks whether device support was dropped. Device model,
Android version, update source, and exact error are pending.

Findings:
- Local 1.11.0 build 19 merged release manifest requires API 24 (Android 7.0)
  and targets API 36. Target SDK is not the minimum supported OS.
- Local release AAB includes armeabi-v7a, arm64-v8a, and x86_64 Flutter libraries.
- Application ID remains com.loosetie.doublingseason.
- Both v1.10 configuration and current configuration inherit Flutter's minimum
  SDK rather than pinning it. Flutter 3.35 raised its default to API 24.
- No Android device is currently visible through adb.
- Have not verified the previous shipped artifact's minimum SDK or Google Play
  release/device catalog settings. No confirmed regression or selected fix.

Next: obtain device/error details and distinguish compatibility filtering from
installation failure or release availability. Compare Play's actual published
artifacts if necessary. Do not change minimum SDK without establishing cause.

Follow-up: device is not running Android 6 or older; installed app remains on
1.8. Minimum-OS explanation does not fit. Need to establish whether Play offers
an Update button and installation fails, or offers only Open. Possible causes
include release-track/rollout eligibility or a signing mismatch if the installed
copy was sideloaded. These are hypotheses, not confirmed findings.
