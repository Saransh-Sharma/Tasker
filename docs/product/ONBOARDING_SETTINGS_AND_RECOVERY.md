# Onboarding, Settings, Permissions, and Recovery

**Classification:** Canonical feature contract
**Primary routes:** First launch, EVA activation, Settings, Life Management, permission prompts, and bootstrap recovery

## Promise and user jobs

Onboarding gets a person to one useful, completed loop without requiring full configuration. Settings makes control, privacy, integrations, and life structure understandable after activation. Recovery surfaces preserve user work and explain what can be retried safely.

Users need to:

- understand the product promise and privacy model;
- create or choose life areas, a first task, and an initial focus;
- configure EVA locally or continue without it;
- grant permissions at the moment their value is clear;
- manage projects, areas, routines, reminders, quiet hours, and privacy;
- recover from unavailable dependencies, migration issues, or damaged derived state;
- delete or export data with explicit consequences.

## Onboarding journey

The journey is progressive:

1. Welcome and product promise.
2. Goal/context selection.
3. Life area and starter workspace choices.
4. First task with enough detail to act.
5. Focus demonstration and completion.
6. EVA preference/model setup where supported.
7. Optional permissions in context.
8. Outcome summary and entry into the five-root shell.

Each step has one primary action. Skip is offered where the feature is optional and explains the resulting limitation. Progress persists so termination or interruption resumes at the correct step. Starter content uses canonical repositories and reversible installation/compensation.

## EVA activation and model setup

- Explain local processing, device support, model size, storage impact, and expected capability before download.
- Model choice does not imply clinical, guaranteed, or autonomous behavior.
- Download shows truthful progress, cancellation, retry, insufficient-storage, network, and unsupported-device states.
- Users can use the non-assistant app when model setup is skipped or fails.

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
| Resumed onboarding | Restore exact step and recoverable draft |
| Permission denied | Explain limitation, preserve remaining functionality, link to Settings |
| Unsupported device | Describe unavailable capability and keep core app usable |
| Download interrupted | Preserve progress/state where supported and offer retry/cancel |
| Missing dependency | Enter bootstrap recovery rather than partial shell |
| Migration interrupted | Preserve stores, expose retry/recovery, avoid reset |
| Destructive management | Confirm scope and provide move/archive/Undo where supported |
| Export failure | Preserve source data and provide retry |

## UI/UX contract

- Onboarding uses cinematic atmosphere sparingly; required copy and controls sit on readable surfaces.
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

Recorded evidence covers onboarding persistence, first-task/focus flow, model eligibility policy, Settings migration, life-management destructive flows, permission copy surfaces, and bootstrap semantic presentation. Signed-device permissions, model download pressure, production-style migration, export/restore, and complete keyboard/assistive-technology passes remain release gates.
