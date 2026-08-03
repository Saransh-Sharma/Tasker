# Life OS Implementation Hub

> **Classification: Canonical implementation and architecture hub.**

This package is the canonical handoff for the LifeBoard-to-Life-OS program. It
describes what is implemented, how rollback works, which contracts later phases
must preserve, and what evidence still requires signed hardware. Current status
is owned by the [LifeBoard Unified Completion Status](./LIFEBOARD_UNIFIED_COMPLETION_STATUS.md);
the dated audits preserve their historical evidence boundaries.

Product and UI behavior is now canonical in the [LifeBoard 5.0 Product Handbook](../product/README.md) and [Product UI/UX Guide](../design/LIFEBOARD_PRODUCT_UI_UX_GUIDE.md). This package remains the implementation, activation, invariant, and release-gate handoff.

## Current state

| Phase | State | Product outcome |
|---|---|---|
| Phase I — Foundation | Complete | Stable shell, routes, capture arbitration, daypart/theme context, atmospheric policy, and versioned dashboard persistence |
| Phase II — Unified Adaptive Home | Complete | Canonical customizable Home, Smart Slots, Trackers/Health/care, shared Journal, Knowledge Notes, and no legacy Home fallback |
| Phase III — Planning Core | Complete | Planning schema, EventKit/free windows, Day/Week/Backlog, receipts/Undo, Focus, deterministic ranking/repair, and Home projections |
| Phase IV — Track Foundations | Complete | Goals, routines, resilience, care, habits, wellness, nutrition, life moments, Track Today, Universal Capture, and Home projections |
| Unified Phases 0–8 | Code-complete for available gates | Daily Loop, Rescue extraction, architecture retirement, clay refinement, Beyond Notes continuity, adaptive layouts, system surfaces, and release reconciliation |
| Public promotion evidence | External observation pending | Signed-device delivery, paired Watch, populated CloudKit, hardware accessibility, performance, and final visual approvals |

Detailed references:

- [Phase I implementation handoff](../phase-1-life-os-foundation.md)
- [Phase II implementation handoff](./phase-2-adaptive-home.md)
- [Manual test playbook](./manual-testing.md)
- [Roadmap to the complete Life OS](./roadmap.md)
- [Phase III/IV implementation status](./phase-3-4-implementation.md)
- [LifeBoard visual contract](../../DESIGN.md)
- [LifeBoard product handbook](../product/README.md)

## Developer activation

All retained staged surfaces default on in Debug and Release. A normal launch
opens canonical Adaptive Home without launch arguments. Adaptive Home itself has
no flag, fallback host, or obsolete disable argument.

Debug CI may use a retained surface's `-LIFEBOARD_DISABLE_<ARGUMENT>` launch
argument to isolate its presentation. Stored overrides provide the corresponding
data-preserving Release rollback. Re-enabling a surface must reveal the same
canonical records. Enable arguments remain compatibility-only test controls;
they are not needed for ordinary launches.

## Invariants for future phases

- The shared Home layout is one ordered placement set. Mode is context, never a persistence key.
- Widget sizes are semantic: `compact`, `standard`, `wide`, and `tall`.
- Unknown widget kinds/configurations must survive migrations and downgrades without becoming visible.
- Managed objects never cross actor, route, or repository boundaries.
- Journal, mood, health, and biometrics are `privateSensitive`; ordinary personal planning data is `privateStandard`.
- Shared/collaborative records must be explicit whitelist projections, never direct exposure of private records.
- Audio, embeddings, semantic chunks, caches, drafts, graph positions, and diagnostic derivatives remain local-only.
- Daypart changes atmosphere; system appearance and accessibility control functional surfaces.
- Static rendering is a complete experience, not a degraded error state.
- Eva may explain and propose, but consequential mutations require an explicit review/apply boundary.

## Verification snapshot

The final checkpoint passes 2,071 tests with 3 environment skips and zero
failures; iOS Debug and Release, Widgets Debug, Share Extension Debug, and Mac
Catalyst Debug builds; all eight repository guardrails; 18 signature Metal
shaders; and 23 bundled TaskModelV3 versions. The Watch build is unobserved
because this workspace has no watchOS Simulator runtime. Detailed journeys and
the distinction between automated completion and external evidence live in the
[Unified Completion Status](./LIFEBOARD_UNIFIED_COMPLETION_STATUS.md).

## Release gates still requiring external conditions

- Upgrade a production-style populated database on a signed physical iPhone and iPad.
- Exercise iCloud enabled, disabled, signed out, account switched, offline edits, and remote merges.
- Verify Watch and widgets against the shared production App Group.
- Capture cold-launch, warm mode switch, capture latency, memory, energy, and scroll hitch metrics on matched hardware.
- Complete VoiceOver, Switch Control, keyboard, Dynamic Type, Reduce Motion, Reduce Transparency, high contrast, Low Power, and thermal-pressure passes.
- Review Health and Speech permission copy, App Privacy responses, exported privacy manifest, and external-surface redaction.
- Approve morning, afternoon, evening, and night reference screenshots across iPhone and iPad.
