# Onboarding, Settings, Permissions, and Recovery

**Classification:** Canonical feature contract
**Audience:** Users, support, product, design, engineering, and QA
**Capability status:** Current workspace
**Source authority:** Onboarding flow/state, Settings routes/stores, bootstrap/recovery services
**Last verified:** 2026-08-17
**Primary routes:** First launch, EVA activation, Settings, Life Management, permission prompts, and bootstrap recovery

## Promise and user jobs

Onboarding builds a useful personal Life Map without requiring permissions, EVA, or a network connection. Settings makes control, privacy, integrations, and life structure understandable after activation. Recovery surfaces preserve user work and explain what can be retried safely.

Users need to:

- understand the product promise and privacy model;
- choose and prioritize life areas, set realistic capacity, and optionally route one real capture;
- activate Cloud EVA, configure Offline EVA, or continue without either;
- grant permissions at the moment their value is clear;
- manage projects, areas, routines, reminders, quiet hours, and privacy;
- recover from unavailable dependencies, migration issues, or damaged derived state;
- delete or export data with explicit consequences.

## Onboarding journey

The v4 journey is progressive and visibly assembles one persistent Life Map:

1. Welcome and the promise “Your whole life, in one calm system.”
2. Desired change and up to two sources of friction.
3. Two to five active life areas and their seasonal priority order.
4. Real working capacity and week start.
5. Recommended module connections across Home, Plan, Track, Insights, and EVA.
6. One optional Universal Input capture, reviewed before staging.
7. An idempotent assembly phase and the completed Life Map reveal.
8. Optional, resumable permissions and EVA activation.

Each step has one primary action. Core completion never depends on permission, model download, network access, or sample data. The v4 draft uses snapshot schema 6; a version-3 partial journey restarts safely at Welcome. The commit upserts canonical life areas/order, working hours, and Home layout, stores only goal/friction as small profile metadata, then writes the reviewed capture last. Completion is recorded only after required writes succeed. No starter projects, chores, habits, tasks, or fabricated activity are installed.

Completed users remain completed. An established workspace is never interrupted by a launch prompt; Life Management exposes the live, canonical Life Map and a voluntary “Refresh my map” merge flow that preserves existing records.

## EVA activation and model setup

- Cloud activation explains Luna processing, Sign in with Apple, per-device Apple 18+ eligibility, device trust, credits, bounded context, and optional AI-generated spoken output before consent.
- Sensitive Journal, Health, Life Moments, and personal-memory grants are separate and off by default. Cloud setup force-refreshes verified policy so a cached disabled configuration cannot hide a newly available staging service.
- Offline EVA explains on-device processing, supported hardware, model size, storage impact, download progress, cancellation, retry, insufficient storage, and expected capability.
- The provider chosen for a request stays fixed. Cloud failure may offer explicit Offline EVA but never silently redirects private context to another provider.
- Model choice does not imply clinical, guaranteed, or autonomous behavior. Users can use ordinary LifeBoard when all assistant setup is skipped or fails.

## Permission contract

Request permissions only when the related action is understandable. Pre-permission copy states:

- what capability is unlocked;
- what data LifeBoard reads or writes;
- whether the feature remains useful without permission;
- where the choice can be changed.

Denial does not loop prompts. The feature shows a stable denied state and Settings route. Journal protection, Health, Speech, microphone, camera, notifications, calendar, and system integrations retain separate consent and privacy semantics.

## Settings information architecture

Settings groups:

- profile and appearance/comfort;
- focus rituals and day-management preferences;
- notifications, quiet hours, and reminders;
- calendar, health, speech, model, and other integrations;
- dashboard, trackers, habits, routines, life areas, and project management;
- Journal privacy, lock, app-switcher shielding, and external indexing;
- data export, deletion, diagnostics, and recovery;
- accessibility, shortcuts, credits, and support information.

Low-frequency controls remain out of the primary dock. Destructive life-management actions identify dependent items, available move/archive options, retained history, and irreversible effects.

## Recovery contract

Bootstrap recovery appears when required persistent/canonical services are unavailable. It uses a stable semantic clay surface, no private content, and concrete next steps. Recovery never performs a destructive reset implicitly.

Derived-state recovery can rebuild indexes, caches, or projections without replacing canonical content. Migration recovery preserves additive model versions and stable IDs. A failed recovery remains inspectable and retryable.

## State matrix

| State | Required behavior |
|---|---|
| Fresh start | One clear next action and honest time/permission expectations |
| Resumed onboarding | Restore exact v4 step and recoverable schema-6 Life Map draft |
| Permission denied | Explain limitation, preserve remaining functionality, link to Settings |
| Unsupported device | Describe unavailable capability and keep core app usable |
| Cloud policy disabled | Show the signed maintenance reason and offer explicit Offline EVA |
| Apple/18+/trust failure | Name the failed gate; do not claim that account setup completed |
| Credits unavailable | Show balance/refill recovery; do not retry billable work automatically |
| Download interrupted | Preserve progress/state where supported and offer retry/cancel |
| Missing dependency | Enter bootstrap recovery rather than partial shell |
| Migration interrupted | Preserve stores, expose retry/recovery, avoid reset |
| Destructive management | Confirm scope and provide move/archive/Undo where supported |
| Export failure | Preserve source data and provide retry |

## UI/UX contract

- Onboarding uses the bundled, muted dawn hero video as its single ambient timeline; required copy and controls remain readable over an adaptive scrim.
- The orbit is persistent. Daily Loop stays central, the five application roots form the inner ring, and chosen life areas form the outer ring.
- Ordinary choices use clay. Regular Liquid Glass is limited to the primary control dock or one hero/control surface; glass is never stacked.
- Progress is clear but not punitive.
- Forms use local validation with nearby recovery text and preserve entered values after failure.
- Settings favors grouped open rows and descriptive subtitles over nested decorative cards.
- Destructive actions use semantic warning/danger treatment and remain visually separated from routine Save.
- Success celebrations are brief, replay-safe, and never block the next action.

## Accessibility and platforms

- Dynamic Type keeps all setup choices, permission explanations, Save, Skip, Retry, and Cancel reachable.
- VoiceOver announces step progress, selected options, download progress, validation errors, and destructive consequences.
- iPad/Catalyst uses wider forms with readable maximum line lengths, keyboard traversal, and native menus.
- Reduce Motion removes cinematic transitions without removing context.

## Implementation and evidence

Primary anchors include onboarding flow models/views, EVA activation coordinator, Settings/Life Management views, feature-flag preferences, permission services, bootstrap failure controller, migration/runtime composition, and privacy policy persistence.

Onboarding and Settings expose or consume the staged flags documented by each feature chapter. They must not reinterpret a disabled feature as deleted data. Model eligibility, optional assistant setup, permission state, and rollout state remain independent decisions.

Motion verification must use the non-`-UI_TESTING` audit launch path because `-UI_TESTING` disables process animations. Record frame differences for the video, orbit mutations, capture routing, reveal, and representative root transitions. Explicitly cover Full Motion/system Reduce Motion combinations, Low Power, thermal pressure, Reduce Transparency, VoiceOver reorder actions, Dynamic Type, RTL, iPad split layouts, and signed-device permissions. Model download pressure, production-style migration, export/restore, and complete keyboard/assistive-technology passes remain release gates.
