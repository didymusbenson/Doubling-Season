# Compact central component, token actions and life tools — 2026-10-22

Status: implemented and verified locally on `codex/tablet-central-game-hub`, isolated from published main `71c1aee81a368d7ef5c48b195a48923c89647446`. Commander research has resolved the interaction design; final visual/CI review is in progress. Parent visual review is required before merge/deployment. The standing publish instruction applies after that review; no additional user approval round is needed.

## Evidence and correction

The supplied Library `libfile_eead83ed9e08819184fc57190f69338f` was materialized locally through the supported flow and viewed: a 216×63 crop of the rejected toolbar with horizontal top/bottom rules and a vertical seat divider through it. It is failure evidence, not a target mockup. The old `_GameStrip` was centered but remained a 50px control-bearing band with 24.5px reserved in every life lane. Replace it with one standalone circular 52×52 hub at the exact global table center for 2/3/4 seats. It opens the existing shared tools. Thin player boundaries remain outside the hub; only local life-header corner clearance remains. Token lanes keep their full height.

The token reference `libfile_1cc4276e17388191b2757b5ed4b603b4` was materialized/viewed: a Treasure card with a separate wide minus/plus band. Remove that band; compact minus/plus are the first controls in the existing action Wrap, followed by untap, tap, counter, copy, split and applicable special actions. Preserve established 38×40 targets, one-shot remove-all/add-ten holds, clean additions, inline editing, first-line totals, counters, sickness, partial tap, history and undo. Narrow lanes may wrap; no duplicate quantity display is introduced. This is an explicit token exception; life and other numeric trackers keep full halves.

The life reference `libfile_6593d3e55f38819192cdd2ae8e99ec4b` was materialized/viewed. The whole colored life surface is the hit area: read-only name, total, artwork and all internal padding belong to left/right halves. A 66px surface accommodates an 18px name/delta line and the existing 48px number, all inside the full-half target. The pencil is outside it in the tools area, along with all other life tools. Existing 1500ms grouping, transient delta, holds, interruption cancellation, persistence and undo remain authoritative.

Tools in player-local order: recognizable crown Monarch, adjacent City's Blessing, counters, rules, commander access, Edit last. Presets are inside Edit, retaining save/load/Replace/Append. Manage Utilities moves into the utility section's first existing item header (or its empty-state action); no new toolbar row or utility stripe. Retain utility color data and token color rails.

## Commander mini ledger and expanded source grid

Both supplied Lifetap references (`libfile_f9127156ef988191845975fc404706a9`, `libfile_60e6719e3ddc8191bea106766a1321ed`) were materialized and viewed. They show a compact source grid attached below life, including self and multiple incoming sources. Static images do not establish the expansion gesture or source-selection behavior.

Existing `lifetap_research.md` line 108 reports tapping a board mini-grid opened Counters; line 113 records per-cell life coupling; line 151 records partner-art cells. Stable source selection/labels, independent partner adjustments and corrections remain explicitly untested (lines 296, 336–338, 448). Targeted research has now returned and is integrated as [an evidence-labeled addendum](lifetap_commander_revisit_2026-10-22.md). The adaptation is a 60×44 attached read-only source mini ledger; tapping anywhere on it opens a compact, seat-oriented source grid with direct full-half adjustments. No separate source picker or generic navigation menu is added. Each source retains its own ID, owner color/art, name and amount, including separate partners and self. The empty ledger remains visible with per-player zero/self placeholders and opens direct setup with an explicit owner choice. No commander source is silently created.

Expanded source cards are bounded at 200px width. The focused workspace is at most 680×640 (520px minimum requested height within available safe bounds), instead of the general 1050×940 workspace. Main player-navigation chrome is omitted for this focused page; Damage/Sources provides direct setup and existing advanced correction. Variable source lists scroll; normal damage ± is directly available on each source card. New damage/decrement commands retain coupled life changes; ledger-only corrections, history and undo are unchanged. Tapaway closes the full-table modal and consumes the gesture; close/reopen returns updated values to the mini ledger. These self/setup/correction/dismissal details are our explicit product contract, not verified Lifetap parity.

## Acceptance checklist and platform boundary

- [x] Reference pixels inspected; old compact-component assertion fails before production edits.
- [x] Global center and fixed 52×52 bounds for 2/3/4 players at 1133×744, 744×1133 and 1366×1024, safe-area/zero-inset scenarios, full token lanes and no life/tool overlap.
- [x] Token compact inline action ordering, rotated seats, specialized holds, zero clamp/no accidental expand, clean add behavior and expanded last-token FAB clearance.
- [x] Entire life colored bounds equal the union of its two halves; name and near-border corners adjust life in both orientations; tools do not mutate life or overlap the surface.
- [x] Crown/Blessing adjacency, Edit last, presets inside Edit, utility manage located in utility content; Monarch transfer/undo and independent Blessings remain tested.
- [x] Final aggregate suite: **199/199 PASS**; analysis clean; release web build PASS. Both empty-source owner-setup scenarios and eight-source direct adjustments/undo from both facing seats pass in 1133×744 and 744×1133. Source-enabled default Storm/mana capacity and 48px life legibility remain intact.
- [x] Commander ledger→expanded source grid, owner setup, partner/self identity/style, coupled adjustment/undo and tapaway/no-clickthrough regressions.
- [x] Final local analysis, aggregate tests and release web build. Real-font renderer suites: 71/71 plus two eight-source scenarios PASS.
- [ ] CI web/Android/iOS simulator builds.
- [x] Final renderer pixels inspected: 2/3/4 seats, small landscape/portrait, standalone central hub, inline token actions, crown/adjacent Blessing, disjoint colored life/tools, collapsed ledger and expanded source grid, final expanded-token FAB clearance.
- [ ] Independent parent live-browser/visual review before publication.
- [ ] Exact merged/deployed SHA, combined Pages artifact and both live app URLs verified after authorization.

Renderer screenshots are Flutter widget-test evidence with real fonts, not release-browser or native acceptance. Shared Flutter changes target web, Android tablets and iPad. Native hands-on validation remains unavailable under the locked-host restriction; no bypass, signing/account changes, installs or data resets are authorized by this correction. The original root app and deployment workflow remain unchanged.


Release artifact `apps/tablet/build/web/main.dart.js` SHA-256: `5bd529ad1201f0a9b2d76038e6112ef9f7fe1148ff70d66ed66f8e1ff9715ada`. Screenshots under the task workspace's `central-hub-final-evidence/` are Flutter renderer captures; Library saving is currently pending because the prepared-upload skill resource became unavailable during the run. Root app files and combined Pages workflow are unchanged. Final PR/check/deployment records will supply exact commits.
