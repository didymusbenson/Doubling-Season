# Tablet app — MVP field testing

**Current phase:** freeze implementation, collect field-test feedback, then plan
one deliberate next batch. Updated 2026-10-23 (America/Phoenix).

The separate tablet app lives in `apps/tablet`, currently named **Tripling
Table** for development. The audited baseline is `a79a381` (PR #47), installed
as a signed **Release 0.1.0+1** on an iPad Air 13-inch (M3). The original phone
app remains a separate product.

The initial feature scope is represented in the implementation. **MVP means
the frozen implementation baseline here, not completed release acceptance.**
The initial documents also contain validation obligations which are still open;
the [readiness audit](mvp_readiness_audit.md) identifies them without turning
unrun tests into passes or known implementation defects.

## Where things live

| Location | Purpose |
|---|---|
| [Readiness audit](mvp_readiness_audit.md) | Requirements-to-source/evidence map and remaining acceptance work |
| [MVP dossier](MVP/README.md) | Preserved initial requirements, decisions, research, implementation and correction records |
| [MVP validation plan](MVP/08_delivery_validation_and_risks.md) | Original validation scenarios; historical statuses are not current pass claims |
| [Physical iPad handoff](MVP/physical_ipad_handoff_2026-10-23.md) | Signed build/install/launch evidence and its limits |
| [Next pass](next_pass/README.md) | Feedback collection and the later batch-planning process |
| [Field-test feedback](next_pass/field_test_feedback.md) | Observations to aggregate before choosing changes |
| [Future directions](future/README.md) | Previously deferred ideas, not an approved next-pass backlog |

## Current working agreement

The user is field testing on iPad and wants to collect substantial feedback
before another implementation pass. Record observations with context, preserve
successful behavior, and group related feedback before proposing priorities.
Do not turn individual observations, old proposals, or unverified acceptance
items into automatic spot fixes. Feedback recording does not authorize app
changes. Start implementation only when the user is ready and the next batch's
scope has been agreed.

The preserved requirements remain binding. Archiving their planning history
does not waive token parity, player isolation, durable recovery, the full
2/3/4-seat tablet layout, or player-facing input. Six-player/foldable/extra
keyboard options remain deferred. Native gameplay validation and eventual
store preparation are distinct from this installed test build.

Original app: <https://didymusbenson.github.io/Doubling-Season/>

Tablet preview: <https://didymusbenson.github.io/Doubling-Season/tablet/>
