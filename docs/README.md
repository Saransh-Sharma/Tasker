# LifeBoard Docs

This directory is the navigation hub for product, architecture, audit, feature, and release-evidence documentation in LifeBoard.

## Current status and design authority

- [LifeBoard 5.0 remaining execution ledger](./todos/LIFEBOARD_5_REMAINING_EXECUTION_LEDGER.md) - the sole active completion tracker.
- [LifeBoard 5.0 implementation and design audit](./audits/LIFEBOARD_5_IMPLEMENTATION_AND_DESIGN_AUDIT_2026-07-23.md) - reviewed source, automated evidence, documentation reconciliation, and device gates.
- [Root DESIGN.md](../DESIGN.md) - the canonical warm clay/paper visual contract. Swift tokens remain the implementation source of truth.
- [LifeBoard 5.0 product handbook](./product/README.md) - canonical feature, journey, state, responsive, privacy, and acceptance behavior.
- [Product UI/UX guide](./design/LIFEBOARD_PRODUCT_UI_UX_GUIDE.md) - canonical cross-feature interaction and presentation rules.
- [Deep completion traceability](./todos/LIFEBOARD_5_DEEP_COMPLETION_TRACEABILITY.md) - release-contract evidence and historical traceability; defer present completion status to the remaining ledger.

## Canonical references

- [Life OS implementation hub](./life-os/README.md) - Phase I/II architecture, operational flags, migration/privacy contracts, manual QA, and the roadmap from Adaptive Home to the complete Life OS.
- [Local EVA / LLM architecture](./architecture/LOCAL_LLM_EVA_ARCHITECTURE.md) - source of truth for local inference, chat routing, Chief of Staff day overview cards, planner proposals, apply/undo boundaries, and timeline-aware assistant context.
- [Assistant mascot persona placement guide](./design/EVA_MASCOT_PLACEMENT_GUIDE.md) - source of truth for selectable Chief of Staff personas, sprite resources, placement mapping, accessibility rules, and QA checklist.
- [LifeBoard V2 architecture guide](./architecture/LIFEBOARD_V2_ARCHITECTURE_GUIDE.md)
- [Habit UX audit](./audits/HABITS_IOS_UX_AUDIT_2026-04-17.md)
- [Premium clay, glass, and motion execution record](./todos/LIFEBOARD_PREMIUM_CLAY_GLASS_MOTION_EXECUTION.md) - detailed migration history and remaining visual-surface work.

## Feature Packages

- [Adaptive Home](./product/HOME.md)
- [Plan and Focus](./product/PLAN_AND_FOCUS.md)
- [Track and Wellness](./product/TRACK_AND_WELLNESS.md)
- [Journal, Notes, and Reflection](./product/JOURNAL_NOTES_AND_REFLECTION.md)
- [Insights and EVA](./product/INSIGHTS_AND_EVA.md)
- [Onboarding, Settings, and Recovery](./product/ONBOARDING_SETTINGS_AND_RECOVERY.md)
- [System Surfaces and Continuity](./product/SYSTEM_SURFACES_AND_CONTINUITY.md)
- [Phase I — Life OS Foundation](./phase-1-life-os-foundation.md)
- [Phase II — Unified Adaptive Home](./life-os/phase-2-adaptive-home.md)
- [Habits feature docs](./habits/README.md)
- [Calendar + timeline docs](./calendar/README.md) - canonical Home/timeline product contract for the single-glanceable day command center, read-only calendar schedule context, timeline runtime, task-fit hints, timeline-aware Eva guidance, risks, and roadmap.

## Historical records and evidence

- [Implementation-record index](./todos/README.md) classifies the active ledger, release traceability, migration records, and historical TODOs.
- [LifeBoard 5.0 visual literal audit](./evidence/lifeboard-5/VISUAL_LITERAL_AUDIT.md) is a dated static-analysis evidence snapshot.
- [Root-state fixtures](./evidence/lifeboard-5/root-state-fixtures/README.md) cover deterministic populated, empty, loading, denied, and error projections.
- [Appearance and comfort matrix](./evidence/lifeboard-5/appearance-matrix/README.md) records simulator captures across selected appearance and accessibility modes.
- Research and licenses remain preserved provenance. They are not product requirements, implementation status, or visual authority.

## Day Management Model

The timeline, calendar schedule feature, and Eva are one product system:

- Calendar schedule provides read-only reality: fixed commitments, busy periods, next meeting, free-until state, and selected-calendar scope.
- The Home timeline interprets that reality alongside tasks, habits, routines, completed work, and open gaps.
- Eva acts as the chat-first Chief of Staff over that day picture, helping the user understand, sequence, repair, defer, and protect focus without silently mutating tasks or external calendars.

When documenting this system, keep the split clear:

- Product behavior and user-facing schedule semantics belong in the calendar package.
- LLM, chat, prompt routing, context projection, day overview cards, proposal cards, and apply/undo trust mechanics belong in the Eva architecture document.
- Broad product priorities, success metrics, and acceptance criteria belong in the PRD.

## Working Rule

When a feature gets its own documentation package, keep the PRD, roadmap, and supporting notes linked to that package instead of duplicating the same contract in multiple places. Calendar, timeline, and Eva-assisted day management now follow that rule.

## Status language

Use **verified in source**, **verified by automated evidence**, **partially implemented**, **unverified**, and **requires signed-device validation** in new audits. A historical checked item must not be read as fresh release approval without current evidence. Signed-device performance, accessibility hardware, account, and paired-device behavior remain explicit gates.

## Document classifications

- **Canonical:** current product, design, or architecture behavior.
- **Active status:** the remaining execution ledger only.
- **Audit snapshot:** evidence observed at a dated point.
- **Implementation record:** a TODO or phase plan that preserves work history.
- **Evidence:** screenshots, manifests, and executable-result notes.
- **Reference:** research, attribution, or external technical context.

Research, evidence, audits, and implementation records can explain why a decision exists, but they do not override the canonical handbook, architecture, DESIGN.md, or active ledger.
