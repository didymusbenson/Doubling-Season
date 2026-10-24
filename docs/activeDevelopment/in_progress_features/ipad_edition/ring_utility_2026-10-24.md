# The Ring utility — provisional field-feedback implementation

The user authorized a best-effort implementation on 2026-10-24 and deliberately
deferred complete design and feedback. The choices below are reviewable first
passes, not fully settled requirements.

## Rules basis

The Ring is a per-player emblem, not a normal token. Each temptation chooses a
controlled creature as Ring-bearer (the existing bearer may be chosen again) and
advances the emblem by one ability, up to four. Temptation remains meaningful
after four abilities. With no creatures, progress still advances without a
bearer. Losing a bearer does not remove progress. The designation ends if the
bearer leaves the battlefield, changes controller, or another is chosen.

Sources reviewed on 2026-10-24:

- [Official mechanics explanation](https://magic.wizards.com/en/news/feature/the-lord-of-the-rings-tales-of-middle-earth-mechanics)
- [Official release notes](https://magic.wizards.com/en/news/feature/the-lord-of-the-rings-tales-of-middle-earth-release-notes)
- Current Comprehensive Rules 701.54a–e, researched by the parent:
  [September 25 rules](https://media.wizards.com/2026/downloads/MagicCompRules%2020260925.txt)

The four UI reminders summarize emblem effects on the bearer. They do not add
creature keywords or execute combat triggers, draw/discard, sacrifices, blocking
restrictions, legendary-state rules, or opponent life changes.

## Concrete first-pass decisions

- Add **The Ring** from Utilities or select the existing Ring catalog emblem.
  New catalog selection routes to the utility rather than creating token stacks.
  One utility per seat is restored/shown on repeat addition.
- The board shows stage `min(temptations, 4)`, total temptations, and an optional
  bearer label. **Tempt** opens the seat-facing workspace. A name may identify
  any physical or token creature; keeping the same name chooses it again.
- **The Ring tempts you** commits one temptation and the chosen bearer in one
  acknowledged history command. **No creatures** advances with no bearer.
  Opening, canceling a choice, or dismissing the draft does not tempt the player.
- **Clear bearer** retains progress. **Correct** explicitly edits count and
  label together. There is no automatic relationship to token stacks.
- The count uses the existing `UtilityState.value`; `configuration.ringBearer`
  is a manual label. Existing aggregate persistence/history needs no schema
  migration. Undo restores both fields; persistence errors retain the old state
  and recoverable workspace draft.
- Start Turn does not alter The Ring. Keep-board new-game reset retains utility
  inclusion/art/configuration while clearing count and bearer. Complete reset
  restores only the established Storm and Mana defaults. Presets retain Ring
  inclusion and metadata, never the live count or bearer. Appending a setup does
  not duplicate or reset an existing Ring utility.
- Existing saved Ring token objects, prior presets, archives and history remain
  intact. They are not destructively converted or rewritten on load.
- Reuse the catalog's large-URL art, LTR / Viko Menezes, with display-time crop:
  `https://cards.scryfall.io/large/front/7/2/7215460e-8c06-47d0-94e5-d1832d0218af.jpg`.
  HEAD verification returned HTTP 200, JPEG, 112389 bytes on 2026-10-24.

## Deliberately deferred complete design

Revisit physical bearer identification; optional links to token objects and
single-creature stack splitting; automatic clearing when a linked bearer leaves
or changes controller; opt-in conversion of legacy Ring objects; correction
ergonomics and temptation-count presentation; card reminder density and compact
tablet workspace layout. These need the user's later field feedback. No
automatic rules enforcement or native acceptance is claimed by this document.

## Verification

Focused regressions cover five temptations, no creatures, choosing the same
bearer, clearing/undo without losing progress, seat isolation, save failure,
stale scope, persistence/reopen, Start Turn, both reset modes, preset zero-state
semantics/append singleton, new catalog routing, unchanged legacy objects, and
atomic workspace confirm/cancel in iPad mini portrait/landscape dimensions.
The existing all-utility fixed-modal regression includes The Ring. Exact test
results and native pixel review are recorded in the parent batch evidence.
