# LifeBoard LifeOS Feature Catalog

> Classification: Canonical current-feature reference
> Audience: Users, support, product, design, engineering, and QA
> Capability status: Current workspace; limitations are called out per entry
> Source authority: Runtime routes, models, repositories, feature flags, targets, and system extensions
> Last verified: 2026-08-24

This catalog accounts for the current user-visible product. “Current” means represented in this workspace; it does not by itself mean freshly exercised on a device. The [future blueprint](./LIFEOS_FUTURE_BLUEPRINT.md) is intentionally excluded. Public language, platform qualifiers, and screenshot use are separately gated by the [Public Capability Matrix](./PUBLIC_CAPABILITY_MATRIX.md).

## Reading an entry

Each feature names its outcome, entry points, authority, actions and recovery, integrations, privacy, states, accessibility/platform behavior, and known constraints. All features inherit the shared state and trust contract in the [handbook](./README.md).

Stable public identifiers live in the capability matrix so product chapters can
remain exhaustive while public surfaces stay precise. A website chapter must
link back to the corresponding catalog anchor and must not promote a future or
device-unverified behavior into an unqualified promise.

## 1. Life structure and onboarding

### Guided onboarding and starter workspaces

- **Outcome and use:** Build a useful system without configuring every module. The flow covers Welcome, intent/friction profile, life areas, guide/persona, day shape, optional modules, a first win, contextual permissions, and success.
- **Entry points/status:** First launch; resumable onboarding state. Current, with optional paths controlled by available modules and permissions.
- **Authority:** Onboarding persistence plus canonical area, project, task, habit, routine, goal, and settings repositories. Starter packs install real records, not demo-only copies.
- **Actions/Undo:** Select or create Work & Career, Life Admin, Health & Self, Relationships, Learning & Growth, Creativity & Fun, and Money; install starter structures; create a first task; choose day shape and EVA guide. Skips are explicit. Installation must compensate or expose reversible cleanup if a multi-record operation fails.
- **Integrations/privacy:** Permission prompts are just-in-time. Personal structure is `privateStandard`; health choices remain `privateSensitive` once data is connected.
- **States/accessibility:** Progress survives interruption. Unavailable modules are explained rather than blocking setup. Each screen has one primary action, readable Dynamic Type flow, VoiceOver order, and non-color selection state.
- **Limitations/evidence:** Starter content and permission availability vary by platform capability. See `OnboardingStep`, onboarding stores, starter-area definitions, and [Onboarding and Settings](./ONBOARDING_SETTINGS_AND_RECOVERY.md).

### Life Management, areas, projects, sections, and tags

- **Outcome and use:** Restructure responsibilities after onboarding without losing historical evidence.
- **Entry points/status:** Settings → Life Management, project screens, task editors, and organization pickers. Current.
- **Authority:** Canonical life-area, project, section, tag, and task relationships.
- **Actions/Undo:** Create/edit/reorder areas; create nested projects; add sections/tags; move projects between areas; archive or delete with a consequence preview. Archiving preserves history. Deletion must state treatment of descendants and linked records; supported reversible actions produce Undo.
- **Integrations/privacy:** Reflected in Home, Plan, Insights, EVA context, widgets only where safe. `privateStandard`.
- **States/accessibility:** Empty areas suggest a project or goal; missing/deleted parents must not substitute unrelated entities. Tree depth, disclosure controls, drag alternatives, keyboard/pointer support, and VoiceOver hierarchy remain usable.
- **Limitations/evidence:** Collaboration and shared ownership are not current capabilities. See project stores, project routes, and Life Management settings.

## 2. Home and the Daily Loop

### Adaptive Home

- **Outcome and use:** Orient to the day and act without reconciling separate task, calendar, health, and tracking screens.
- **Entry points/status:** Default Home root, deep links, widget continuation, notifications, and root reselection. Current and canonical.
- **Authority:** A projection assembled from canonical tasks, plans, calendar, habits, routines, care, health, nutrition, fasting, goals, moments, and journal evidence.
- **Actions/Undo:** Change Smart/Work/Personal/Low Energy mode and atmosphere; open Focus Now; complete supported rows; capture; replan; customize cards; change size and placement; Add to Home. Mutations pass to source repositories and expose Undo where supported.
- **Integrations/privacy:** Calendar and Health are permission-gated. External surfaces receive redacted projections only. Home consent is required for sensitive optional cards.
- **States/accessibility:** Per-card empty/loading/stale/denied/offline/error states do not blank the whole dashboard. Wide layouts use adaptive columns; compact and accessibility sizes stack in meaning order. Reduce Motion/Transparency and VoiceOver are supported.
- **Limitations/evidence:** Card availability depends on module flags, consent, records, and permissions. See [Home](./HOME.md) and `HomeLifeOSProjectionStore`.

### Home cards and customization

- **Outcome and use:** Build a small dashboard for the current season rather than expose every module.
- **Current card kinds:** Setup Checklist, Focus Now, Life Snapshot, Care, Tasks, Routines, Schedule Capacity, Quick Capture, Compact Timeline, Journal, Progress Reflection, Fasting, Goals, EVA Conversation, Body Metric, Workout, Sleep, Movement, Life Moment, Nutrition Summary, Recent Meal, and Log Meal.
- **Authority/actions:** Layout preferences own visibility, size, and placement; each card reads its domain authority. Smart Slots may recommend placement but do not silently pin or mutate records.
- **Privacy/states:** Sensitive cards require consent and safe previews. An unavailable source explains the missing permission or data. Removing a card removes only the projection, never its domain records.
- **Accessibility/platform:** Reordering has non-drag alternatives; cards preserve semantic headings and minimum targets across iPhone, iPad, and Catalyst.
- **Evidence:** Home card kind definitions, dashboard customization store, and [Home](./HOME.md).

### Daily Loop: Commit, Act, Repair, Close, Rest

- **Outcome and use:** Move through the day with explicit recovery rather than punish deviation.
- **Entry points/status:** Home, Day, Day Open, Day Close, rescue decks, notifications, and deep links. Current.
- **Authority/actions:** Commit chooses a realistic day; Act runs tasks/routines/Focus; Repair offers Replan, Minimum Viable Day, and Overdue Rescue; Close records outcomes and carry-forwards; Rest reduces pressure and supports tomorrow. Planning receipts preserve what changed and enable supported Undo.
- **States:** Empty days offer capture or intentional rest. Overload is a capacity state, not failure. Interrupted flows resume; stale projections refresh; failed batch changes preserve original placement.
- **Accessibility/platform:** Stage meaning is available in text, not color or animation alone. Morning/evening experiences remain usable with reduced motion and large text.
- **Evidence:** Daily-loop domain/state machines, day-open/day-close routes, rescue stores, and [Running Your Day](../guides/RUNNING_YOUR_DAY.md).

## 3. Capture, tasks, and organization

### Universal Capture

- **Outcome and use:** Capture before deciding where information belongs.
- **Kinds/status:** Task, Habit, Journal, Note, Tracker Entry, Mood and Energy, Hydration, Medication Event, Routine Run, and Time Block. Current availability can vary by enabled module.
- **Entry points:** Persistent composer, capture sheet, Home, widgets/control, App Intents/Siri, Spotlight, share extension, Watch, EVA, and deep links.
- **Authority/actions:** A router deduplicates and queues presentation; the destination editor remains the save boundary. Deterministic slash/command handling, structured natural-language parsing, semantic classification, live dictation, clarification, editor review, and EVA fallback preserve the draft. Classification alone never commits.
- **Privacy/states:** Drafts inherit destination privacy. Denied microphone/speech, missing model, offline remote lookup, ambiguity, or presentation interruption retains editable input.
- **Accessibility/platform:** Dictation has visible/text status and Stop; controls have labels and 44-point targets; keyboard submission and cancellation work on iPad/Catalyst.
- **Evidence:** `CaptureKind`, capture coordinator, Life Thread adapters, and [Universal Input](./UNIVERSAL_INPUT.md).

### Tasks, subtasks, recurrence, and dependencies

- **Outcome and use:** Turn a responsibility into a concrete, schedulable action.
- **Entry points/status:** Capture, Inbox, Day/Week/Backlog, Home, project, search, widgets, Siri, EVA, and linked goals/routines. Current; some fields appear progressively.
- **Authority:** Canonical task repository and planning metadata.
- **Actions/Undo:** Edit title, notes, priority, energy, context, duration, project, life area, section, tags, dates, planned day/time, recurrence, reminders, subtasks, and dependencies; complete, reopen, reschedule, defer, archive/delete, and triage Inbox. Completion and scheduling mutations are receipt-backed where supported.
- **Integrations/privacy:** Calendar placement may create internal time blocks; Reminders linking retains source identity. Widgets/intents invoke canonical commands. `privateStandard` unless notes contain sensitive material.
- **States/accessibility:** Blocked dependencies, overdue status, recurrence, and completion are announced in text. Missing links do not redirect to a different task. Failed saves retain edits.
- **Limitations/evidence:** External calendar events are never edited as tasks. See task models/stores, task detail route, and [Plan and Focus](./PLAN_AND_FOCUS.md).

### Inbox and task recovery

- **Outcome and use:** Process unorganized captures and repair work that no longer fits.
- **Entry points/status:** Plan → Inbox, weekly workspace lanes, Home repair, and overdue deep links. Current.
- **Authority/actions:** Canonical tasks plus planning receipts. Assign area/project/section/tags, clarify, schedule, batch distribute, defer, complete, or delete. Minimum Viable Day and Overdue Rescue make explicit changes and preserve recoverable failures.
- **States/accessibility:** Zero items is a completed state. Partial batch failure identifies applied and unapplied items. Selection count and overload are announced without relying on color.
- **Evidence:** Plan lenses, weekly workspace, rescue deck, and planning mutation services.

### Projects and views

- **Outcome and use:** Group outcomes and actions at the right level of responsibility.
- **Entry points/status:** Project route, Life Management, task editor, templates, and search. Current.
- **Authority/actions:** Project hierarchy is canonical; list and board are presentations. Create/edit, nest, template, move between life areas, organize sections, archive, and delete with explicit descendant/link consequences.
- **States/accessibility:** Empty projects explain how to add or link work. Board movement has menus/keyboard alternatives. Archived projects retain evidence but leave active selection.
- **Limitations/evidence:** Team/shared projects are future. See project stores and project management views.

## 4. Plan, Week, Focus, and recovery

### Plan lenses and schedule capacity

- **Outcome and use:** Decide what fits around fixed commitments.
- **Entry points/status:** Plan root with Inbox, Day, Week, and Backlog; Day has Timeline and Agenda presentations. Current.
- **Authority:** Tasks and LifeBoard time blocks are writable; calendar events are read-only projections; working hours and anchors come from settings.
- **Actions/Undo:** Navigate days; search/filter; place/move/unschedule; inspect capacity; use readiness, context, energy, duration, and project filters; select and batch mutate; open a daily summary. Receipts describe before/after placement and Undo.
- **States/accessibility:** Permission-denied calendar still permits internal planning. Conflicts, over-capacity, stale calendars, and explicit free time are labeled. Timeline always has an agenda/text equivalent.
- **Evidence:** Plan root/views, Calendar package, and [calendar reference](../calendar/README.md).

### EVA decision loops

- **Outcome and use:** Make an overloaded day honest, change one condition behind repeated task friction, and close the week into a viable next-week shape.
- **Entry points/status:** Make It Fit Today from Plan capacity; Friction Detective from Task Detail; Weekly Reset from the weekly review route. Implemented and enabled by default in Debug and Release; three promoted local flags and three signed runtime controls remain independent kill switches.
- **Authority/actions:** Canonical capacity and repositories supply facts. Every task disposition is previewed; calendar events and deadlines are not edited. Make It Fit and Weekly planning create reversible receipts. Friction Detective restores the original task or removes its created split step and deletes the linked local finding on Undo.
- **Privacy:** Structured `FrictionFinding` records are local-only and contain no custom prose. Optional custom text lives in a linked reflection note. Journal evidence is never sent without a per-ritual explicit grant.
- **States/accessibility:** IDs-only drafts restore by refetching records. Stale previews revalidate, unknown estimates never count as free work, sparse histories remain uncertain, and reduced-motion/VoiceOver/Dynamic Type states preserve meaning.
- **Limitations/evidence:** Local/degraded rituals do not require Cloud EVA. The 100% production cloud policy is prepared but not live while DeviceCheck provisioning and staging verification remain open. See [EVA Decision Loops implementation](../eva/EVA_DECISION_LOOPS_IMPLEMENTATION.md).

### This Week workspace

- **Outcome and use:** Build a concrete near-term week and recover overdue work without a multi-step wizard.
- **Entry points/status:** Week and overdue entry modes; the legacy weekly-planner route resolves into this current workspace. Current.
- **Authority/actions:** Overdue, Inbox, and Anytime source lanes feed Today plus the next two concrete days, with Later This Week as a softer placement. Search, selection, task placement, bulk distribution, intention, meetings, capacity bars, completion, and overloaded-week recovery persist immediately. Receipts support Undo.
- **States/accessibility:** Empty lanes are success, overload is explained, and partial bulk failure retains selection. Compact uses sections; wide layouts may expose more days without changing authority.
- **Limitations/evidence:** Old wizard documentation is retired. See `WeeklyPlanningWorkspaceView` and [weekly guide](../guides/PLANNING_AND_REVIEWING_YOUR_WEEK.md).

### Focus sessions

- **Outcome and use:** Protect attention for scoped work or an unscoped interval, then record what happened.
- **Entry points/status:** Plan, Home Focus Now, task detail, Siri/App Intent, widgets, Live Activity, notifications, and deep links. Current.
- **Authority/actions:** Focus session store owns duration, scope, phase, pause/resume, interruptions, outcome, reflection, and history. Start, pause, resume, finish, abandon with confirmation, and repair an active session after startup. Rewards are applied idempotently.
- **Integrations/privacy:** Notifications and Live Activities show minimal safe context and invoke canonical commands. Task scope is `privateStandard`; reflections may be sensitive.
- **States/accessibility:** Timer state uses text and system time semantics, not animation alone. Interrupted or expired activities reconcile on app activation. Notification denial does not block the timer.
- **Evidence:** Focus session routes/models, ActivityKit surface, and [Plan and Focus](./PLAN_AND_FOCUS.md).

## 5. Track, habits, goals, routines, and care

### Habits and Quiet Tracking

- **Outcome and use:** Sustain behaviors with honest history and low-friction logging.
- **Entry points/status:** Track Today, Habit Board, library, detail calendar, Home, widgets, notifications, capture, and linked goals. Current.
- **Authority/actions:** Habit definitions, schedules, targets, and occurrences are canonical. Create/edit schedules and reminders; log binary, quantity, or count progress; correct dates/values; recover a missed occurrence; pause, archive, or delete. Quiet Tracking records several habits without celebration pressure. Undo reverses supported occurrence mutations.
- **Integrations/privacy:** Safe summaries may project to widgets; Health-derived evidence remains source-labeled and is not silently converted into manual completion.
- **States/accessibility:** Paused/archived/unscheduled states are distinct. Streaks distinguish current, best, resilience/recovery, and insufficient history. Calendar cells expose text equivalents.
- **Limitations/evidence:** Recovery changes an intended occurrence, not history wholesale. See [habit reference](../habits/README.md).

### Goals and progress evidence

- **Outcome and use:** Maintain direction while grounding progress in evidence.
- **Entry points/status:** Track, goal detail, Home, Insights, EVA, and linked entities. Current.
- **Authority/actions:** Goal definitions and typed progress samples are canonical. Link tasks, habits, routines, and trackers; add/correct samples; define milestones; check in; revise target/timeline; complete or archive.
- **States/accessibility:** Trajectory distinguishes on-track/risk/insufficient data without false precision. Charts include textual summaries and sample provenance.
- **Limitations/evidence:** Portfolio planning and yearly/quarterly hierarchy are future. See goal routes/models and Track views.

### Routines and runs

- **Outcome and use:** Execute a repeatable sequence while allowing real-life branches and interruptions.
- **Entry points/status:** Track, routine detail/run, Home, capture, notifications, and linked goals. Current.
- **Authority/actions:** Versioned routine definitions and run snapshots. Ordered and branching steps support task, habit, check-in, timer, instruction, and choice behavior. Pause/resume, interrupt, partially complete, finish, and inspect history. Linked mutations execute once through canonical services.
- **States/accessibility:** Missing linked items are explained and skippable where safe. Active runs survive app interruption. Timers and branch choices have textual state and large controls.
- **Evidence:** Routine models/run store and Track chapter.

### Generic trackers and care

- **Outcome and use:** Record personal measures and care events without manufacturing meaning.
- **Entry points/status:** Track, tracker detail/history, Universal Capture, Home cards, EVA, reminders, and supported intents. Current.
- **Authority/actions:** Generic tracker samples, hydration, mood/energy, and medication/care event stores retain timestamp, unit/value, notes, and source identity. Log, correct, delete, review history, and configure reminders. Explicit zero is preserved.
- **Integrations/privacy:** Health write-back is limited to supported domains and retains provenance. Care and health values are `privateSensitive`.
- **States/accessibility:** Denied Health access leaves manual logging available. Sync pending, stale, partial, and failed outbox states are distinct. Charts provide text/table equivalents.
- **Evidence:** Tracker/care models, Health runtime, and [Track and Wellness](./TRACK_AND_WELLNESS.md).

### Starter packs

- **Outcome and use:** Install a coherent starting system rather than disconnected templates.
- **Authority/actions:** Packs create linked goals, habits, routines, trackers, and reminders through canonical repositories. Users review contents before installation and can later edit/archive records independently.
- **States/limitations:** Partial installation must compensate or identify what succeeded. Packs are personal scaffolding, not clinical programs or financial advice.
- **Evidence:** Starter-pack catalogs/installers and onboarding.

## 6. Health, nutrition, fasting, and Life Moments

### Health connection and synchronization

- **Outcome and use:** Combine Apple Health evidence with manual LifeBoard records while preserving provenance.
- **Domains/status:** Activity/walking distance, active/resting energy, hydration, nutrition/macros, body mass/body fat/waist/resting heart rate, workouts, sleep, and fasting context. Current coverage varies by permission and device data.
- **Authority:** HealthKit remains authoritative for imported samples; LifeBoard owns manual records and an outbox for supported writes. Read-only domains are activity, energy, sleep, and fasting context. Supported write-back domains are hydration, nutrition, body, and workouts.
- **Actions/recovery:** Connect per domain, request permission in context, refresh, inspect source, add manual fallback, correct LifeBoard-owned entries, retry outbox writes, and disconnect projections. Deduplication uses stable provenance; a failed write never masquerades as synced.
- **States/privacy:** Not requested, denied, restricted, protected-data unavailable, stale, partial, unavailable, and retrying are distinct. Health data is `privateSensitive`, minimized in logs/widgets, and protected when the app is locked or backgrounded.
- **Accessibility/platform:** Charts expose values and periods in text. Background observation is opportunistic; foreground refresh remains available.
- **Evidence:** `HealthDomain`, HealthKit type catalog, Health runtime/sync models, and [health guide](../guides/MANAGING_HEALTH_AND_WELLBEING.md).

### Nutrition, recipes, and meals

- **Outcome and use:** Plan or record food with durable nutrition evidence.
- **Entry points/status:** Track → Nutrition, Home cards, capture/EVA proposals, search, meal timeline, and reports. Current.
- **Authority/actions:** Food library, serving definitions/conversions, recipes, meal templates, and meal entries are canonical. Search local first; remote barcode lookup occurs only when explicitly requested. Log/edit/delete meals, resolve duplicates, inspect recent meals/reports/goals, and Undo supported deletion.
- **Data integrity/privacy:** Logged meals keep immutable macro snapshots so later food edits do not rewrite history. Remote requests minimize context; dietary data is sensitive personal data.
- **States/accessibility:** Offline keeps local search/logging. Unknown barcodes and ambiguous duplicates open review. Reports state missing/partial days and provide text values.
- **Evidence:** Nutrition models/stores/views and Home nutrition cards.

### Fasting

- **Outcome and use:** Run a voluntary timer with an explicit target and correctable history.
- **Entry points/status:** Track, Home, widget/Live Activity, Siri/App Intents, notifications, and deep links. Current.
- **Authority/actions:** Fasting session store owns start/end/cancel/keep-running, target duration, early completion, reminder schedule, history, and correction. Startup repair resolves duplicate active sessions.
- **Health/privacy:** Fasting may provide context but is not a clinical recommendation; HealthKit boundaries and source identity are explicit. Sensitive projections are minimized.
- **States/accessibility:** Timer remains useful without notifications or Health permission. Early finish/cancel are distinct and confirmed where loss is possible.
- **Evidence:** Fasting models, intents, widgets, and Track chapter.

### Life Moments and countdowns

- **Outcome and use:** Remember meaningful dates without exposing personal context.
- **Entry points/status:** Track, Home with consent, widgets, search, Siri/App Intent, and detail screens. Current.
- **Authority/actions:** Moment records retain type, date, captured timezone, recurrence, title/context, and archive state. Create/edit/search/archive; countdown displays derive from the captured temporal semantics.
- **Privacy/integrations:** Widget/Home projection is opt-in and redacted. Export must preserve timezone and recurrence. Relationship context is never inferred for public surfaces.
- **States/accessibility:** Past, recurring, undated/invalid, and timezone-transition states are explicit. Countdown meaning is spoken as text.
- **Evidence:** Life Moments models/views, Home card, widget, and countdown intent.

## 7. Journal, Notes, Knowledge, and reflection

### Journal and durable media

- **Outcome and use:** Capture private lived context in text, voice, scans, photos, or files and revisit it safely.
- **Entry points/status:** Journal day/search routes, Home, Universal Capture, Siri/App Intent, Spotlight, Insights, EVA, and weekly reflection. Current; media capabilities depend on permission/device.
- **Authority/actions:** Journal entries and durable attachment records are canonical. Record mood/energy, type/dictate, save original audio, transcribe, scan/import, review before save, edit/search/delete. Deletion propagates to derived indexes and attachments according to the visible consequence.
- **Privacy:** `privateSensitive`; protected routes require app-lock authentication, app-switcher shielding, and privacy-safe deep-link failure. Semantic chunks and embeddings share the classification.
- **States/accessibility:** Original audio remains when transcription fails. Missing attachment, protected file, denied microphone/camera/photos, indexing delay, and locked content are distinct. Editors support Dynamic Type and labeled playback/transcription controls.
- **Evidence:** Journal package/features, protected route handling, and [Journal and Knowledge](./JOURNAL_NOTES_AND_REFLECTION.md).

### Notes and Knowledge

- **Outcome and use:** Keep reference material, working notes, and linked knowledge apart from daily reflection.
- **Entry points/status:** Notes library, note route, Knowledge folders, capture, Spotlight, share/import, Siri, and EVA. Current.
- **Authority/actions:** Note/folder/tag/link/attachment stores. Create/edit with block/TextKit editor, folders and tags; pin/favorite; use templates; link notes; scan/import/attach; sort/search/index; secure with biometric unlock; trash/restore/permanently delete; batch actions.
- **Privacy/states:** Ordinary notes are `privateStandard`; secure notes and derived semantic content are `privateSensitive`. Locked content has no preview. Indexing lag, unavailable attachments, conflicts, empty collections, and trash are explicit.
- **Accessibility/platform:** Keyboard commands, pointer behavior, reading order, scalable editor text, and alternatives to drag/drop support iPad/Catalyst.
- **Evidence:** `KnowledgeStore`, Knowledge routes/views, Knowledge package, and chapter.

### Weekly reflection

- **Outcome and use:** Review what happened, what evidence supports, and what to adjust.
- **Entry points/status:** Weekly Review, Journal, Insights, EVA, and end-of-week prompts. Current.
- **Authority/actions:** Evidence links point to source records; reflection text and decisions are user-owned. Review wins, friction, capacity, habits/goals, health signals, and carry-forward; revise the coming plan through explicit mutations.
- **Safety/states:** Insufficient evidence is stated. Correlation is not causation; health interpretation is non-clinical. Missing or deleted evidence remains a labeled unavailable reference.
- **Evidence:** Weekly reflection/review routes and Insights services.

## 8. Insights, gamification, and EVA

### Insights and evidence disclosure

- **Outcome and use:** Understand productivity, habits, goals, and health trends without false certainty.
- **Entry points/status:** Insights root, reports, weekly review, goal/habit details, and evidence routes. Current.
- **Authority/actions:** Derived analytics retain period, source references, freshness, and calculation semantics. Open evidence, change lens/timeframe, save/dismiss/snooze/follow up where supported.
- **Privacy/safety:** No causal or clinical claims. Sparse data produces “insufficient data,” not a score. Sensitive evidence stays protected.
- **Accessibility/platform:** Every chart has a text/table equivalent; colors are redundant; trend direction and timeframe are announced.
- **Evidence:** Insight routes/services and [Insights and EVA](./INSIGHTS_AND_EVA.md).

### XP, levels, badges, achievements, and streak relationships

- **Outcome and use:** Celebrate meaningful progress without creating pressure.
- **Entry points/status:** Completion celebrations, Insights/profile surfaces, Focus rewards, and widgets where enabled. Current behind promoted/rollback flags in some surfaces.
- **Authority/actions:** An idempotent event/reward ledger prevents duplicate XP or achievements on retry, sync, or repeated projection refresh. Habit streaks remain habit evidence; rewards do not rewrite them.
- **Safety/accessibility:** Celebrations respect reduced motion, quiet modes, and interruption context. No shame, loss framing, coercive streak pressure, or health-based moral score.
- **Evidence:** gamification domain/services, widget projections, and feature flags.

### EVA assistant

- **Outcome and use:** Understand context, explore options, and safely apply reviewed changes.
- **Entry points/status:** EVA root, persistent composer fallback, Home conversation card, selected context attachments, Siri request, and evidence follow-ups. Current in source; Cloud EVA production remains fail-closed while missing DeviceCheck secrets block the prepared staging v3/production v2 promotion.
- **Authority/actions:** Activation selects guide/mascot and Cloud EVA or Offline EVA. The provider router chooses Luna only when account, trust, per-device 18+, consent, credits, network, and signed policy are ready; explicitly selected Offline EVA uses installed MLX. Chats/threads, chips, slash commands, attachments, day overview cards, task/habit actions, semantic retrieval, and user-controlled memory feed a working/streaming response. Stop, Continue, Retry, and edit remain available. Consequential output becomes a proposal with diff, Apply/Edit/Not Now, partial-application disclosure, receipt, and Undo.
- **Privacy:** Context is bounded and category-scoped. Cloud context requires explicit minimization and authoritative consent; Journal, Health, Life Moments, and personal memory are independently off by default. Offline prompts remain on device. Cloud prompts and authorized projections transit LifeBoard's Cloudflare Worker to OpenAI with `store: false`; the Worker retains no conversation/audio history.
- **States/accessibility:** Signing in, device trust, age eligibility, consent, credits, configuration disabled/degraded, downloading, unavailable model, offline, working, streaming, stopped, partial, failed, and stale context are distinct. Text remains selectable/readable and streaming does not steal VoiceOver focus. TTS is optional and independently disableable.
- **Limitations/evidence:** EVA is assistive, not autonomous authority. It cannot bypass canonical validation or approval, silently switch providers mid-request, use cloud speech input, or operate as full duplex. See [EVA architecture](../architecture/LOCAL_LLM_EVA_ARCHITECTURE.md) and [Cloud EVA guide](../eva/CLOUD_EVA_PRODUCT_AND_TECHNICAL_GUIDE.md).

## 9. Settings, continuity, and Apple platforms

### Settings and recovery

- **Outcome and use:** Control planning, intelligence, appearance, integrations, privacy, data, and destructive operations.
- **Entry points/status:** Settings and typed detail routes. Current categories: Plan & Organize, Calendar & Health, EVA, Reminders, Look & Feel, Data & Help, Life Management, LLM, Chats, Models, Recovery, and Notices.
- **Authority/actions:** Configure week start, working hours, timeline anchors, calendars, Health, reminders, quiet hours, daily rituals, EVA intelligence/chat/model behavior, appearance/motion/accessibility comfort, organization, data/help, recovery, acknowledgements, export/delete where available.
- **Safety/states:** Destructive actions identify scope and confirmation; settings failures do not erase prior values. Permission rows distinguish app preference from system authorization.
- **Evidence:** `SettingsDetailRoute`, settings views/stores, and [Onboarding and Settings](./ONBOARDING_SETTINGS_AND_RECOVERY.md).

### Persistence, sync, and offline continuity

- **Outcome and use:** Continue locally and understand freshness when cloud or extensions lag.
- **Status/authority:** Local persistence is the immediate authority; CloudKit-backed continuity and system projections operate within their configured containers and schemas. Current, subject to entitlement/account availability.
- **Behavior:** Local mutations remain available offline when safe, then synchronize/retry. Conflicts preserve provenance and surface recoverable choices rather than silently dropping records. Projections use versioned atomic envelopes and freshness timestamps.
- **Privacy/states:** Signed-out, offline, quota, conflict, protected-data unavailable, partial sync, and stale projection are distinct. Diagnostics exclude content.
- **Evidence:** persistence package/adapters, CloudKit configuration, projection stores, and system-surface chapter.

### Reminders, widgets, Live Activities, Siri, Spotlight, and notifications

- **Outcome and use:** Glance, capture, and continue without creating a second data system.
- **Current surfaces:** Apple Reminders linking; task-list, Focus Seed, Streak Resilience, Journal, Fasting, Nutrition, Wellness, Life Moments, Goals, and Routines widgets; capture control; Focus, Fasting, and Routine Live Activities; App Shortcuts/App Intents; Spotlight; notification actions; typed deep links.
- **Authority/actions:** Extensions read redacted projections and dispatch stable commands. Interactive task completion/defer and habit occurrence resolution validate identity and return receipts. Missing or stale targets open a safe app route; they never substitute another record.
- **Privacy/accessibility:** Lock-screen previews minimize content. Widget families have text alternatives and adequate contrast; action labels are explicit.
- **Evidence:** widget bundle, ActivityKit attributes, intent definitions, notification router, Spotlight indexer, and [System Surfaces](./SYSTEM_SURFACES_AND_CONTINUITY.md).

### Share extension, Watch, iPad, and Catalyst

- **Outcome and use:** Capture from another app or device and continue in LifeBoard.
- **Status/actions:** Share extension sends reviewable task/note/journal/file input; Watch supports durable capture/audio outbox plus timeline, meetings, and habit widgets/complications; iPad and Catalyst provide adaptive layouts, keyboard commands, and pointer/menu behavior. Current surface depth varies by target and OS.
- **Authority/recovery:** App-group/outbox records preserve stable identity and retry on the phone. Failed transfer remains visible and retryable. The receiving editor is the final commit boundary where review is required.
- **Privacy:** Projections and transfer payloads are minimized and protected; secure Journal/Notes content does not appear without authorization.
- **Evidence:** extension targets, Watch targets, app-group contracts, and system-surface chapter.

## Exhaustive interface coverage

These tables map every required public navigation or system discriminator to the canonical entry above. They are also checked by the documentation guardrail.

### Roots and routes

| Interface | Values | Catalog owner |
|---|---|---|
| `Destination` | `home`, `plan`, `track`, `insights`, `eva` | Home; Plan; Track; Insights; EVA |
| `AppRoute` | `taskDetail`, `habitBoard`, `habitLibrary`, `habitDetail`, `trackerDetail`, `careLibrary`, `health`, `project`, `routine`, `goal`, `journalDay`, `journalSearch`, `weeklyReflection`, `notesLibrary`, `note`, `knowledgeFolder`, `planDay`, `planWeek`, `backlog`, `focusSession`, `dayClose`, `dayOpen`, `weeklyPlanner`, `weeklyPlanningWorkspace`, `weeklyReview`, `trackHistory`, `wellness`, `nutrition`, `fasting`, `insightEvidence`, `healthInsight`, `settings`, `settingsDetail`, `tokenGallery`, `referenceDashboard` | Relevant feature entry; gallery/dashboard are internal reference destinations |
| `CaptureKind` | `task`, `habit`, `journal`, `note`, `trackerEntry`, `mood`, `hydration`, `medicationEvent`, `routineRun`, `timeBlock` | Universal Capture and destination feature |
| `SettingsDetailRoute` | `planAndOrganize`, `calendarAndHealth`, `eva`, `reminders`, `lookAndFeel`, `dataAndHelp`, `lifeManagement`, `llm`, `chats`, `models`, `recovery`, `notices` | Settings and recovery |
| `HealthDomain` | `activity`, `energy`, `hydration`, `nutrition`, `body`, `workouts`, `sleep`, `fasting` | Health connection and synchronization |

`weeklyPlanner` is a compatibility route only; it opens the current This Week workspace. `tokenGallery` and `referenceDashboard` support internal visual verification and are not primary user workflows.

### App Intents and shortcuts

| Current intent | User result |
|---|---|
| `AddTaskIntent` | Opens or commits the supported task capture path |
| `OpenEvaChatIntent`, `RequestLLMIntent` | Opens EVA or submits a supported assistant request with consent boundaries |
| `StartFocusSessionIntent` | Starts/opens a canonical Focus session |
| `QuickJournalCaptureIntent` | Opens protected quick Journal capture |
| `QuickNoteCaptureIntent`, `CreateNoteIntent`, `OpenNoteIntent`, `SearchNotesIntent` | Capture, create, open, or search Notes |
| `LogWaterIntent`, `LogWeightIntent`, `LogBodyMetricIntent` | Record supported, source-labeled wellness values |
| `StartFastingTimerIntent`, `EndFastingTimerIntent` | Start or finish a canonical fast |
| `CreateCountdownIntent` | Create a Life Moment/countdown |
| `CaptureToInboxIntent` | Start Universal Capture from a control widget |
| `OpenTaskScopeIntent`, `CompleteTaskFromWidgetIntent`, `DeferTaskFromWidgetIntent` | Open, complete, or defer a stable task |
| `ResolveBehaviorOccurrenceIntent` | Resolve a supported habit/behavior occurrence |

### Home, widget, Watch, and extension coverage

- **Home card kinds:** `setupChecklist`, `focusNow`, `lifeSnapshot`, `care`, `tasks`, `routines`, `scheduleCapacity`, `quickCapture`, `compactTimeline`, `journal`, `progressReflection`, `fasting`, `goals`, `evaConversation`, `bodyMetric`, `workout`, `sleep`, `movement`, `lifeMoment`, `nutritionSummary`, `recentMeal`, `logMeal`.
- **Widgets:** task lists, Focus Seed, Streak Resilience, Journal, Fasting, Nutrition, Wellness, Life Moments, Goals, Routines, and Capture Control.
- **Live Activities:** Focus, Fasting, and Routine.
- **Watch:** timeline, meetings, and habit complications/widgets; durable capture and audio outbox in the Watch app.
- **Share extension:** reviewable capture into supported task, note, journal, link, text, image, or file flows, depending on payload and enabled destination.

## Promoted flags and limitations

Current promoted flags are rollback boundaries, not separate products or alternative stores. The catalog covers the flag families for foundation shell/presentation/IA, wellness/fasting/nutrition/Life Moments, system surfaces and dashboard customization, trackers and Health/write-back, Journal/Knowledge/planning/Focus/Track/goals/routines/care, trust closure and Daily Loop, flagship task/project/Home/Track experiences, Universal Input/dictation/semantic routing, EVA, gamification, and widgets. Disabling a retained flag must not destroy canonical records; re-enabling must reveal them intact.

The current `promotedDefaults` keys are exhaustively accounted for here:

| Promoted key | Catalog capability |
|---|---|
| `debug.life_os_foundation_v1` | Five-root shell and onboarding foundation |
| `feature.life_os.unified_presentation_v2` | Shared Adaptive Home/LifeOS presentation |
| `feature.life_os.premium_ia_v5` | Current information architecture and root presentation |
| `feature.life_os.wellness_core_v1` | Generic wellness and care evidence |
| `feature.life_os.fasting_v2` | Fasting sessions/history/system surfaces |
| `feature.life_os.nutrition_v1` | Food, meals, recipes, reports, and nutrition sync |
| `feature.life_os.life_moments_v1` | Life Moments/countdowns |
| `feature.life_os.system_surfaces_v2` | Widgets, intents, notifications, Watch, Spotlight, and deep links |
| `feature.life_os.dashboard_customization_v2` | Home cards, sizing, placement, and Add to Home |
| `feature.life_os.trackers_v1` | Generic trackers and typed samples |
| `feature.life_os.health_integrations_v1` | HealthKit read connections |
| `feature.life_os.health_writeback_v1` | Supported HealthKit write-back/outbox |
| `feature.life_os.journal_v1` | Journal capture/day/history |
| `feature.life_os.journal_parity_v1` | Mood, media, semantic evidence, reflection, and Watch parity |
| `feature.life_os.knowledge_notes_v1` | Notes and Knowledge spaces |
| `feature.life_os.planning_core_v1` | Inbox/Day/Week/Backlog and receipts |
| `feature.life_os.focus_execution_v2` | Focus sessions and continuity |
| `feature.life_os.track_foundations_v2` | Track Today and domain foundations |
| `feature.life_os.goals_routines_v1` | Goals, routines, runs, and progress evidence |
| `feature.life_os.care_modules_v2` | Medication/care states and reminders |
| `feature.life_os.knowledge_notes_textkit_v2` | TextKit/block note editing |
| `feature.life_os.knowledge_notes_search_v2` | Indexed Notes/Knowledge search |
| `feature.life_os.knowledge_notes_security_v1` | Secure notes and biometric unlock |
| `feature.life_os.knowledge_notes_eva_v1` | EVA-assisted note actions |
| `feature.life_os.trust_closure_v1` | Recovery Center and trust diagnostics |
| `feature.life_os.daily_loop_v1` | Commit/Act/Repair/Close/Rest mutation surfaces |
| `feature.life_os.task_project_flagship_v1` | Task/project detail and Plan Repair |
| `feature.life_os.day_close_v1` | Day Close reconciliation and carry-forward |
| `feature.life_os.day_open_commit_v1` | Morning commitment/Day Open |
| `feature.life_os.home_loop_spine_v1` | Home daily-loop spine |
| `feature.universal_input.routing_v1` | Universal deterministic routing |
| `feature.universal_input.dictation_v1` | Live SpeechAnalyzer dictation |
| `feature.universal_input.semantic_v1` | Semantic classification and fallback |
| `feature.life_os.track_behavior_flagship_v1` | Flagship habit/goal/care/tracker presentation |
| `feature.onboarding.life_weave_v6` | v6 "Life Weave" first run; off in Release until the rollout completes, with the v5 Life Map journey still composed and resumable |
| `feature.life_os.eva_fm_responder_v1` | Legacy key retained for migration compatibility; Apple Foundation Models are no longer an EVA provider |
