# LifeBoard LifeOS Product Handbook

> Classification: Canonical product documentation
> Audience: Users, support, product, design, engineering, and QA
> Capability status: Current workspace, with future work isolated in the blueprint
> Source authority: Runtime code, persistence models, routes, public Swift APIs, and observed verification
> Last verified: 2026-08-13

This handbook explains what LifeBoard currently does, how to use it as a personal operating system, and where to find evidence about implementation status. It does not treat a design aspiration as shipped behavior.

## Choose your path

- New to LifeBoard: start with [Getting Started](../guides/GETTING_STARTED.md), then [Running Your Day](../guides/RUNNING_YOUR_DAY.md).
- Looking up a capability: use the [Feature Catalog](./FEATURE_CATALOG.md).
- Publishing a claim: verify it in the [Public Capability Matrix](./PUBLIC_CAPABILITY_MATRIX.md).
- Designing a complete operating practice: use the [User Guides](../guides/README.md).
- Evaluating current scope: read the [Product Requirements Document](../../PRODUCT_REQUIREMENTS_DOCUMENT.md) and [completion status](../life-os/LIFEBOARD_UNIFIED_COMPLETION_STATUS.md).
- Considering product direction: read the clearly unimplemented [Future LifeOS Blueprint](./LIFEOS_FUTURE_BLUEPRINT.md).

## Current product reference

| Area | Canonical chapter | Practical guides |
|---|---|---|
| Home and Daily Loop | [Home](./HOME.md) | [Run the day](../guides/RUNNING_YOUR_DAY.md), [recover](../guides/RECOVERING_REFLECTING_AND_ADAPTING.md) |
| Capture and speech | [Universal Input](./UNIVERSAL_INPUT.md) | [Getting started](../guides/GETTING_STARTED.md) |
| Tasks, plans, week, and Focus | [Plan and Focus](./PLAN_AND_FOCUS.md) | [Work](../guides/MANAGING_WORK_AND_PROJECTS.md), [week](../guides/PLANNING_AND_REVIEWING_YOUR_WEEK.md) |
| Habits, goals, routines, care, and wellness | [Track and Wellness](./TRACK_AND_WELLNESS.md) | [Health](../guides/MANAGING_HEALTH_AND_WELLBEING.md) |
| Journal, Notes, and Knowledge | [Journal and Knowledge](./JOURNAL_NOTES_AND_REFLECTION.md) | [Reflect and adapt](../guides/RECOVERING_REFLECTING_AND_ADAPTING.md) |
| Insights, rewards, and EVA | [Insights and EVA](./INSIGHTS_AND_EVA.md) | [Run the day](../guides/RUNNING_YOUR_DAY.md) |
| Setup, permissions, settings, and repair | [Onboarding and Settings](./ONBOARDING_SETTINGS_AND_RECOVERY.md), [Life Weave v6 contract](./LIFE_WEAVE_V6_AND_SETUP_CENTER.md) | [Privacy and devices](../guides/PRIVACY_DATA_DEVICES_AND_INTEGRATIONS.md) |
| Widgets, Siri, Watch, and continuity | [System Surfaces](./SYSTEM_SURFACES_AND_CONTINUITY.md) | [Privacy and devices](../guides/PRIVACY_DATA_DEVICES_AND_INTEGRATIONS.md) |

Specialist references remain for the [calendar/timeline](../calendar/README.md), [habit runtime](../habits/README.md), [architecture](../architecture/LIFEBOARD_V2_ARCHITECTURE_GUIDE.md), [visual system](../../DESIGN.md), and [marketing-site expression](../design/MARKETING_SITE_GUIDE.md).

## The LifeOS model

LifeBoard organizes action through one maintainable chain:

`life area → project or goal → task, habit, routine, or tracker → day/week placement → evidence and review`

The five roots answer different questions:

- **Home:** What matters now?
- **Plan:** When and in what order?
- **Track:** What am I sustaining or learning?
- **Insights:** What patterns does my evidence support?
- **EVA:** Help me understand or safely change the plan.

Journal, Notes, Knowledge, Focus, Settings, and entity details are destinations within this system, not parallel roots or duplicate stores.

## Shared behavior contract

- Canonical repositories own records; Home cards, widgets, Watch, Spotlight, notifications, and EVA cards are projections.
- Consequential assistant changes require a visible proposal and explicit Apply. Supported changes produce a receipt and Undo.
- Fixed external calendar events remain calendar-owned. LifeBoard changes only its own time blocks and planning metadata.
- Empty, loading, stale, offline, denied, locked, and error states are honest and recoverable. An explicit zero is data, not an empty state.
- Private content is minimized outside the app. Journal and health information receive the strongest protection and never appear in an unsafe preview.
- Health language is non-clinical; money language is non-advisory; shared-data direction is consent-first.

## Capability status language

| Label | Meaning |
|---|---|
| Current | Present in the checked workspace and represented by current runtime types or surfaces |
| Partial | Present, but with a documented limitation, rollout flag, platform constraint, or incomplete verification |
| Projection | Read or action surface backed by another canonical authority |
| Future — unimplemented | Product direction only; not available in the current workspace |

The workspace can contain uncommitted product changes. “Current” therefore describes source state, not an App Store release claim. Only the verification ledger may say a build or scenario was observed to pass.
