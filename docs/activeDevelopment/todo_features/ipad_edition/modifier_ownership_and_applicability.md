# Modifier ownership and applicability

**Status:** D25 source ownership/local-global distinction accepted 2026-10-21. Contracts below distinguish accepted behavior, recommended representation and technical validation. No implementation or full rules-engine claim.

## Accepted behavior

- Each seat owns its modifiers. Ownership identifies the source context, not a human access permission or visual position.
- Local and global effects are differentiated. A seat-owned global modifier such as Primal Vigor impacts applicable operations across the table, rather than remaining a personal-board approximation.
- Other seats cannot independently remove that source from inside their own modifier panels. Disabling/removing the originating modifier removes its contribution from recipients, not their independently owned modifiers.
- Two seats enabling copies means independent sources. Do not collapse them by name or manufacture extra copies for recipient panels.
- The user allows either a propagated enabled representation or an Other effects representation that recipients cannot remove. **Recommendation only:** read-only Other effects with source-seat labels. Exact UI is not settled; a propagated representation must still be linked to the authoritative source rather than independently mutable.

## Proposed source/evaluation contract

One session-scoped modifier source has stable source identity, owning seat/participant, definition, enabled state, count/configuration, declared local/global applicability and revision. Concrete schema names remain proposed. The effective input for an operation is its target seat's applicable local sources plus applicable global sources, each authoritative source included exactly once. Global does not mean “apply to every numeric value”: token creation, eligible counters, life, mana and unrelated statuses remain distinct domains.

Capture source IDs/revisions and target context when planning; after asynchronous work revalidate against current effective sources. A shared source change can invalidate a recipient's preview even when that recipient's own modifier list is unchanged. No last-active-seat lookup, copied recipient switch, stale aggregate count or display-only toggle may become a second authority. Namespaced source/group provenance must survive persistence, preset/library conversion if later included, history and recovery.

Enabling/disabling a source changes applicability for subsequent operations; it is not a request to retroactively recalculate previously created tokens/counters. Record an attributable source-seat action with its affected scope in the single game timeline. A central-origin operation, if provided, still records game origin and affected sources without fabricating a human actor. Latest-action undo restores source state and effective applicability as one coherent operation; evaluated token/counter commands separately retain their complete derived results and causal source snapshot. Do not replay historical events as fresh token entries.

This source/applicability model does not approve token ownership/control transfers, combat inference, automatic phase handling or a general rules engine. Existing manual monarch/day-night and warning-only bookkeeping remain unchanged.

## Actual calculator baseline and limits

Source evidence is pinned to current audited main, `d30050bd7a1067058fcdf7e707d3a223124a79fb`.

- Current evaluation is phased: custom also-create; Academy Manufactor; Chatterfang; custom replace; custom multiply; preset token doubler, Doubling Season, Primal Vigor and Ojer Taq. Custom sorting does not provide arbitrary ordering across those phases. Custom also-create/multiply counts expand; replace is not expanded the same way. [Builder](https://github.com/didymusbenson/Doubling-Season/blob/d30050bd7a1067058fcdf7e707d3a223124a79fb/lib/providers/rules_provider.dart#L336-L466).
- Each existing Primal Vigor count emits one ×2 token multiplier. For +1/+1 counters, current calculation adds the extra-counter amount then applies the relevant powers-of-two doublers, including Primal Vigor. Other counter calculations do not include Primal Vigor. This is observed calculator behavior, not a newly asserted comprehensive card-rules implementation. [Counter calculation](https://github.com/didymusbenson/Doubling-Season/blob/d30050bd7a1067058fcdf7e707d3a223124a79fb/lib/providers/rules_provider.dart#L750-L767).
- Companions continue at the next rule, not the start of evaluation; creator-group suppression avoids repeated self-application. Academy Manufactor's forced utility count and preset count use the maximum, not their sum. Preserve those distinctions rather than doubling an effect merely because it appears in another view. [Companion evaluation](https://github.com/didymusbenson/Doubling-Season/blob/d30050bd7a1067058fcdf7e707d3a223124a79fb/lib/providers/rules_provider.dart#L608-L675), [forced-count builder](https://github.com/didymusbenson/Doubling-Season/blob/d30050bd7a1067058fcdf7e707d3a223124a79fb/lib/providers/rules_provider.dart#L336-L395).
- Existing evaluator arguments/results do not supply seat/source ownership. Current global/group keys cannot simply be copied into multiple seat stores and assumed safe. Adapt source provenance and effective-input resolution before reusing arithmetic. Exact multi-source ordering, count handling, replacement/companion interactions and counter applicability require explicit fixtures and current rule verification where card semantics are claimed; no new blanket stacking algorithm is approved here.

## Reset, presets and archive boundaries

Accepted keep-board/complete-reset behavior for tokens, utilities, life and statuses is unchanged. **Modifier activation/configuration retention for each reset mode remains open** and must be mapped explicitly. Do not infer that a global source survives because some recipient keeps a board, or disappears merely because its UI is hidden. Removed-seat handling must not leave an ownerless active contribution; exact clearing versus retention/reassignment is part of the source lifecycle/reset mapping, not an approved reassignment behavior.

Archive snapshots restore historical source ownership, activation, configuration and applicability together with historical state/timeline. Persistent seat name/life art does not imply persistent active modifier sources. Preset contents remain the accepted token list plus utility preferences; whether source modifiers are included in a preset is not silently decided by this document. Before reset/restore, capture sources and affected projections coherently; never serialize propagated views as extra independent copies.

## Planned validation

V20 covers local-only scope, global application, recipient non-removability, two independently owned copies, source disable/remove, latest-action undo, stale previews, restart and archive restore. Test both source and recipient seats with identical names and matching tokens. Validate no duplicate application through inherited panels, no loss of B's independent source when A disables theirs, and no retroactive mutation of committed values. Add per-reset expectations once activation retention is settled. These are planned manual cases, not passed tests.
