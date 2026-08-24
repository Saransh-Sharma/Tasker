# Onboarding, Settings, Permissions, and Recovery

**Classification:** Canonical feature contract
**Audience:** Users, support, product, design, engineering, and QA
**Capability status:** Current workspace
**Source authority:** Onboarding flow/state, Settings routes/stores, bootstrap/recovery services
**Last verified:** 2026-08-20
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

Life Weave v6 is canonical for every fresh install. Its signed presentation
switch is an emergency kill switch, not a route back to v5. Legacy v5 and
interrupted v6 drafts are accepted only as migration inputs and resume in the
six-stage graph without losing confirmed answers.

### v6 — Life Weave (six core steps, schema 9)

1. **Arrival.** The promise, the privacy line, and one action. No feature list,
   no root names, no percentage.
2. **Intent.** What would make this week feel lighter. The sources of friction
   unfold *inline* under the chosen answer, are optional, and never gate the
   primary action.
3. **Life areas.** Two to five, and — inline, after the second selection — which
   one needs the clearest path first. One tap replaces the drag ranking.
4. **Day shape.** Presets first, including "my days move around" as a
   first-class answer. Exact hours, weekends, and week start sit behind `Edit
   hours`; week start is derived from the locale and shown as a fact with a way
   to change it, not as a question.
5. **First capture.** One real sentence, interpreted in front of the person and
   reviewed in place. Nothing is written until they keep it. When the
   interpretation is genuinely uncertain the destination is *asked*, never
   guessed. Onboarding offers Task and Journal, which are the two stores it
   actually writes.
6. **Reveal.** A deterministic personalised sentence, a receipt of what was
   saved, and explicit **Start my day** and **Personalize more** exits. Both
   finalize; the second opens Home and then Setup Center.

Calendar, Apple Health, and Cloud EVA are offered in an optional **Power-Up
phase** that begins *after* core completion has been recorded, and are also
permanently available in Setup Center. Reminders stay contextual and are still
never requested during first run.

They remain **completion gates for nothing**. `AppOnboardingStateStore.completeCore`
writes the completion before the first connector is offered, so a denied
permission, a dead network, or a force-quit mid-phase all leave a finished
LifeBoard. Every connector is skippable, and an explicit "Not now" is recorded as
a decision — it suppresses the Home resume card rather than provoking it.

Setup Center is reachable from the Power-Up summary, a Home card shown only for
genuinely *interrupted* setup, and a permanent Settings row; dismissal changes no
connector state. There is no closing phase and **no root tour**.

The modules screen is gone. What Home contains is derived from the intent and the
chosen areas rather than asked for, so removing the question does not mean every
user gets the same Home.

An interrupted v5 journey is migrated rather than restarted: intent, friction,
areas and their order, day shape, a reviewed capture, permission outcomes, and
the commit phase all carry across. The v5 snapshot is left in place so turning
the flag back off resumes rather than restarts. Migration resumes at the screen
that now owns each question, which is never later than the person reached.

### Retired v5 migration

V5 UI, connector steps, and root tour are retired. Persisted intent, friction,
area order, day shape, reviewed capture, and commit progress migrate to their v6
owners. Migration does not reactivate permissions or EVA.

### What both guarantee

Each step has one primary action. Core completion never depends on permission,
model download, network access, or sample data — which is precisely why Setup
Center and EVA activation are outside the core lifecycle. The
commit upserts canonical life areas and their order, working hours, and Home
layout, stores only goal/friction as small profile metadata, then writes the
reviewed capture last; it is phase-tracked, so a failure resumes rather than
replays. Completion is recorded only after required writes succeed. No starter
projects, chores, habits, tasks, or fabricated activity are installed, and a
skipped capture is reported as an honest empty state rather than dressed up.

Completed users remain completed and receive one prefilled refresh invitation
after Home settles for each signed refresh version. **Not now** suppresses
future automatic prompts for that version; Settings replay remains available.
The merge preserves every existing record and customized Home layout.

## EVA activation and model setup

EVA has no separate first-run flow. Its former five-stage journey — meet EVA,
working style, goals, cloud setup, first chat — is retired; opening the EVA tab
lands directly in chat. Any of those stages left persisted by an interrupted
update normalises to completed rather than stranding the person on a screen that
no longer leads anywhere. EVA's profile is derived from the Life Map instead of
re-asked, carrying the person's literal wording alongside the structured
mapping. Offline model installation keeps its own entry point in Settings.

- Setup Center presents one standard Sign in with Apple control, then compactly progresses account exchange, Apple 18+ eligibility, device trust, signed configuration, and credits.
- Journal, Health, Life Moments, and personal-memory grants are preselected after sign-in but individually editable before one explicit compare-and-swap confirmation.
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
| Resumed onboarding | Restore the exact schema-9 lifecycle/step or migrate a v5/v8 draft |
| Permission denied | Explain limitation, preserve remaining functionality, link to Settings |
| Calendar granted, none selected | Represent none selected; never reinterpret an empty selection as all calendars |
| Health request presented | Say access was requested; infer neither read grant nor read denial from the sheet |
| Health write access | Show an authorized count or per-category status independently of read availability |
| EVA deferred or declined | Record the choice, stage the opening prompts anyway, and let the EVA tab offer connection inline |
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
