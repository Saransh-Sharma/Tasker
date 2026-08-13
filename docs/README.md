# LifeBoard Documentation

> Classification: Canonical documentation index
> Audience: Users, support, product, design, engineering, QA, privacy, and release teams
> Capability status: Current workspace, with future scope isolated
> Source authority: The authority map below
> Last verified: 2026-08-13

## Start here

- [Product tour](../README.md)
- [LifeOS Product Handbook](./product/README.md)
- [Current Feature Catalog](./product/FEATURE_CATALOG.md)
- [Public Capability Matrix](./product/PUBLIC_CAPABILITY_MATRIX.md)
- [User Operating Manual](./guides/README.md)
- [Canonical Product Requirements](../PRODUCT_REQUIREMENTS_DOCUMENT.md)
- [Future LifeOS Blueprint — unimplemented](./product/LIFEOS_FUTURE_BLUEPRINT.md)

## Authority map

| Question | Authority |
|---|---|
| What does the current workspace do? | [Feature Catalog](./product/FEATURE_CATALOG.md) and product chapters |
| What may be claimed publicly? | [Public Capability Matrix](./product/PUBLIC_CAPABILITY_MATRIX.md) |
| How should a person use it? | [User Operating Manual](./guides/README.md) |
| What is the intended current product contract? | [Product Requirements](../PRODUCT_REQUIREMENTS_DOCUMENT.md) |
| What is implemented and freshly verified? | [Unified Completion Status](./life-os/LIFEBOARD_UNIFIED_COMPLETION_STATUS.md) |
| How is it structured? | [Architecture Guide](./architecture/LIFEBOARD_V2_ARCHITECTURE_GUIDE.md) and [EVA Architecture](./architecture/LOCAL_LLM_EVA_ARCHITECTURE.md) |
| What are the visual/interaction rules? | [DESIGN.md](../DESIGN.md) and [Product UI/UX Guide](./design/LIFEBOARD_PRODUCT_UI_UX_GUIDE.md) |
| How should the public site communicate and present the product? | [Marketing Site Guide](./design/MARKETING_SITE_GUIDE.md) |
| What might be built later? | [Future Blueprint](./product/LIFEOS_FUTURE_BLUEPRINT.md), always labeled unimplemented |

Runtime code, persistence, routes, targets, entitlements, and public Swift APIs are the final authority for source-state behavior. A document never upgrades a capability to verified or released by assertion.

## Current product chapters

- [Home and Daily Loop](./product/HOME.md)
- [Universal Input and Speech](./product/UNIVERSAL_INPUT.md)
- [Plan, This Week, Focus, and recovery](./product/PLAN_AND_FOCUS.md)
- [Track, habits, goals, routines, care, and wellness](./product/TRACK_AND_WELLNESS.md)
- [Journal, Notes, Knowledge, and reflection](./product/JOURNAL_NOTES_AND_REFLECTION.md)
- [Insights, gamification, and EVA](./product/INSIGHTS_AND_EVA.md)
- [Onboarding, Settings, permissions, and recovery](./product/ONBOARDING_SETTINGS_AND_RECOVERY.md)
- [System surfaces and continuity](./product/SYSTEM_SURFACES_AND_CONTINUITY.md)

Specialist current references: [Calendar and timeline](./calendar/README.md), [Habits](./habits/README.md), [LifeOS implementation hub](./life-os/README.md), and [manual scenarios](./life-os/manual-testing.md).

## Evidence and provenance

`docs/evidence/` contains dated fixtures, snapshots, manifests, and observed test baselines. Research, licenses/notices, asset READMEs, repository instructions, and skill documentation remain provenance/reference material. They do not override current product authority.

Historical TODOs, phase handoffs, completion audits, legacy roadmaps, and superseded PDFs have been removed after current decisions and evidence gates were consolidated. New work tracking belongs in the repository’s Markdown TODO practice, not in a parallel product-spec tree.

## Status language

- **Current:** represented in the checked workspace.
- **Verified in source:** matched to a current runtime symbol or behavior path.
- **Verified by automated evidence:** observed in the named command/run and date.
- **Partial:** present with a documented limitation or rollout boundary.
- **Requires signed-device validation:** simulator/source evidence cannot establish the claim.
- **Future — unimplemented:** direction only and never user-facing current behavior.

## Maintenance rule

Every living product document includes classification, audience, capability status, source authority, and last verified date. Update the catalog and at least one user journey when a capability changes. A public claim also requires an entry in the capability matrix, and a website visual must satisfy the marketing guide and screenshot manifest. Run `scripts/check-documentation-current.sh` before merging documentation changes.
