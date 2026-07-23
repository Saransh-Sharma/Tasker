# Roadmap — From Adaptive Home to the Complete Life OS

> **Classification: Product roadmap reference.** Current completion status is owned by the [remaining execution ledger](../todos/LIFEBOARD_5_REMAINING_EXECUTION_LEDGER.md); feature intent is canonical in the [product handbook](../product/README.md).

Phases I and II create the shell, adaptive command center, capture/data contracts, care tracking, private reflection, and knowledge substrate. The next program should deepen these systems rather than introduce parallel navigation, theme, persistence, or assistant architectures.

## Immediate promotion track — Phase II hardening

Goal: make the implemented Adaptive Home safe to promote to internal and then production cohorts.

- [ ] Establish a clean legacy-test baseline and separate unrelated repository debt from Life OS regressions.
- [ ] Add seeded UI tests for the two-second orientation scenarios, modes, dayparts, customization, and all capture providers.
- [ ] Complete physical-device Core Data/CloudKit upgrade rehearsals from each supported production version.
- [ ] Verify Watch/widgets/App Group compatibility and sensitive-value redaction.
- [ ] Profile launch, navigation, capture, scroll, energy, memory, and all atmosphere backends on supported device tiers.
- [ ] Complete accessibility and sensory-comfort matrix with assistive technologies, not snapshots alone.
- [ ] Run founder proxy, then moderated neurodivergent-user usability sessions; address comprehension and overload findings.
- [ ] Promote Adaptive Home while retaining legacy Home rollback for one release; remove rollback only after telemetry-free local diagnostics and support signals are stable.

Exit: Adaptive Home is the production default, additive schemas have survived real iCloud upgrades, and the legacy Home can be retired without data rollback.

## Phase III — Plan OS and intentional commitments

Goal: turn Plan into the trustworthy place for commitments, capacity, goals, and weekly shaping.

Product scope:

- Unified day/week planning over tasks, routines, calendar reality, focus blocks, energy, and protected recovery.
- Goals → projects → milestones → next actions with explicit ownership and outcome states.
- Capacity planner that explains confidence and missing estimates; no false precision.
- Scenario planning before calendar/task mutation, with review/apply/undo.
- Weekly reset/review connected to Home progress and Journal reflection evidence.
- Time-zone/DST-safe travel behavior and conflict resolution.

Engineering reuse:

- Keep `LifeBoardDestination.plan`, typed routes, capture arbitration, shared theme context, and value repositories.
- Add only goal/planning-owned model versions; preserve the CloudSync/LocalOnly split.
- Publish Plan projections to Home through adapters; widgets do not fetch Core Data.

Exit: a user can decide what matters, see what realistically fits, and commit/replan without losing calendar truth or private context.

## Phase IV — Track OS and care intelligence

Goal: mature tracking into a flexible, safe, user-controlled wellbeing and routine system.

Product scope:

- Tracker histories, charts, goals, reminders, correlations, and export.
- Medication schedule lifecycle, notification actions, audit trail, and neutral adherence reporting.
- Richer HealthKit sources through contextual permission onboarding and provenance-aware display.
- Recovery plans, sensory load, sleep/rest context, and Low Energy continuity.
- Habit/routine unification with daypart/recovery semantics and Watch capture.

Safety boundaries:

- No diagnosis, dosing, interaction advice, or prescriptive fasting/health coaching.
- Insights distinguish observation, confidence, missing data, and user-authored meaning.
- Health data remains minimized and excluded from external surfaces.

Exit: Track answers “what is changing?” and “what care needs attention?” without medicalizing ordinary variability.

## Phase V — Journal and Knowledge OS maturity

Goal: turn private reflection and structured knowledge into dependable long-term memory.

Product scope:

- Journal templates, prompt packs, timeline detail, audio management/export, local semantic search, evidence navigation, and retention controls.
- On-device OCR/transcription improvements with explicit per-operation consent and offline fallbacks.
- Notes import/export, richer table/code/bookmark handling, version history, graph neighborhoods, and reference capture from share extension.
- Explicit links among Journal evidence, Notes, goals, projects, tasks, and tracker trends without leaking excerpts by default.

Engineering constraints:

- Embeddings, chunks, indexes, graph caches, and drafts stay LocalOnly and rebuildable.
- Synced user-authored content remains private; audio stays protected and local until a separate user-approved sync design exists.

Exit: users can retrieve why something mattered, not merely store more content.

## Phase VI — Eva as a trustworthy Life OS copilot

Goal: let Eva orient, explain, rehearse, and propose across Home/Plan/Track/Journal/Notes while keeping the user in control.

Product scope:

- Bounded context broker honoring `DataSensitivity`, surface, intent, and user consent.
- Evidence-linked daily brief, overload warnings, recovery suggestions, planning proposals, and reflection synthesis.
- Preview/apply/undo for every mutation; no hidden task, calendar, medication, or sharing changes.
- Local-model capability tiers and deterministic fallbacks when MLX models are unavailable.
- Explain-why, source inspection, memory controls, deletion, and private-session modes.

Exit: Eva reduces executive-function load without becoming an opaque autonomous operator.

## Phase VII — Insights OS

Goal: connect action, care, time, mood, and reflection into comprehensible trends.

- User-selected questions and dashboards rather than a universal productivity score.
- Confidence-aware correlations, evidence drill-down, missing-data explanations, and time-window comparison.
- Gentle progress language in Low Energy mode and anti-shame defaults everywhere.
- Local computations first; any server capability requires an explicit privacy architecture and consent reset.

Exit: Insights helps users notice and decide; it never labels, diagnoses, or moralizes.

## Phase VIII — Collaboration and shared planning projections

Goal: enable family/team coordination without exposing the private Life OS graph.

- Create a third shared-store architecture only when collaboration ships.
- Share whitelist-based projections of explicit plans, tasks, availability, or routines.
- Never CloudKit-share existing private Task/Journal/Health/Note records directly.
- Permissions, expiry, revocation, audit log, conflict UX, and per-field disclosure preview.

Exit: a user can coordinate a plan while remaining confident that private reflection and care data cannot cross the boundary.

## Phase IX — Ecosystem, automation, and platform depth

Goal: make Life OS useful wherever intent appears while preserving one source of truth.

- Watch capture/care actions, widgets, Live Activities, App Intents/Shortcuts, Spotlight, share extension, and notification actions.
- iPad multiwindow, Catalyst command menus, keyboard-first editing, drag/drop, and spatially appropriate layouts.
- User-authored automations with simulation, scope preview, rate limits, history, and undo.
- Import/export, backup/recovery, portability, and account deletion.

Exit: the system is ambient and interoperable without fragmenting state or bypassing privacy/review boundaries.

## Program-level definition of complete

Life OS is complete when a user can orient, choose, act, care, plan, remember, reflect, learn, and selectively coordinate from one coherent system; every surface works with accessibility and static-rendering fallbacks; private data boundaries are inspectable; migrations survive real-world iCloud histories; and Eva remains useful without being required for core behavior.
