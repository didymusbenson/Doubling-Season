# Token header spacing

## Report and scope

The annotated Zombie screenshot marks the title, +1/+1 counter controls, and
type line. The counter-free compact card and expanded card have uneven visual
gaps around those header sections. Work is isolated to the tablet token card;
no phone app changes, deployment, or device installation are included.

## Findings

The tablet counter strip has a fixed 32 px height, including a 40 px control.
It has no explicit separation from the title/status and type sections. The
status group is taller than the single-line name but the header aligns both
at their top edges. The root phone token card instead uses explicit section
spacing and a content-sized counter region.

## Plan and verification

Balance the name/status alignment, add compact section spacing, and allow
counter text to determine its row height at larger text scales. Preserve
horizontal scrolling, existing counter commands, expansion, and token data.
Compare rendered compact/expanded cards with and without counters, narrow
lanes, rotated views, and larger text. Run tablet analysis and regression tests.
Native device acceptance is separate from rendered widget checks.

## Implemented

- Align name/status by their first alphabetic baseline, rather than top edges.
  This retains first-row alignment when either the name or badges wrap.
- Add 4 px of separation above and below the counter strip. The previous
  cramped lower gap now matches the breathing room above the pills.
- Replace the strip's fixed 32 px height with a 32 px minimum. The manage action
  keeps its existing effective 32 px hit height, while larger counter text can
  grow the strip without clipping. Other action targets remain unchanged.
- Keep horizontal overflow scrolling, accessible names, callbacks, P/T updates,
  inline editing, and repeated expansion/collapse behavior unchanged.

## Validation (2026-11-07)

- Baseline rendered checks reproduced header misalignment and the fixed-height
  large-text problem before the production change.
- `flutter analyze`: no issues.
- 48 focused checks passed across `token_header_spacing_test.dart`,
  `tablet_token_card_regression_test.dart`, and
  `pt_backplate_render_regression_test.dart`.
- All 16 new spacing checks also passed with Roboto, Material, and Mana fonts.
  Rendered compact/expanded cards with 0/5 counters were inspected before and
  after. Additional cases cover 180/290/400 px lanes, 1.8x text, long names at all
  four rotations, scrolling multiple counters, counter-editor callbacks, and
  repeated expansion/collapse.
- Compared the original phone card's explicit section-spacing/content-height
  pattern. No root phone component changed. Tablet utilities have no equivalent
  token title/status/counter strip, so no utility change is needed for this fix;
  their separate screenshot feedback is being integrated independently.
- Full tablet suite and web build are delegated to the combined feedback
  integration branch. No deployment, device installation, or native acceptance
  is claimed. Keep this note in bug tracking until native acceptance.
