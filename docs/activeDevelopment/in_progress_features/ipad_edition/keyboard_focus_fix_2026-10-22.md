# Focused keyboard selection repair — 2026-10-22

Status: implemented with automated regression evidence; awaiting the independent reviewer’s live-browser retest. This follows the UI batch at `8849514` and changes no token/life/utility layout.

The reviewer reproduced Name → Select all → q → a leaving `a` on the release web build. Before changing production code, a platform-focus regression reproduced exactly `Expected: qa; Actual: a` under macOS focus behavior. The fixture models a keyboard button taking focus before its press callback, a transition omitted by the earlier touch-only regression.

The installed Flutter 3.41.2 source confirms `EditableText.selectAllOnFocus` defaults to true on web/desktop and false on mobile. `_replace` intentionally returns focus to the preview so caret/selection stay visible. That focus is applied after the shared controller’s new value, and Flutter then selects the newly inserted `q`; the next key replaces it.

The sole production change explicitly sets `selectAllOnFocus: false` on the keyboard preview `EditableText`. Its shared controller remains the selection authority. Explicit Select all, pointer range selection, cursor movement, hardware handling, clipboard operations, native IME suppression and orientation remain unchanged. This is shared Flutter behavior with no web-only conditional: mobile retains its previous default, while web/desktop no longer introduce a focus-only replacement.

Verification: `flutter analyze` clean; focused keyboard suite 13/13; aggregate tablet suite 111/111. Eight new platform/orientation cases exercise Android, iOS, macOS and Windows test variants, each at 0° and 180°. They preserve initial valid selection, explicit Select all, q+a, repeated a, cursor insertion, range replacement, backspace, later Select all, and committed text. Platform variants are widget tests, not native runtime acceptance.

A fresh release web build is served at the existing isolated review endpoint `http://127.0.0.1:8784/Doubling-Season/tablet/`. Reviewer retest should freshly reload this build and verify Name → Select all → q → a produces and commits `qa`, including a repeated-letter and top-facing case. Native computer use remains unavailable while the Mac is locked; no unlock bypass, install, signing change or personal data reset was attempted.

The previous 27-screenshot manifest and green CI at `36f6ffd` remain historical UI-batch evidence. This focused change requires a new CI run and live-browser acceptance; it does not retroactively turn the older web-input failure into a passing result. No main merge or deployment is authorized.
