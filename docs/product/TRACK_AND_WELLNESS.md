# Track, Habits, Care, and Wellness

**Classification:** Canonical feature contract

**Root:** Track
**Related:** [Habit package](../habits/README.md), [Adaptive Home](./HOME.md), [System surfaces](./SYSTEM_SURFACES_AND_CONTINUITY.md)

## Promise and user jobs

Track helps a person sustain routines, record meaningful evidence, and understand care or wellness activity without turning incomplete data into judgment. It combines habits, routines, goals, generic trackers, care, Wellness, Nutrition, Fasting, and Life Moments behind one coherent Today-first surface.

Users come to Track to:

- record something quickly and correct it later;
- see what is due, active, or recently completed;
- manage habit resilience and routine execution;
- inspect history and trends with text equivalents;
- distinguish manual records from connected-health projections;
- add a useful domain card to Home;
- export or delete their own data deliberately.

## Information architecture

Track leads with Today, followed by enabled domain summaries and routes to native histories/details. Domain modules retain stable identities and canonical repositories; Home cards and system surfaces are projections, not secondary stores.

### Habits and resilience

Habits use canonical occurrences and schedules. The Habit Board is the primary streak surface. Paused/archived habits retain history but leave active projections. Recovery labels the intended missed occurrence and must not replay completion or rewards incorrectly. See the [Habit product contract](../habits/product-feature.md).

### Routines

Routines are versioned definitions with immutable run snapshots. Linked task/habit actions pass through canonical mutations once. Active runs prevent destructive definition changes that would make the run uninterpretable.

### Goals

Goals use typed samples and explainable progress. A target, current value, and source must be clear; an absent sample is not zero. Home projections remain compact and route back to the canonical goal.

### Generic trackers and care

Trackers support create, edit, archive, delete, schedules, reminders, quick capture, history, and correction. Care modules use privacy-sensitive language and never infer adherence from missing evidence. Medication events, mood, energy, hydration, and related entries clearly state source and time.

### Wellness

Wellness includes typed body metrics, workouts, sleep, movement, canonical units, source identity, timezone, correction, search, export, and deletion. Connected-health projections are permission-gated and never overwrite manual records.

### Nutrition

Nutrition is local-first. Food/library search, serving conversion, meal timeline, manual/voice/barcode review, reports, recents, and delete/Undo use immutable historical macro snapshots. Remote lookup remains explicitly opt-in when available. Barcode or voice recognition produces a reviewable draft, never a silent committed meal.

### Fasting

Fasting has one serialized active lifecycle. Start, finish, cancel, and keep-running have distinct meanings. Target, elapsed time, reminders, early completion, correction, and duplicate-active recovery remain explicit. History retains the meaning recorded at completion.

### Life Moments

Life Moments record important dates or events with captured timezone, recurrence, search, archive, export, and explicit Home consent. They are personal context, not engagement prompts; suggestions must be explainable and removable.

## Shared capture and mutation contract

- Every committed value records time, source, and unit/meaning needed for later interpretation.
- Recognition/import workflows stop at review until the user saves.
- Corrections preserve stable identity and indicate correction time where the model supports it.
- Delete explains dependent records, history, and projection effects; Undo restores in place where supported.
- Add to Home handles singleton cards predictably and provides a receipt/Undo.
- Permission or integration failure does not block manual/local recording.

## State matrix

| State | Required behavior |
|---|---|
| Populated | Today-first actions, then history/trend and management |
| No records | Explain what recording enables and show one capture action |
| Explicit zero | Display zero with unit and timestamp/source |
| Setup required | Explain target/schedule/source needed before interpreting status |
| Permission denied | Keep manual data available and expose Settings path |
| Connected source unavailable | Label source failure; do not erase manual records |
| Loading | Preserve summary geometry and keep capture available when safe |
| Outlier | Ask for confirmation without diagnosing |
| Duplicate active state | Resolve deterministically and explain the retained record |
| Error | Preserve draft/input and provide retry or correction |

## UI/UX contract

- Today actions precede charts and management.
- Each metric shows value, unit, timeframe, and source; color alone never indicates “good” or “bad.”
- Charts include readable axes and a table/text equivalent.
- Use compact clay tiles for related signals, open rows for history, and one primary capture action.
- Health and care language is descriptive and non-clinical.
- Fasting may use the approved ember effect; other domains do not invent decorative tracker animations.

## Responsive, accessibility, and privacy

- Dynamic Type stacks value/unit/source and moves chart details into accessible lists.
- VoiceOver labels include domain, value, unit, time, and source; controls announce resulting state.
- iPad can use multi-column summary/history layouts without compressing data labels.
- Catalyst offers keyboard-accessible forms and tables where supported.
- Health, care, nutrition, and private life context are redacted from external surfaces unless an explicit product projection permits a safe summary.

## Implementation and evidence

Primary anchors include Phase II Track/Journal views, Phase IV Track Foundation views/models, Phase VI Wellness/Nutrition/Life Moments models and persistence, Home provider registries, and system-surface projection contracts.

Primary flags are `trackFoundationsV2Enabled`, `habitResilienceV2Enabled`, `goalsRoutinesV1Enabled`, `careModulesV2Enabled`, `starterPacksV1Enabled`, `trackersV1Enabled`, `wellnessCoreV1Enabled`, `healthIntegrationsV1Enabled`, `nutritionV1Enabled`, `fastingV2Enabled`, and `lifeMomentsV1Enabled`. Turning a domain off removes its staged surfaces and projections without deleting records.

Recorded evidence covers canonical occurrence/recovery, typed samples, routine idempotency, tracker CRUD/history, Wellness repository paths, fasting serialization, Nutrition conversion/snapshots, Life Moments recurrence, and redacted projections. Signed-device connected-health, notification, export/restore, and full cross-module visual matrices remain release gates.
