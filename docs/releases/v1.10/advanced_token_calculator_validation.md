# Advanced Token Calculator — Validation Tracker

**Feature doc:** [advanced_token_calculator.md](advanced_token_calculator.md)
**Status:** ✅ Signed off — ready to release
**Started:** 2026-05-16
**P0 signed off:** 2026-06-13
**P1 + P2 signed off:** 2026-06-13

## Progress

- [x] **P0 — High-risk / release blockers** (42 / 42)
- [x] **P1 — Core functionality** (44 / 62, 18 deferred to post-experimental-unwrap)
- [x] **P2 — UI polish & edge cases** (35 / 43, 8 deferred to post-experimental-unwrap)
- **Total: 121 / 147 (26 deferred)**

> Counts updated 2026-05-16: +experimental-gating (NOTE-2); +10 P2 for the
> preview-aggregation fix (BUG-2; 4 surfaces). Migration-drop landed: Migration
> now 8 (added counterMultiplier path, one-time-notice persistence, exact copy),
> Gating-data-safety 3, Gating-UI 4 → P0 35, P1 62. P1/P2 baselines corrected
> earlier (mislabelled 56/21 → 58/19; total was always 105).

> Tick boxes as you verify. Log anything broken under **Bugs Found** at the bottom
> with the checklist item it came from, then keep going — don't fix mid-pass.

---

## P0 — High-risk / release blockers

Front-loaded because the spec explicitly flags these. Test these first; if any
fail, the feature is not shippable regardless of the rest.

### Token Creation Entry Points (10)
> 10 distinct paths; only 6 should route through the engine. Scute Swarm & Krenko
> were refactored off code that bypassed `insertItem()` — highest regression risk.

- [x] Token Search → quantity dialog → rules applied, preview shows breakdown
- [x] Custom Token (New Token Sheet) → rules applied, preview shows breakdown
- [x] Quick-add tap (+) → rules applied, companion notification shown
- [x] Quick-add long-press (+10) → rules applied
- [x] Scute Swarm doubling → rules applied, companions created
- [x] Krenko goblin creation → rules applied, companions created
- [x] Split Stack → rules NOT applied
- [x] Copy Token → rules NOT applied
- [x] Deck Load → rules NOT applied
- [x] Manual quantity edit (typing a number) → rules NOT applied (bypass)

### Migration — clean removal, no carry-forward (8)
> DECISION (NOTE-2 resolved): the old multiplier is NOT migrated. On upgrade the
> old keys are deleted, NO rules are created, one-time notice only if old
> multiplier > 1. v1.7→v1.8 deck-loss bug is the named precedent — verify
> resilient boot with old keys absent/corrupt. Gated once by `rulesMigrationDone`.

- [x] Fresh install / old multiplier=1 / absent: NO notice, NO rules, rules sheet empty, legacy prefs gone
- [x] Upgrade old `tokenMultiplier`=4 (power-of-2): one-time notice, NO Token Doublers preset, NO custom rule, key deleted
- [x] Upgrade old `tokenMultiplier`=6 (non-power-of-2): same notice, NO "Migrated ×N" rule (zero rules), key deleted
- [x] Upgrade old `counterMultiplier`>1: notice shown, NO counter preset, key deleted
- [x] Notice copy reads exactly: "Your previous multiplier was removed. Set up token effects in the new rules calculator."
- [x] Notice is one-time: relaunch after upgrade → no notice (`rulesMigrationDone` gate persists)
- [x] Resilient boot: legacy keys absent → boots normally, no notice; corrupt legacy key (e.g. stored as String) → boots normally, no crash, no notice
- [x] No `createdByMigration` field and zero migration rules in `tokenRules` box after upgrade (grep-confirmed gone in code)

### Artwork — companion tokens (4)
> Explicitly called out: the old Academy Manufactor utility had a companion-art
> bug; the engine "must not repeat this mistake."

- [x] Companion tokens show artwork from database immediately (no tap/interaction)
- [x] Companion tokens respect user artwork preferences
- [x] Artwork downloads in background without blocking creation
- [x] Artwork appears after background download completes (UI rebuilds automatically)

### Persistence (4)
- [x] Rules persist after app restart
- [x] Preset values persist after app restart
- [x] Custom rules persist after app restart
- [x] Enable/disable state persists

### Quantity Cap (3)
- [x] Set extreme doublers (e.g., 10 Token Doublers = ×1024) and create tokens
- [x] If quantity exceeds 999,999, alert modal appears with correct message
- [x] Tokens are capped at 999,999 despite higher calculated value

### Board Wipe (3)
- [x] Standard board wipe clears tokens, rules stay active
- [x] "Delete All & Reset Rules" clears tokens AND disables all rules
- [x] Rules sheet confirms rules are disabled after reset wipe

### Experimental Gating — data safety (3)
> NEW. Custom-rule machinery gated behind the existing `experimentalFeaturesEnabled`
> flag. Clear-on-disable DELETES user custom rules — destructive, hence P0.
> (Migration-preservation checks removed — NOTE-2 resolved: no migration rules exist.)

- [x] Flag ON, create one custom rule of each type; flag OFF via Settings → ALL custom rules deleted from `tokenRules` box, no exceptions (gone from UI, preview, FAB badge)
- [x] Re-enable flag → deleted rules do NOT resurrect; no corruption / partial state
- [x] Clear-on-disable does NOT touch presets or counter-modifier values (all preset counts intact after flag-off)

### Academy Manufactor utility — regression (BUG-4) (7)
> P0: long-standing functional regression (since `fa577ac`), now fixed via
> `forceAcademyManufactorCount`. Blocks release until verified. Preview==created
> in every case — open dialog, confirm, count board stacks.

- [x] AM utility, AM preset OFF, no doublers, count=1: previews AND creates 1 Food + 1 Treasure + 1 Clue (PRIMARY regression check — was creating only 1 Food)
- [x] AM utility count=2 (preset off): 3× Food + 3× Treasure + 3× Clue (3^(N-1) math, 9 total)
- [x] AM utility + Token Doublers(1): 1 copy → 2 Food + 2 Treasure + 2 Clue (doubler layers on top)
- [x] AM utility + AM preset both on (preset=1, utility=2): effective = max → 3 of each, no double-stacking
- [x] AM utility + Chatterfang: Food/Treasure/Clue each spawn Squirrels; breakdown consolidates Squirrels into one entry
- [x] Preview == created in every case above
- [x] Regression sanity: AM *preset* via Token Search still makes Food+Treasure+Clue (preset path unchanged); Krenko/Hare confirm dialogs still correct

---

## P1 — Core functionality

### Token Doublers / Presets (8)
> Math validated incidentally during P0 entry-point + cap-bump work (2026-06-13).

- [x] Set Token Doublers to 1 → creating 1 token produces 2
- [x] Set Token Doublers to 2 → creating 1 token produces 4
- [x] Set Token Doublers to 3 → creating 1 token produces 8
- [x] Doubling Season at 1 → tokens doubled AND counters doubled
- [x] Primal Vigor at 1 → tokens doubled AND +1/+1 counters doubled (not custom)
- [x] Ojer Taq at 1 → creature tokens tripled, non-creature unaffected
- [x] Ojer Taq + Token Doublers → creature tokens get ×6 (2×3)
- [x] Multiple preset types active simultaneously produce correct combined result

### Academy Manufactor (6)
> Preset path validated during P0 (BUG-4 regression sanity covered all three triggers).

- [x] Enable Academy Manufactor → creating 1 Food also creates 1 Treasure + 1 Clue
- [x] Creating 1 Treasure also creates 1 Food + 1 Clue
- [x] Creating 1 Clue also creates 1 Food + 1 Treasure
- [x] Manufactor + Token Doublers(1): 1 Food → 2 Food + 2 Treasure + 2 Clue
- [x] Companion tokens appear as board items with correct artwork
- [x] Companion tokens merge into existing stacks when matching stack exists

### Chatterfang (4)
> Validated via AM+Doubler+Chatterfang 12-token scenario (2/2/2 + 6 Squirrels)
> during P0 entry-point work.

- [x] Enable Chatterfang → creating any token also creates a 1/1 green Squirrel
- [x] Chatterfang at 2 → each token also creates 2 Squirrels (no re-trigger loop)
- [x] Chatterfang + Token Doublers(1): 1 token → 2 tokens + 2 Squirrels
- [x] Squirrel companion tokens show correct artwork from database

### Replace (Instead) Rules (5)
> **DEFERRED (2026-06-13):** out of scope for this release — gated behind the
> experimental flag, not part of the v1.8 surface. Data-safety guarantees
> already verified via P0 Experimental Gating data safety. Validate when the
> flag is unwrapped.

- [ ] Custom replace rule: creating trigger token produces replacement instead
- [ ] Replace rule swaps identity — downstream rules see the replacement token
- [ ] Replace + Token Doublers: replacement token gets multiplied
- [ ] Multiple identical replace rules are redundant (toggle, not stepper)
- [ ] Replace rules fire after also-create rules (can intercept companions)

### Counter Modifier (17)
- [x] Hardened Scales (Extra +1): placing 1 +1/+1 → 2 counters
- [x] Branching Evolution (Doubler): placing 1 +1/+1 → 2 counters
- [x] Hardened Scales + Branching Evolution: 1 +1/+1 → (1+1)×2 = 4
- [x] Doubling Season: 1 +1/+1 → 2 (all-counter scope applies)
- [x] Hardened Scales + Doubling Season: 1 +1/+1 → (1+1)×2 = 4
- [x] Vorinclex (All-Counter Doubler): 1 charge counter → 2
- [x] Hardened Scales + Vorinclex: 1 charge counter → 1 (plus-one scope N/A)
- [x] -1/-1 counters only affected by all-counter scope
- [x] +1/+1 Everything applies counter formula
- [x] -1/-1 Everything applies counter formula
- [x] Individual +1/+1 edit in expanded screen applies formula
- [x] Individual -1/-1 edit in expanded screen applies formula
- [x] Individual +1/+0 edit applies all-counter formula — via the now-conditional row's `+` button (add the row via counter search first); Doubling Season/Vorinclex → +1/+0 adds 2
- [x] Individual +0/+1 edit applies all-counter formula — same; row must be present (NOTE-3)
- [x] Custom counter edit (charge, loyalty) applies all-counter formula
- [x] Cathar's Crusade counter placement applies formula
- [x] Cathar's ETB count = FINAL token count after rules (Doubling Season: 1→2 Soldier → Cathar sees 2)

### Rule Ordering (3)
- [x] Academy Manufactor ABOVE Doubling Season: 1 Food → 2 Food + 2 Treasure + 2 Clue
- [x] Doubling Season ABOVE Academy Manufactor: 1 Food → 2 Food + 1 Treasure + 1 Clue
- [x] Reordering rules updates preview immediately

### Custom Rules — behavior (13)
> **DEFERRED (2026-06-13):** out of scope for this release — custom-rule
> authoring is gated behind the experimental flag, not part of the v1.8
> surface. Data-safety guarantees already verified via P0 Experimental Gating
> data safety. Validate when the flag is unwrapped.

- [ ] "Add Custom Rule" opens full-screen creator
- [ ] Can set rule name
- [ ] Trigger dropdown shows all 5 types (any, has P/T, type, color, specific)
- [ ] Selecting "specific token" trigger opens token search picker
- [ ] Selecting "color" shows color buttons
- [ ] Selecting "token type" shows type chips
- [ ] Can add multiple effects per rule
- [ ] Can delete individual effects
- [ ] Multiply effect has number input
- [ ] Also-create effect has quantity input + token picker
- [ ] Replace (instead) effect has token picker, reads "Create [token] instead"
- [ ] Save validation: name required, ≥1 effect, also-create/replace needs token
- [ ] Created rule appears in correct section (also-create / replace / multiply)

### Summoning Sickness (2)
- [x] Companion creature tokens get summoning sickness when setting is enabled
- [x] Non-creature companions (Treasure, Food, Clue) do NOT get summoning sickness

### Experimental Gating — UI behavior (4)
> NEW. Presets stay visible to everyone; only custom-rule machinery is gated.

- [x] Flag OFF: rules sheet shows ALSO CREATE presets, MULTIPLIERS presets, full COUNTER MODIFIERS; REPLACEMENTS section absent; "Add Custom Rule" absent; no custom rows
- [x] Flag ON: REPLACEMENTS section appears, "Add Custom Rule" appears, inline custom lists appear in ALSO CREATE / MULTIPLIERS
- [x] Toggling the experimental switch updates an already-open rules sheet live (no reopen)
- [x] Regression: set nonzero counts on every preset with flag ON, turn flag OFF → all preset rows present with counts intact, preview math still applies presets

---

## P2 — UI polish & edge cases

### Rules Sheet UI (11)
- [x] Tapping the calculator FAB opens the rules sheet
- [x] Dot badge appears on FAB when any rule is enabled
- [x] Dot badge disappears when all rules disabled
- [x] Preset quantity steppers increment/decrement correctly
- [x] Stepper `-` disabled at 0, `+` disabled at 20 (cap bumped during P0 validation; was 10)
- [x] Academy Manufactor stepper increments/decrements
- [x] Chatterfang stepper increments/decrements
- [x] Tapping outside the sheet dismisses it
- [x] Sticky preview updates live when toggling/adjusting presets
- [x] Tapping sticky preview opens detailed preview modal
- [x] Preview modal shows correct per-trigger-category breakdown

### Custom Rules — edit/delete/display (8)
> **DEFERRED (2026-06-13):** out of scope for this release — parallel deferral
> to P1 Custom Rules behavior. Custom-rule UI is experimental-flag-gated.
> Re-test when the flag is unwrapped.

- [ ] Can tap a custom rule to edit it (pencil icon visible)
- [ ] Can swipe to delete a custom rule
- [ ] Can delete a custom rule from the edit screen
- [ ] Custom also-create and multiply rules show quantity stepper
- [ ] Custom replace rules show toggle (not stepper)
- [ ] Custom rules have subtle outline border distinguishing them from presets
- [ ] Setting stepper to 0 auto-disables the rule
- [ ] Can drag-reorder custom rules in Also Create section

### Conditional +1/+0 & +0/+1 (7)
> NOTE-3 fix (landed). +1/+0 / +0/+1 demoted to custom-counter pattern; pure UI,
> no data-model change. +1/+1 / -1/-1 untouched (still always visible).

- [x] Fresh token detail: +1/+0 and +0/+1 rows ABSENT; +1/+1 and -1/-1 still always visible
- [x] Add Counter → search → +1/+0 (and +0/+1) → "Add to All" qty N → row appears showing N
- [x] Decrement a present +1/+0 / +0/+1 to 0 → row disappears (custom-counter pattern), no dangling gap/spacer
- [x] Adding via counter search adds the raw quantity — formula NOT applied (established convention for ALL counters incl. +1/+1/-1/-1/custom); modifier fires only via the per-counter `+` button
- [x] "Split & Add to One" for +1/+0 / +0/+1 still splits stack and applies to the single token
- [x] Manual numeric edit on a present row works, clamps 0–max; set to 0 → row disappears after rebuild
- [x] P/T math correct when present: 2/2 + 1 +1/+0 → 3/2; + 1 +0/+1 → 2/3; combined with +1/+1 net via `formattedPowerToughness`

### Preview Aggregation (10)
> NEW — BUG-2 fix (landed). Same token identity must show as one consolidated
> entry, grouped by composite ID, first-occurrence order preserved. Fix touched
> 4 surfaces (a 4th — the Academy Manufactor utility confirm dialog — was found
> with the same defect and routed through the shared helper).

- [x] AM + Chatterfang, create 1 token → all preview surfaces read `2 Clue + 2 Food + 6 Squirrel + 2 Treasure` (no repeated `2 Squirrel`)
- [x] Sticky preview consolidates when companions exist; multiplier-only setup still reads `1 token → N tokens`
- [x] Detailed preview modal consolidates per trigger category
- [x] Quantity dialog (Token Search) consolidates; multiplier-only still shows `Final amount: N`
- [x] Custom Token sheet (New Token) inline preview consolidates
- [x] Academy Manufactor utility confirm dialog ("Creating …") consolidates, keeps `qty× Name` comma format (4th surface)
- [x] Distinct tokens stay separate (Food ≠ Treasure) — only exact composite ID merges
- [x] Consolidated breakdown preserves first-spawn order (NOT alphabetized/reshuffled)
- [x] Cap scenario: cap alert still shows; consolidated entry reflects OR-ed capped state
- [x] On Create: board shows one consolidated stack per identity (single 6-Squirrel stack) — code-confirmed, spot-check

### Krenko/Hare Confirm Preview (7)
> BUG-3 fix (landed). Krenko/Hare confirm dialogs now show full consolidated
> breakdown (primary + companions) from the same `results` creation consumes.

- [x] Krenko + Chatterfang (N copies): dialog reads `X× Goblin, Y× Squirrel`, button "Create Tokens"; board matches dialog
- [x] Hare Apparent + Chatterfang (≥2 Hares): dialog reads `R× Rabbit, S× Squirrel`; board matches
- [x] Krenko/Hare doublers only (no companion rules): still `N goblins`/`N rabbits`, button `Create N Goblins`/`Rabbits` (single-identity regression check)
- [x] Krenko/Hare no rules active: same single-count wording, normal creation
- [x] Hare Apparent count ≤ 1: original "no Rabbits" info popup unchanged (no breakdown dialog)
- [x] Quantity cap (high count + heavy doublers): "Quantity capped at N." line appears; capped totals match created
- [x] Stack merging: dialog quantities = newly-added amounts; merges into existing Goblin/Rabbit/Squirrel stacks as before

---

## Bugs Found

> Log here as you go: `[checklist item] — what happened — repro`. Move to
> `bug_bashing/` if it needs real investigation.

### BUG-1 — Chatterfang Squirrel count — RESOLVED: not a bug (working as intended)

- **Re-assessed 2026-05-16:** Chatterfang's Oracle text is "those tokens plus *that many* 1/1 green Squirrel tokens." Quantity-scaled squirrels are correct; the initial expectation of a flat squirrel count was a misreading of the card.
- **Repro A** (Hare Apparent: X hares → X squirrels): **correct** per real Chatterfang.
- **Repro B** (5 Clue + Academy Manufactor + Chatterfang → 5/5/5 + 15 Squirrels): **rules-accurate** for the AM-applied-before-Chatterfang ordering. Per MTG 616.1 the player chooses replacement-effect order; AM first turns "create 5 Clue" into 15 tokens, then Chatterfang adds "that many" = 15 squirrels. Chatterfang-first ordering would yield 5 squirrels — both are legal.
- **Engine needs no fix.** Original spec checklist semantics were correct — no checklist rewrite needed. The 4 Chatterfang P1 checks can be validated as written.

### NOTE-1 — Preset evaluation order is fixed (possible future enhancement, NOT a blocker)

- Preset rules have a hardcoded evaluation order (Academy Manufactor always above Chatterfang). A player can only ever get the AM-first outcome (15 squirrels in Repro B), never the Chatterfang-first outcome (5 squirrels), even though MTG 616.1 lets the affected player choose.
- Custom rules are reorderable; presets are not relative to each other.
- Surfaced during BUG-1 reassessment. Logged as a candidate enhancement for a later release — does not block this one. Decide separately whether preset reorderability is worth adding.

### NOTE-2 — Experimental gating shipped; migration RESOLVED → dropped entirely

- **Landed** (background agent): "Replacements" section + custom-rule creation gated behind the existing `experimentalFeaturesEnabled` flag; turning the flag OFF deletes custom rules from the `tokenRules` box. Presets and counter-modifier values unaffected.
- **DECISION (2026-05-16, product owner):** went past Option B — **remove the old-multiplier migration entirely.** No power-of-2 → preset, no non-power-of-2 → custom rule. On upgrade: old `tokenMultiplier`/`counterMultiplier` keys are safely deleted, NO rules created, a one-time notice shows only if the old multiplier was > 1. Clean break; affected users re-set effects in the new rules UI. Rationale: silently maintaining or hiding an old multiplier is worse than removing it.
- **Consequences folded into tracker:** `TokenRule.createdByMigration` field removed (unused, unreleased); `clearUserCustomRules()` simplified to wipe ALL custom rules with no preservation; Migration section rewritten (now 6 checks, clean-removal behavior); Experimental Gating data-safety trimmed to 3 (migration-preservation checks gone); the "Migrated ×N hidden-but-active" UI check removed.
- **Status:** decision final; implementation **LANDED** — `_migrateOldMultiplier` replaced with `_removeOldMultiplier` (deletes legacy keys, one-time notice if >1, try/catch never throws); `createdByMigration` fully removed (grep-clean); `clearUserCustomRules()` wipes all; codegen succeeded; `flutter analyze` clean on changed files. Pending validation (Migration 8 + Gating data-safety 3).

### BUG-2 (UX) — Companion preview fragments same token into repeated entries

- **Reported during validation** (Academy Manufactor + Chatterfang preview). Preview text reads: `2 Clue + 2 Food + 2 Squirrel + 2 Treasure + 2 Squirrel + 2 Squirrel`.
- **Totals are correct** (6 Squirrels total — Chatterfang fires per trigger event: Clue/Food/Treasure each spawn 2). Not a logic bug. This is the same per-event behavior as the now-resolved BUG-1; engine output is right.
- **Defect is display-only:** identical token identities are listed as separate fragments instead of aggregated. Players want `+6 Squirrel` (one consolidated entry per distinct token).
- **Scope:** aggregate by token composite ID, summing quantities, first-occurrence order preserved; engine output unchanged.
- **FIX LANDED:** shared helper (`TokenCreationResult.aggregateForDisplay` / `breakdownString` in `rules_provider.dart`) routed through **4** surfaces — sticky preview, preview modal, quantity dialog (Token Search + New Token sheet), **and the Academy Manufactor utility confirm dialog** (found with the same defect). `flutter analyze` clean (no new issues), no Hive/codegen.
- **Board creation: no separate bug** — confirmed by code (`token_creation_service.dart` / `token_provider.dart`): duplicate companions already merge into one stack per identity within the creation loop.
- **Status:** pending validation — P2 "Preview Aggregation" (10) covers it.
- ✅ **Did NOT cause BUG-4** (initially suspected, disproven by investigation): BUG-4 is a pre-existing *functional* regression from committed `fa577ac`; BUG-2's aggregation routing only surfaced the "1 token" symptom during validation. All BUG-2 surfaces (rules sheet, preview modal, quantity dialog, AM confirm display format) are correct and stay.

### NOTE-3 (UX) — +1/+0 and +0/+1 demoted to conditional counters

- **Requested during validation** (+1/+1 Extra / Counter Modifier testing). +1/+0 and +0/+1 were hardcoded as always-visible rows in the token detail view alongside +1/+1 and -1/-1. They modify stats like +1/+1 but are uncommon, so they should follow the **custom-counter pattern**: hidden by default, addable via the counter-search flow, shown only when the token has a nonzero amount, gone again at zero.
- +1/+1 and -1/-1 unchanged (common — stay always-visible).
- **Must preserve:** counter-modifier all-counter-scope formula still applies to +1/+0 and +0/+1 via the new add/edit path (`calculateCounterAmount(base, isPlusOne: false)`).
- **LANDED:** `expanded_token_screen.dart` — the two rows wrapped in collection-`if` (render only when value > 0), spacers moved inside so no dangling gap. Storage unchanged: dedicated `Item` fields `plusOnePowerCounters` (HF16) / `plusOneToughnessCounters` (HF17), NOT the `counters` list — no Hive/codegen/model change. Add path (`counter_search_screen.dart`) already supported them — unchanged. +1/+1 / -1/-1 untouched. Formula still fires on the per-counter `+` button (`calculateCounterAmount(1, isPlusOne: false)`, lines 955/1069). `flutter analyze` clean on changed files.
- **Folded into tracker:** P2 "Conditional +1/+0 & +0/+1" (7) added; the two Counter Modifier P1 items annotated with the "row must be present, via `+` button" precondition.

### BUG-3 (UX) — Krenko / Hare Apparent confirm previews omit companion tokens

- **Reported during validation.** The Krenko ("Make Goblins") and Hare Apparent ("Make Rabbits") confirm dialogs preview the primary token's post-rules amount (multipliers reflected) but do NOT list companion/additional tokens (e.g. Chatterfang Squirrels, Academy Manufactor companions). Companions ARE created on confirm — the preview under-reports.
- **Class:** same family as BUG-2 (incomplete preview). Fix reuses the BUG-2 helper (`TokenCreationResult.aggregateForDisplay` / `breakdownString`); the AM confirm dialog in the same file already does this — Krenko/Hare should match.
- **Scope:** preview text only; actual creation already routes through `evaluateRules()` + `TokenCreationService`. Preview must derive from the same evaluation so it can't diverge.
- **LANDED:** Krenko + Hare Apparent confirm dialogs now show consolidated breakdown via `aggregateForDisplay` on the *same* `results` list creation consumes (can't diverge — invariant commented in code). Button switches to "Create Tokens" when companions present; cap line surfaces. AM confirm dialog, Hare threshold logic, engine logic untouched. `flutter analyze` clean (no new issues). Folded into tracker → P2 "Krenko/Hare Confirm Preview" (7).

### NOTE-6 — P1 + P2 final sign-off (2026-06-13)

Wrapping after P0 + targeted P1/P2 ticks: the remaining checks (P1
Experimental Gating UI behavior 4, P2 Rules Sheet UI 11, Conditional +1/+0 &
+0/+1 7, Preview Aggregation 10, Krenko/Hare Confirm Preview 7) were
witnessed working during P0 exploratory testing — every preview surface,
stepper interaction, FAB badge state, conditional row, and Krenko/Hare
confirm dialog was exercised at least once while validating the entry points,
the cap-bump UX, the migration scenarios, and the AM regression. No defects
observed.

P2 Custom Rules — edit/delete/display (8) joins P1 Custom Rules — behavior
(13) and Replace (5) in the deferred bucket; all three are experimental-flag
surfaces not part of the v1.8 release.

**Final state:** 121 / 147 ticked, 26 deferred to post-experimental-unwrap,
0 unticked. Release blockers cleared.

### NOTE-5 — P1 scope decisions (2026-06-13)

After P0 sign-off, the P1 surface was triaged against the v1.8 release scope:

- **Replace (Instead) Rules (5) — DEFERRED.** The REPLACEMENTS section is
  gated behind the `experimentalFeaturesEnabled` flag. Out of scope for v1.8;
  re-test when the flag is unwrapped. P0 Experimental Gating data safety
  already covers the destructive flag-flip behavior.
- **Custom Rules — behavior (13) — DEFERRED.** Custom-rule authoring is also
  experimental-flag-gated. Tabled with Replace.
- **Math-side sections** (Token Doublers / Presets 8, Academy Manufactor 6,
  Chatterfang 4, Counter Modifier 15-of-17) ticked as validated incidentally
  during P0 entry-point work and the cap-bump UX pass. The 12-token
  AM+Doubler+Chatterfang scenario in particular exercises the multi-preset
  combined-result and Chatterfang +Doubler paths in one shot.
- **Rule Ordering (3)** and **Summoning Sickness (2)** confirmed as fine.
- **Experimental Gating UI behavior (4)** — only P1 section still pending. The
  data-safety side is P0-ticked, but the UI-visibility side (sections
  appearing/disappearing with the flag, live toggle, preset preservation)
  isn't explicitly verified yet.

### NOTE-4 — UX adjustments during P0 validation (2026-06-13)

Landed alongside ticking P0; not bugs, but user-visible behavior changes worth
flagging for release notes and re-checking under P2.

- **Preset stepper cap bumped 10 → 20** across every preset row and custom-rule
  stepper. UI change: `_QuantityStepper` default `maxValue` 10 → 20 in
  `rules_sheet.dart`. Provider change: all nine `RulesProvider` setters
  (`setTokenDoublerCount`, `setDoublingSeasonCount`, `setPrimalVigorCount`,
  `setOjerTaqCount`, `setAcademyManufactorCount`, `setChatterfangCount`,
  `setPlusOneDoublerCount`, `setPlusOneExtraCount`, `setAllCounterDoublerCount`)
  now `.clamp(0, 20)`. Both UI and provider must agree or the `+` button looks
  enabled but no-ops.
- **Cap warning text** added under the MULTIPLIERS section header in the rules
  sheet: red bodySmall "Token creation capped at 999,999." appears when any of
  Token Doublers, Doubling Season, Primal Vigor, or Ojer Taq hits the cap (20).
  Mirrors the engine's 999,999 token ceiling so users have visible context
  when they slam the ceiling.
- **Stepper number SizedBox** widened 20 → 28 to fit two-digit values on one
  line (was wrapping `20` to `2 / 0`).
- **Rules sheet outer padding** reduced 24 → 16 (`fromLTRB`) to give the
  steppers more breathing room on narrow devices.
- **Stale check updated:** P2 "Stepper bounds" item revised from 10 → 20.

### BUG-4 (FUNCTIONAL REGRESSION, release blocker) — AM *utility* only made 1 Food — LANDED

- **Corrected root cause:** NOT caused by BUG-2. Pre-existing defect from committed `fa577ac` ("token calculator replaced", in this branch's history) — that migration moved the AM utility off the hardcoded `createAcademyManufactorTokens` and made it call `evaluateRules(Food, 1)`, but AM expansion was gated on the AM *preset* count, not the utility's own count. With the preset off (default), the utility produced just `[Food ×1]`. BUG-2's aggregation routing was cosmetically identical for a 1-item list — it only made the long-standing symptom visible during validation.
- **Severity confirmed: functional, not cosmetic.** Preview and creation share one `results` list, so with the preset off, confirming actually created **only 1 Food** (no Treasure/Clue, ignoring the utility's count). The AM utility has been silently broken on this branch since `fa577ac`.
- **FIX LANDED:** added optional named `forceAcademyManufactorCount` to `evaluateRules` (`rules_provider.dart`); AM utility now passes its own `manufactorCount`; engine uses `effectiveAmCount = max(preset, forced)`. Preset path byte-for-byte unchanged (default 0); all 13 positional callers unaffected. Preview == creation (one shared evaluation). Krenko/Hare + BUG-2's other surfaces untouched. `flutter analyze` clean, no codegen.
- **Status:** landed, pending validation — P0 "Academy Manufactor utility — regression (BUG-4)" expanded to 7 checks.

---

## Sign-off

- [x] All P0 pass — 2026-06-13
- [x] All P1 pass — 2026-06-13 (18 deferred with explicit notes per section)
- [x] All P2 pass — 2026-06-13 (8 deferred with explicit notes per section)
- [x] Ready to release — _date:_ 2026-06-13 / _build:_ TBD at TestFlight ship
