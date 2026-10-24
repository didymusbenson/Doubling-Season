# Tablet utility redundancy cleanup — 2026-10-23

Exact built-in kinds excluded from the tablet add catalog and primary board/management UI: `life_total`, `poison_counters`, `energy_counters`, `experience_counters`, `radiation_counters`, `citys_blessing`, `monarch`, `day_night`. Custom kinds remain independently usable regardless of editable names. Unique game/card utilities remain. Existing add-catalog exclusions for initiative/commander tax are unchanged; existing commander-tax entries remain independently visible. Shared root WidgetDatabase is unchanged.

This is presentation filtering only. Retain every serialized legacy entry, ID, raw value/default, artwork/configuration and visible flag. Legacy handlers already bind authoritative player/session state; stale raw UtilityState values must not be migrated, summed or normalized. Historical `@id` diffs and whole-list snapshots depend on original payloads. One effective-visible predicate drives rendering/reordering, leaving filtered and manually hidden entries in their slots. Collapsed Legacy settings exposes metadata/art without duplicate gameplay or visibility controls. Phone imports with `isCustom: true` and no `actionType` retain custom identity before name fallback; explicit action kinds retain their established meaning.

Validation and review checklist:

- [x] Clean Flutter analysis; 333 aggregate tests; release web build.
- [x] Ten focused state/import/history regressions: exact excluded/retained kinds; custom names; save/reopen; stale raw values/IDs/flags/art/configuration unchanged; authoritative counter/status handlers; hidden-slot reorder; persisted `@id` field diffs and whole-list additions undo; archive restore and undo; preset replace/append; tablet v4 import/export; phone v1–3 import and v3 export.
- [x] Seven renderer/UI cases: populated mini-landscape/portrait utility lanes and menus, primary filtering with unchanged payload, custom trackers/toggles, top/bottom facing metadata/art recovery without duplicate gameplay controls, legacy-only chooser, disclosure absent when no legacy entries exist.
- [x] Before/after pixels inspected locally. Menu now shows independent utilities and a collapsed secondary Legacy settings row. Add catalog retains mana, Storm and unique card actions. No new explanatory paragraph/toast or utility stripe.
- [ ] Exact-head remote CI and parent visual acceptance before merge/deployment.
- [ ] Native/live-browser hands-on acceptance. Mac connection recovered, but screen-lock indicator remains Yes; no lock bypass or native UI action attempted. Flutter renderer captures and a release build are separate evidence.

The executor disconnected before the first compatibility-file/test command executed; inspection confirmed both absent on reconnect. Work was preserved and compatibility coverage completed. The initial WIP commit/push was rejected before execution by automatic approval review; fresh trusted user publication/push evidence was supplied for the permitted single retry. Parent review precedes publication through the existing combined Pages workflow.

Before/after images are in task-local `utility-dedup-before` / `utility-dedup-after`, saved to Library for review. No original-app source, model/storage schema, personal data or deployment configuration changes.
