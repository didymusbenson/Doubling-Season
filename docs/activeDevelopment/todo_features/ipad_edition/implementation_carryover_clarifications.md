# Implementation carryover clarifications — 2026-10-22

**Status:** explicit user decisions reconciled with read-only source evidence. No app implementation, purchase setup or store configuration is performed.

## Wipes versus resets

A board wipe is token-level: destroy creatures or all tokens. It is not a game reset and must not reset life, commander damage, player counters, shared statuses or modifier activation by implication. Target selection and exact command UI follow explicit affected-seat context; central placement does not invent a human actor. Preserve relevant token properties and causal history needed for undo; no automatic full rules-engine/death-trigger resolution is implied.

The Reset menu presents **reset with current configuration**, **complete reset**, and **reload previous game state**. These map to the existing accepted contracts, not three new meanings: keep-board zeros token counts/removes counters while retaining reusable setup and enabled utility selection; complete reset clears tokens/utilities; archive reload saves current then restores selected historical state/timeline, retaining ten archive snapshots and preserving permanent seat customization/decks.

**After either game reset, reset custom rules/modifiers as Tripling Season does.** Its [delete-and-reset-rules action](https://github.com/didymusbenson/Doubling-Season/blob/d30050bd7a1067058fcdf7e707d3a223124a79fb/lib/screens/content_screen.dart#L1039-L1062) calls [disableAllRules](https://github.com/didymusbenson/Doubling-Season/blob/d30050bd7a1067058fcdf7e707d3a223124a79fb/lib/providers/rules_provider.dart#L851-L869): every preset count becomes zero and custom rules become disabled; definitions are not deleted. Apply that result to the new game's seat-owned sources and derived global contributions coherently. Retaining a utility widget or reusable board configuration is not retaining an enabled modifier. Archive restoration is different: restore historical source activation, not reset it again.

This source mapping supersedes the earlier unresolved modifier-retention question. Other per-kind runtime fields still need implementation mapping, but should use existing behavior rather than ask the user to redesign every field.

## Dice

Support standard d4, d6, d8, d10, d12 and d20. Users choose dice types and quantities, then see every individual result plus the sum of all rolls. Do not silently add special systems, automatic game mutations, percentile dice or timers. Exact arrangement and sensible input limits are implementation details; history/undo inclusion of random results is not assumed.

## Mana: Disa's Diary reference baseline

The user points to their existing Disa's Diary implementation as the starting point while recognizing mana may need further specification. Source audit found six manual W/U/B/R/G/C pools, a 3×2 layout, tap ±1, hold ±10, decrement clamped at zero, confirmed Empty, color locks that protect only against Empty, and a convert mode that moves all other colors into the selected color. Locks do not restrict ordinary adjustments or conversion. Conversion exits to normal mode. Actual source uses ±10; an older mana feature document saying ±5 is stale.

This is a source-backed starting design, not authorization to add automatic phase emptying, restricted-mana accounting or a payment solver. Adapt to one authoritative pool per seat, the accepted curated hide/restore semantics and persistent game-wide undo. The phone's literal geometry, hold timing/haptics and counter storage are not automatically tablet implementation requirements. Current source: [mana screen](https://github.com/didymusbenson/Disas-Diary/blob/bb8f79da12d025de0767a584dabf6cc082566868/disas_diary_flutter/lib/screens/mana_pool_screen.dart#L35-L82), [tile gesture implementation](https://github.com/didymusbenson/Disas-Diary/blob/bb8f79da12d025de0767a584dabf6cc082566868/disas_diary_flutter/lib/widgets/mana_tile.dart#L69-L85).

## Deck import and shared catalog

Importing existing Tripling Season decklists is in scope. Use the existing reusable setup format as a bridge, preserve source data, show incompatible/omitted fields honestly, and load into an explicit seat through accepted Replace/Append semantics. A decklist is not a live-game/archive snapshot. This does not authorize shared mutable live storage between products or legacy live-board import.

Use **the same token database and update path**. Existing [remote constants](https://github.com/didymusbenson/Doubling-Season/blob/d30050bd7a1067058fcdf7e707d3a223124a79fb/lib/utils/constants.dart#L202-L210) point to the repository main assets/token_manifest.json and assets/token_database.json. [TokenUpdateService](https://github.com/didymusbenson/Doubling-Season/blob/d30050bd7a1067058fcdf7e707d3a223124a79fb/lib/services/token_update_service.dart) compares versions/minimum app compatibility, verifies size/hash and JSON before promoting pending data with rollback. [Startup check](https://github.com/didymusbenson/Doubling-Season/blob/d30050bd7a1067058fcdf7e707d3a223124a79fb/lib/main.dart#L358-L469) uses a 24-hour throttle and respects dismissed versions/recovery priority. Carry the update principles and feed, not old snackbars against D41.

Substantive adaptation concerns: current filesystem promotion needs a web storage equivalent, and the shared manifest's minimum-app-version contract must be interpreted safely for a separate product/version. Validate compatibility without inventing a second catalog or endpoint. Catalog refresh must not rewrite historical/custom selected art or invalidate active scoped commands silently.

## Visual direction and engineering baseline

Use Lifetap as an iterative reference for life-tracker presentation/arrangements while honoring accepted tablet layouts and creating the new interface, not copying it wholesale. Exact dimensions and small-tablet reach/readability require actual visual/interactive inspection.

Local and global applied modifiers live together in each seat's Rules-equivalent panel, analogous to Tripling Season's Rules button. Foreign-source effects remain non-removable in recipients' panels. Source labels/read-only styling are useful implementation details; a separate Other effects screen is not required.

Default to Tripling Season's deliberate interaction, artwork, ordering and editing principles unless a substantive incompatibility is demonstrated. The custom, player-facing keyboard is the largest net-new interaction, including suppression of the ordinary system-keyboard path, orientation, composition and accessibility validation. Existing single-board globals, unsafe partial saves and nondismissible dialogs are known adaptation concerns, not philosophies to preserve.

## Names and commercial direction

Working potential names, exactly as supplied: **Primal Procession, Anointed Vigor, Exalted Vigor, Primal Sunborn, Doubling Vigor, Anointing Season**. None is selected as final.

The app is **free, with no ads**, using the same IAP model as French Vanilla and Tripling Season. TS's [IAP service](https://github.com/didymusbenson/Doubling-Season/blob/d30050bd7a1067058fcdf7e707d3a223124a79fb/lib/services/iap_service.dart) exposes three non-consumable support tiers, cached ownership, restore and tier access helpers. The audited [TS purchase menu](https://github.com/didymusbenson/Doubling-Season/blob/d30050bd7a1067058fcdf7e707d3a223124a79fb/lib/widgets/purchase_menu.dart#L328-L348) presents Say Thanks/red badge, Play Booster/blue badge and Collector Booster/customizable WUBRG badge. Independent French Vanilla audit likewise found supporter cosmetics and Collector heart customization, not gameplay-rule/content gating. These are optional non-consumable support purchases, not subscriptions or consumable repeat-tip transactions; display live store-supplied prices. No new prices, product IDs, automatic cross-app entitlement sharing or web payment mechanism are specified by this decision.

Disa persists counts and locks, but its immediate updates/unawaited saves are not proof of durable tablet transactions. Retain the accepted coherent state/history/undo contract rather than reproducing that limitation.\n\n## Planned validation

Verify creature/all-token wipe versus both full reset modes, all preset counts zero/custom rules disabled with definitions retained, and archived historical activation restored. Verify chosen dice types/quantities, individual results and sum. Import real TS deck fixtures including custom art and mixed utilities into one seat, then undo without touching others. Exercise same-feed update rejection/hash/version/offline paths on each target. Validate the audited mana actions per seat, including locked Empty versus conversion, and all-modal tapaway barriers. These are planned cases, not executed tests.
