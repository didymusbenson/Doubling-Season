# Research and sources

**Research date:** 2026-10-20 (America/Phoenix). Sources are primary documentation, plus the repository baseline and the user's screenshot. Live documentation may move; recheck against the selected SDK and rules publication before implementation. No framework benchmark, hardware prototype or native-versus-Flutter comparison was run.

## Decision update — 2026-10-21

The user has since selected Flutter with custom player-facing input as the direction, a separate product, Android/iOS/web targets and customizable 2–4 players. This does not turn the source research below into prototype evidence. Any keyboard input must face its initiating player; the subsequent explicit “No simultaneous keyboards.” decision requires one keyboard at a time, with handoff details still open. See the [decision register](09_decision_register.md) and [deferred keyboard options](custom_keyboard_options.md). The research date above remains unchanged.

## Findings and confidence

**Recommendation: keep Flutter.** The official framework APIs cover the required categories. This is an inference from capability and existing code reuse, not measured proof of this particular four-player interface. The unresolved questions concern rotated panels/keyboard, geometry, multi-touch arbitration and persistence. None of the reviewed evidence establishes a reason to pivot frameworks.

**The existing frontend needs a new composition boundary.** This follows directly from the current mixed list, global providers/events and whole-board restoration. The [source audit](../../../../ai_docs/research/2026-10-20-ipad-edition-current-architecture.md) pins those facts to `8894640543833eaf37bd62b971a0955c26bafa49`, with source links rather than relying on older project summaries.

**Hardware and source validation are different.** Online API support does not establish usable touch targets, acceptable seated reading distance, correct system-keyboard behavior or session durability. Those require the [phase gates and manual acceptance work](08_delivery_validation_and_risks.md).

## Flutter sources consulted

| Source | What it establishes | Project implication / inference |
|---|---|---|
| [General approach to adaptive apps](https://docs.flutter.dev/ui/adaptive-responsive/general) | Window size and parent constraints are distinct; responsive choices use available space | Measure both table and lane constraints; a generic “tablet” check is insufficient |
| [RotatedBox](https://api.flutter.dev/flutter/widgets/RotatedBox-class.html) | Quarter-turn rotation participates in layout | Candidate seat orientation primitive; validate overlay, drag and semantics separately |
| [Taps, drags and gestures](https://docs.flutter.dev/ui/interactivity/gestures) | Pointer dispatch and gesture recognition are separate layers | Prototype button/drag/hold conflicts; do not retarget by a mutable global seat |
| [showModalBottomSheet](https://api.flutter.dev/flutter/material/showModalBottomSheet.html) | A modal sheet blocks interaction below its route; anchorPoint relates to display features | Root phone sheets do not automatically become independent quadrant panels |
| [Navigator](https://api.flutter.dev/flutter/widgets/Navigator-class.html) | Nested navigation and overlays support separate journeys | A bounded local navigator/panel host is plausible, but route/barrier bounds need verification |
| [Reorder drag boundaries](https://api.flutter.dev/flutter/material/ReorderableListView/dragBoundaryProvider.html) | Reordering exposes a drag-boundary provider | Evaluate lane-bound dragging on the chosen SDK; clipping a child alone is insufficient evidence |
| [Reorder proxy decoration](https://api.flutter.dev/flutter/widgets/ReorderableList/proxyDecorator.html) | Dragging can use a decorated proxy | Check proxy orientation/bounds and neighbor hit testing rather than assuming normal cell behavior |
| [setPreferredOrientations](https://api.flutter.dev/flutter/services/SystemChrome/setPreferredOrientations.html) | iPad orientation locking has multitasking limitations; Android large-screen restrictions also apply | Choose resize/fallback behavior and recheck current target OS before relying on landscape lock |
| [Accessibility](https://docs.flutter.dev/ui/accessibility) | Framework guidance covers semantics, contrast, target size and scaling | Player labels, large text, screen-reader traversal and accessible reorder are release design work |
| [Performance best practices](https://docs.flutter.dev/perf/best-practices) | Localized rebuilds, lazy lists and measured rendering costs matter | Avoid rebuilding every seat per tap; profile actual game workloads before optimization |
| [AppLifecycleListener](https://api.flutter.dev/flutter/widgets/AppLifecycleListener-class.html) | Framework lifecycle hooks are available | Hooks can request cleanup/flush; they are not evidence of durable writes after abrupt termination |

The current app dependency floor is Dart 3.10 / Flutter 3.38-era packages; online documentation can describe newer APIs. Check project SDK, lockfile and API availability during P0. Do not upgrade Flutter or packages solely because a live reference page uses a newer version. This planning turn changes none of them.

## Game rules sources consulted

[Wizards' rules landing page](https://magic.wizards.com/en/rules) linked to the [Comprehensive Rules effective 2026-09-25](https://media.wizards.com/2026/downloads/MagicCompRules%2020260925.txt) at research time. The relevant rule references used in the feature documents are:

| Topic | Rule references | Design document |
|---|---|---|
| Token creator, owner and initial control | 111.2 | [Isolation](04_player_isolation_and_rules.md) |
| Starting life, advisory loss thresholds | 903.7, 704.5a/c, 903.10a | [Life](03_life_and_game_controls.md) |
| Separate commanders / cast tax | 702.124d, 903.8 | [Life](03_life_and_game_controls.md) |
| Mana types, restrictions, emptying, snow | 106.1b, 106.4, 106.6, 107.4h | [Mana pool](07_utilities_tokens_and_decks.md) |

The edition's scope is a tracker and selected calculation tools. These references guide representations; they do not establish a complete rules engine. Specific card semantics should be rechecked against authoritative current text when implementing new automation. Existing rule mathematics is being inventoried for reuse, not independently certified by this document.

## Source limitations

- The screenshot provides spatial intent, not production measurements, rights to reuse another product's assets, or an approved interaction specification.
- The source audit is static. It reports code/configuration, not successful iPad execution.
- Apple's layout page returned a JavaScript-only document in this research environment; its body was not used as evidence. No App Store requirement or current Apple distribution policy is asserted here.
- Flutter documentation supplies capability guidance, not comparative proof that a different framework would perform better or worse.
- Store entitlement, legal/branding, platform minimums and accessibility conformance claims require separate work if the release choices make them relevant. They are not prerequisites for writing or reviewing this dossier.
- The physical test matrix, storage experiments and unresolved decision register are deliberately left open rather than populated with invented results.
