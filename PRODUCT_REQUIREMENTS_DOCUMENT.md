# LifeBoard LifeOS Product Requirements

**Classification:** Canonical product requirements
**Audience:** Product, design, engineering, QA, support, privacy, and release teams
**Capability status:** Current product requirements; future requirements are isolated in the [LifeOS blueprint](docs/product/LIFEOS_FUTURE_BLUEPRINT.md)
**Source authority:** Current workspace, [product handbook](docs/product/README.md), and [completion status](docs/life-os/LIFEBOARD_UNIFIED_COMPLETION_STATUS.md)
**Last verified:** 2026-08-13

## Vision

LifeBoard is a personal operating system for the work, care, routines,
knowledge, and decisions that make up a life. It helps people translate what
they care about into a realistic day, act without losing context, recover after
interruption, and learn from their own evidence without shame or opaque scoring.

LifeBoard is not a clinical treatment, financial adviser, autonomous scheduler,
or employee-monitoring system. It is a local-first planning and life-management
product with explicit boundaries around consequential actions.

## Product promise

The concise public promise is **“One place to run the life you actually have.”**
It expresses the same contract as the requirements below: continuity across life
domains, realistic capacity, recovery, reflection, and user-controlled adaptation.
All external descriptions are gated by the [Public Capability Matrix](docs/product/PUBLIC_CAPABILITY_MATRIX.md).

LifeBoard must help a person:

1. understand what matters now;
2. capture new input before it disappears;
3. organize responsibilities by the part of life they serve;
4. place flexible work around fixed reality and available capacity;
5. focus, track, and record without unnecessary setup;
6. recover when plans, energy, or circumstances change;
7. reflect from evidence rather than memory alone;
8. adapt the system deliberately and reversibly.

The mental loop is:

`orient → capture → organize → plan → focus or track → recover → reflect → adapt`

## Target users and jobs

### People carrying high context load

- “Show me what deserves attention without making me reconcile five apps.”
- “Keep work, home, health, and personal responsibilities separate but connected.”
- “Help me return to the right context after an interruption.”

### People with executive-function friction

- “Make starting smaller than avoiding.”
- “Reduce the number of decisions visible at once.”
- “Help me recover from a missed day without punishment.”

### Builders, students, and project-oriented users

- “Turn outcomes into projects, tasks, time, and focused sessions.”
- “Make deadlines, capacity, blockers, and follow-ups visible.”
- “Let notes and decisions remain connected to the work.”

### People managing health and care routines

- “Let me record and correct useful signals without implying a diagnosis.”
- “Combine manual evidence with authorized Apple Health context.”
- “Keep missing data, zero, permission denial, and sync failure distinct.”

### People with changing energy or burnout risk

- “Give me a Low Energy mode and a Minimum Viable Day.”
- “Let the day close without turning unfinished work into guilt.”
- “Protect rest and open time instead of filling every gap.”

## Experience principles

### Context before commands

Home must establish day, capacity, fixed commitments, active sessions, and the
small number of signals that change the next decision.

### Capacity before ambition

Planning must distinguish due date, intended planning day, fixed calendar time,
internal time blocks, estimates, working hours, and open capacity. Moving work
to a day must never silently rewrite its true deadline.

### Recovery is part of the system

Overdue Rescue, Day Repair, Minimum Viable Day, cancellation recovery, durable
drafts, and Undo are primary product paths—not exceptional error handling.

### Evidence before judgment

Insights must disclose source, timeframe, freshness, and limitations. The app
must not imply causation, diagnosis, adherence, or moral value from incomplete
records.

### Proposals before consequential actions

EVA may answer, clarify, or prepare a proposal. Meaningful mutations require an
explicit Apply boundary, current-state validation, a result, and Undo when the
operation is reversible.

### One canonical system

Home cards, widgets, Watch, Spotlight, notifications, EVA, and integrations are
projections and entry points. They do not become parallel task, habit, journal,
health, or planning stores.

## Product architecture

### Five persistent roots

| Root | Responsibility | Required retained context |
|---|---|---|
| Home | Orientation, current focus, timeline, signals, Daily Loop, recovery | Selected day, scroll position, card layout, active sheet intent |
| Plan | Inbox, Day, Week, Backlog, capacity, Focus, review | Selected lens/day, filters, navigation stack, active session |
| Track | Today, life areas, history, habits, routines, goals, care, wellness | Selected lens/domain, drafts, filters, navigation stack |
| Insights | Overview, trends, review, experience, evidence | Selected lens/timeframe and evidence destination |
| EVA | Conversation, day overview, proposals, model/runtime state | Thread, draft, run identity, context grants, proposal state |

Each root owns an independent typed navigation stack. Root switching preserves
visited product roots; EVA may be reconstructed when inactive to release
visibility-scoped model work.

### Life organization model

LifeBoard organizes finite and recurring work through:

`life area → project or goal → task, habit, or routine → placement → evidence`

Life areas are user-controlled. The starter catalog includes Work & Career,
Life Admin, Health & Self, Relationships, Learning & Growth, Creativity & Fun,
and Money. Templates are starting points, not a fixed taxonomy.

### State vocabulary

| State | Requirement |
|---|---|
| Populated | Put the current decision before secondary detail |
| Empty | Confirm the query succeeded and offer one relevant next step |
| Loading | Preserve expected geometry and keep unrelated navigation usable |
| Stale | Show freshness and a refresh/retry path |
| Partial | Show available evidence and name what is missing |
| Denied | Explain the lost capability without blocking local alternatives |
| Locked | Reveal no protected content or derived preview |
| Offline | Preserve local work and identify what will retry |
| Error | Localize failure, preserve input, and provide recovery |
| Destructive | Confirm exact scope and restoration/Undo behavior |

An explicit zero is a recorded value. It must not render as missing.

## Current product requirements

### Onboarding and Life Management

- Onboarding must progress through Welcome, Intent, Life Areas, Guide, Day
  Shape, Modules, First Win, Permissions, and Success.
- Progress and recoverable choices must survive interruption.
- Starter content must be installed through canonical repositories and avoid
  duplicate creation on retry.
- Users must be able to create, edit, move, archive, and delete life areas and
  projects later through Life Management.
- Destructive life-structure changes must explain affected projects, tasks,
  habits, and retained history before confirmation.
- Optional EVA setup and permissions must never block the ordinary app.

### Home and Daily Loop

- Home must answer “what matters now?” through one dominant Focus Now decision,
  a bounded set of honest signals, work/care context, and the shape of the day.
- Smart, Work, Personal, and Low Energy modes change inclusion and density
  without creating separate persisted dashboards.
- Home must support task and habit action, routines, care, capacity, timeline,
  journal/reflection, Life Snapshot, quick capture, and user-selected cards.
- Layout editing is transactional. Cancel restores the prior layout; commit
  persists one ordered placement set; unknown cards survive migration.
- Smart Slots must respect persistent Hide Today, Suggest Less, Never, and Keep
  feedback and must not displace required orientation content.
- The Daily Loop stages are Commit, Act, Repair, Close, and Rest. Applied
  receipts, not presentation-only preferences, determine whether a day was
  opened or closed.
- Day Close reconciles unfinished work, captures an optional reflection line,
  and identifies tomorrow’s first action as one receipt-backed act.
- Rest asks for nothing further.

### Universal Input and Capture

- Universal Capture supports task, habit, journal, note, tracker entry, mood and
  energy, hydration, medication event, routine run, and time block.
- Typed and dictated input use one arbitration pipeline: commands, task parser,
  deterministic language patterns, bounded semantic classifier, then EVA.
- Semantic output maps only to allow-listed native actions and cannot execute
  arbitrary routes or code.
- Classification does not save. A native editor or explicit confirmation is the
  commit boundary.
- Drafts must survive clarification, permission failure, recoverable
  presentation changes, and background interruption where supported.
- Speech and inference stay on-device on the current local path.

### Tasks, Inbox, and Projects

- Tasks support title, notes, priority, energy, category/context, estimate,
  project, life area, section, tags, due date, planned day, scheduled time,
  recurrence, reminders, subtasks, dependencies, completion, and history.
- Creation is fast by default; secondary planning detail remains available
  without overwhelming the initial capture.
- Inbox triage commits each accepted result through canonical task/planning
  mutations and preserves unresolved drafts.
- Project detail provides list and board modes over the same canonical tasks.
- Projects support hierarchy, sections, templates, statistics, move, archive,
  and confirmed deletion.
- Completion, reschedule, edit, and delete failures must preserve the affected
  task identity and current user input.

### Plan, Week, Focus, and recovery

- Plan owns Inbox, Day, Week, and Backlog lenses.
- Day supports Timeline and Agenda presentations, time-of-day grouping, working
  hours, fixed calendar commitments, internal time blocks, unplaced work,
  capacity, conflict repair, and Focus setup.
- Backlog supports search plus context, readiness, energy, duration, and project
  filters, multi-selection, scheduling, Focus, archive/delete, and Undo.
- The current This Week workspace replaces the retired four-step wizard.
  Persisted legacy routes must restore into the workspace.
- Week and overdue entry modes use Overdue, Inbox, and Anytime source lanes.
  Near days are concrete; later days remain a softer horizon until expanded.
- Each accepted day placement writes planning metadata immediately, preserves
  due dates, clears incompatible unscheduled disposition, and produces a receipt.
- Capacity must have a non-color textual equivalent and distinguish no working
  hours from empty capacity.
- Focus supports exact-task and unscoped sessions, duration setup, pause/resume,
  phase advance, interruption reason, outcomes, reflection, startup repair,
  notifications, deep links, and Live Activity state.
- Overdue Rescue supports Keep, Move, Edit, and Delete through both gestures and
  visible accessible controls. Failure does not advance the deck.

### Habits, goals, routines, trackers, and care

- Habits support schedule/cadence, target semantics, reminders, Board and detail
  history, completion/count/quantity outcomes, corrections, pause, archive,
  recovery, and resilient streak presentation.
- Recovery must target the intended missed occurrence and must not duplicate
  rewards or completion.
- Quiet Tracking provides a low-friction multi-habit recording surface.
- Goals use typed samples and may link to projects, tasks, habits, routines, or
  tracker measures. Missing samples are not zero.
- Routines use versioned definitions and immutable run snapshots. Steps may be
  task, habit, check-in, timer, instruction, or choice, including validated
  branches. Linked mutations execute at most once.
- Trackers, hydration, mood/energy, and medication events record time, source,
  unit or meaning, and correction state.
- Starter packs install coherent goal/habit/routine/reminder groups
  idempotently and report partial or unavailable outcomes honestly.

### Health, wellness, nutrition, fasting, and Life Moments

- Health domains are Activity, Energy, Hydration, Nutrition, Body, Workouts,
  Sleep, and Fasting context.
- Activity, energy, sleep, and fasting are read-only/local-canonical. Hydration,
  nutrition, body measurements, and user-authored workouts support write-back
  when the separate write gate and Health authorization permit it.
- Manual records remain usable without Health authorization.
- Sync must preserve source identity, timezone, anchors, deduplication, outbox
  retry, correction, protected-data state, and per-domain freshness.
- Nutrition supports bundled/user foods, serving conversion, recipes, meal
  templates, meal timeline, immutable macro snapshots, goals, recents, reports,
  local barcode lookup, explicitly requested remote lookup, duplicate review,
  deletion, and Undo.
- Fasting has one serialized active lifecycle with start, finish, cancel,
  keep-running, target, reminders, early-completion meaning, correction, and
  deterministic duplicate-active repair.
- Life Moments support countdown, anniversary, milestone, and recurring
  meaningful-event types; captured timezone; recurrence; search; archive; Home
  consent; and redacted external projections.

### Journal, Notes, Knowledge, and reflection

- Journal supports day-based text, mood/energy, audio, on-device transcription,
  document scanning, file/photo attachment, review before save, search,
  semantic evidence, weekly reflection, and durable attachment recovery.
- Protected Journal routes authenticate before mounting content. App-switcher,
  widgets, Spotlight, notifications, Watch, logs, and diagnostics must not reveal
  protected text or media.
- Notes and Knowledge support spaces, folders, tags, smart collections, sort,
  pin/favorite, templates, TextKit editing, block/note links, attachments,
  scanning/import, indexed search, secure notes, biometric unlock, trash,
  restoration, permanent deletion, batch actions, and EVA assistance.
- Canonical deletion must invalidate derived indexes and prevent late re-ingest.

### Insights, gamification, and EVA

- Insights owns Overview, Trends, Review, and Experience lenses and must expose
  timeframe, source, freshness, and supporting evidence.
- Charts require a textual or tabular equivalent. Insufficient evidence must be
  stated rather than filled with a generated claim.
- Gamification uses idempotent XP events, levels, achievements, and bounded
  celebrations. It must reinforce meaningful progress without punishing missed
  days or encouraging unsafe health behavior.
- EVA supports activation/model setup, personas, chats, threads, prompt chips,
  slash commands, context attachments, day overviews, task/habit quick actions,
  semantic retrieval, personal memory controls, truthful working states,
  streaming, Stop, Continue, Retry, proposal diffs, Apply/Edit/Not Now, results,
  receipts, and Undo.
- A turn ends in persisted text, persisted proposal, explicit cancellation, or
  explicit failure/drop. Stale output must not appear in a later run.
- External calendar content remains read-only. EVA may propose changes only to
  LifeBoard-owned state.

### Settings and Apple-platform continuity

- Settings groups Plan & Organize, Calendar & Health, EVA, Reminders, Look &
  Feel, Data & Help, Life Management, model/chat controls, Recovery, and notices.
- System surfaces consume versioned redacted projections or invoke canonical App
  Intents; they never open app persistence directly.
- Supported surfaces include task/timeline/calendar/domain widgets, capture
  control, habit resilience, Focus seed, Focus/Fasting/Routine Live Activities,
  Siri/App Shortcuts, Spotlight, notifications, deep links, share extension,
  Watch capture, and Watch timeline/meeting/habit complications.
- Duplicate delivery is idempotent. Missing, stale, locked, incompatible, and
  offline projection states fail safely.

## Accessibility, performance, privacy, and safety

### Accessibility

- All icon-only controls use meaningful labels and at least 44-point targets.
- VoiceOver order follows title/state, primary action, supporting evidence, then
  secondary controls.
- Gestures, drag/drop, charts, color, and motion always have non-gesture,
  non-color, static, and textual equivalents.
- Dynamic Type preserves primary actions and meaning before decoration.
- Reduce Motion, Reduce Transparency, Increase Contrast, Differentiate Without
  Color, keyboard, pointer, Voice Control, and Switch Control are product modes.

### Performance

- Home and the persistent composer must avoid waking every retained feature at
  launch.
- Root changes preserve context without rebuilding heavy visited roots; EVA may
  release visibility-scoped model work.
- Large lists use bounded projections, lazy presentation, and stable identity.
- Model prewarm, atmospheric rendering, signature effects, and background sync
  obey energy, thermal, scene, and accessibility policy.

### Privacy and safety

- `privateSensitive`: Journal and media, health/biometric values, protected
  reflections, embeddings/semantic chunks, secure-note payloads, and auth state.
- `privateStandard`: tasks, plans, projects, habits, routines, goals, notes, and
  ordinary tracker records.
- External projections are explicit allow-lists with schema, freshness,
  sensitivity, and authorization.
- Health language remains non-clinical; financial direction remains
  non-advisory; shared-data design remains consent-first.
- Logs contain typed operations, counts, timing, and non-content identifiers—not
  private text or measurements.

## Success measures

### Activation and system setup

- completion and resumption rate by onboarding step;
- time to first canonical task and habit;
- percentage of activated users with at least one life area and useful day shape;
- permission acceptance measured without repeated prompting pressure.

### Daily operation

- time from launch to first meaningful action;
- percentage of active days with a deliberate Focus Now choice;
- capture-to-reviewed-commit rate by capture kind;
- day-open, repair, and day-close use without measuring Rest as failure.

### Planning and recovery

- planned work that fits known capacity;
- backlog items placed, clarified, deferred, or deliberately released;
- overdue/rescue sessions ending in an explicit decision;
- successful receipt-backed Undo and recovery after mutation failure.

### Systems and health

- habit/routine restart after a miss or interruption;
- corrections completed without duplicate evidence;
- Health sync freshness and outbox recovery by domain;
- manual recording retained after permission denial or integration failure.

### Trust and assistance

- clarification versus false-action rate for Universal Input;
- EVA proposal acceptance, edit, Not Now, failure, and Undo rates;
- percentage of insight claims opened to evidence;
- cancellation/retry success and absence of stale response delivery.

Metrics are local and privacy-preserving by default. They must not optimize for
compulsive engagement, health pressure, or unnecessary notification volume.

## Release and evidence policy

- **Implemented in source** means a current route/model/workflow exists.
- **Verified by automated evidence** means the named current test/build passed.
- **Device validation required** means source exists but signed hardware,
  accounts, permissions, delivery, performance, or visual observation is open.
- **Blueprint** means not current product behavior.

The [completion status](docs/life-os/LIFEBOARD_UNIFIED_COMPLETION_STATUS.md) is
the sole current evidence ledger. Exact counts and build claims must appear only
there and only with a dated command result.

## Current non-goals

- autonomous mutation without review;
- editing or RSVPing to external calendar events;
- diagnosis, treatment, adherence inference, or emergency medical use;
- bank/account aggregation or financial advice in the current product;
- full collaborative household/team planning in the current product;
- interpreting missing evidence as failure;
- filling every free window or rewarding volume at the expense of meaning.

The complete future direction for long-horizon planning, work coordination,
home administration, care, relationships, money, learning, creativity,
collaboration, data ownership, and EVA evolution is maintained separately in
the [Future LifeOS Blueprint](docs/product/LIFEOS_FUTURE_BLUEPRINT.md).

## Acceptance

The product documentation and implementation are aligned when a reader can:

1. map every reachable feature to an owning root and canonical data path;
2. distinguish current, partially verified, device-gated, and blueprint behavior;
3. complete the key user journeys in the [operating guides](docs/guides/README.md);
4. understand privacy, permission, recovery, destructive, and Undo behavior
   before relying on a feature;
5. verify each current claim through source, tests, or a named evidence gap.
