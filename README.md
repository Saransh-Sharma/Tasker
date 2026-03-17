# Tasker (iOS)

Tasker is an ADHD-focused todo and life-management app built for low-friction planning, fast execution, and momentum-preserving follow-through.

## Product Overview

Tasker is designed to increase the probability that intent becomes action.
The product focuses on reducing execution friction in everyday life by combining fast capture, bounded decision support, interruption recovery, and reflection loops that reinforce progress without shame-based pressure.

Tasker is not a clinical treatment product. It is a productivity product with ADHD-relevant execution support and non-judgmental interaction design.

## Who Tasker Is For

- Adults with high context load balancing work, personal, and life-admin responsibilities.
- Students and early-career builders facing deadline clustering.
- Habit-oriented users seeking consistency without perfection pressure.
- Low-energy or burnout-prone users needing gentle restart paths.

## Core Execution Loop

Tasker uses a five-phase loop:
1. Capture
2. Decide
3. Start
4. Resume
5. Reflect

Design intent by phase:
- Capture: fast input with minimal required fields.
- Decide: narrow focus to actionable choices now.
- Start: minimize transition cost from plan to action.
- Resume: keep context available after interruptions.
- Reflect: encourage continuity and recovery.

## Experience Surfaces

### Home And Focus
- Bounded "Now" list for immediate action.
- Quick Views for Today, Next, Overdue, Quick Wins, Deep Work, Waiting, and Someday.
- Resume cues after interruption and lightweight done timeline for reflection.

### Add Task
- Two-speed task creation: Lightning capture and Clarify mode.
- Lightning capture supports immediate task creation.
- Clarify mode supports deeper structure such as notes, steps, tags, schedule, and dependencies.

### Tasks Browse And Search
- Browse, smart views, and project-oriented navigation for backlog control.
- Search is optimized for fast retrieval as backlog size grows.

### Assistant
- Ask mode: read-only support.
- Plan mode: proposal cards with rationale.
- Apply mode: propose -> confirm -> apply with diff visibility and bounded undo.

### Insights And Analytics
- Today: momentum, due pressure, focus pulse, completion mix, and recovery loop signals.
- Week: weekly momentum, weekday pattern, project leaderboard, and priority/task-type mix.
- Systems: progression, streak resilience, reminder response, focus ritual health, and recovery loop health.

### Settings
- Controls for reminders, focus behavior, assistant behavior, privacy posture, and accessibility preferences.

## Trust And Safety Guardrails

- Explicit non-clinical product framing.
- No silent assistant mutations for impactful actions.
- Confirmation plus bounded undo for assistant apply workflows.
- Privacy disclosures for data handling and assistant mode behavior.
- Notification strategy optimized for helpfulness over volume.

## Notification Strategy

Tasker uses local notifications to support execution and reflection with bounded, actionable prompts.

### Product Principles
- Relevance over volume: avoid duplicate reminders and stale prompts.
- Actionable by default: notifications provide direct next actions where possible.
- Day framing: reinforce start-of-day planning and end-of-day reflection.
- Explicit controls: user-managed toggles/times in Settings, with clear permission state.

### Catalog

| Type | Trigger | Title | Body template | Actions | Destination |
| --- | --- | --- | --- | --- | --- |
| Task Reminder | Future `alertReminderTime` | `Task Reminder` | `"{taskTitle}" is due {relativeDueText}.` fallback `"{taskTitle}" is waiting for you.` | `Open`, `Complete`, `Snooze 15m` | Task detail |
| Due Soon Nudge | Open task due in next 120m without explicit reminder in window | `Due Soon` | `"{taskTitle}" is due in {minutes}m.` + optional ` + {additionalCount} more due soon` | `Open`, `Complete`, `Snooze 15m` | Home Today |
| Overdue Nudge | Overdue tasks exist, slots at 10:00 and 16:00 local | `Overdue Task` | `"{taskTitle}" is overdue by {days} day(s).` + optional ` + {additionalCount} more overdue` | `Open`, `Complete`, `Snooze 15m` | Home Today |
| Morning Plan | Daily local schedule (default 08:00) | `Morning Plan` | If tasks: `{openCount} tasks today ({highCount} high priority, {overdueCount} overdue). Start with "{topTaskTitle}".` else fallback copy | `Open Today`, `Snooze 30m` | Daily Summary Modal (Morning Plan) |
| Nightly Retrospective | Daily local schedule (default 21:00) | `Day Retrospective` | If completions: `Completed {completedCount}/{totalCount} tasks, earned {xp} XP. Biggest win: "{topCompletedTaskTitle}".` else fallback copy | `Open Done`, `Snooze 60m` | Daily Summary Modal (Nightly Retrospective) |

### Technical Decisions
- Time source: local device timezone.
- Defaults: morning `08:00`, nightly `21:00`.
- Quiet hours: disabled in current release.
- Reconciliation: desired-vs-pending diff (`added`, `updated`, `removed`, `unchanged`) using content fingerprinting.
- Route semantics: `homeToday(taskID:)` changes quick view only; only `taskDetail(taskID:)` opens task detail modal.
- Daily summary semantics: morning/nightly default tap routes to `dailySummary(kind:dateStamp:)` and presents a dedicated summary modal.
- Managed IDs include task reminders/due soon/overdue/snooze and daily summary IDs.

Implementation details and contracts:
- `docs/architecture/notifications-local-strategy-v3.md`

## Product Metrics Snapshot

Primary product metrics include:
- Activation: first-task capture and time-to-first completion.
- Daily execution: focus selection and start-to-complete conversion.
- Recovery: return-to-context utilization after interruption.
- Backlog health: overdue carry-over and stale backlog trend.
- Reminder quality: acknowledgment and action conversion.
- Assistant trust: proposal acceptance, undo frequency, apply failures.

Full metric definitions, acceptance criteria, and requirement detail live in:
- `PRODUCT_REQUIREMENTS_DOCUMENT.md`

## Runtime Snapshot

Current V3 runtime composition:
1. `AppDelegate` bootstraps split `TaskModelV3` stores with hard-cut epoch key `tasker.v3.store.epoch`, CloudKit container `iCloud.TaskerCloudKitV3`, explicit sync runtime mode (`fullSync` vs `writeClosed`), and cloud-authoritative manual recovery actions.
2. `EnhancedDependencyContainer` wires repositories/services and builds `UseCaseCoordinator`.
3. `PresentationDependencyContainer` exposes ViewModels and validates presentation-side runtime readiness.

Primary source anchors:
- `To Do List/AppDelegate.swift`
- `To Do List/State/DI/EnhancedDependencyContainer.swift`
- `To Do List/Presentation/DI/PresentationDependencyContainer.swift`
- `To Do List/UseCases/Coordinator/UseCaseCoordinator.swift`

## Gamification V2

Gamification V2 is now engine-driven and event-driven.

Canonical loop:
1. User action (task completion, focus session end, reflection completion).
2. `GamificationEngine.recordEvent(context:)`.
3. Core Data ledger/profile writes (`XPEvent`, `DailyXPAggregate`, `GamificationProfile`).
4. Post-commit `Notification.Name.gamificationLedgerDidMutate`.
5. Home (`HomeViewModel`), Insights (`InsightsViewModel`), and widgets consume updated state.

How XP stays correct:
- Idempotency keys prevent duplicate awards for repeated equivalent actions.
- Global daily cap is enforced in XP calculation.
- UI freshness is event-driven from post-commit ledger mutation notification.
- `fullReconciliation()` rebuilds aggregates/profile from ledger truth after partial-write failure or qualified cloud import.

Deep technical reference:
- `docs/architecture/gamification-v2-engine.md`

## Release Cutover Policy

- V3-only runtime: legacy task contracts (`TaskRepositoryProtocol`, compatibility task aliases, legacy bridge adapters) are removed.
- Upgrade data policy is destructive reset by design for this hard cut.
- Cloud sync cutover uses a new container: `iCloud.TaskerCloudKitV3`.
- Runtime bootstrap does not auto-wipe stores on compatibility failures; cloud bootstrap failures enter write-closed mode (reads allowed, writes blocked) until user-initiated iCloud recovery.

## Repository Map

| Layer | Purpose | Primary Paths |
| --- | --- | --- |
| Domain | Models, repository interfaces, domain events | `To Do List/Domain` |
| UseCases | Business workflows and orchestration | `To Do List/UseCases` |
| State | CoreData repositories, services, DI composition | `To Do List/State` |
| Presentation | ViewModels and presentation DI | `To Do List/Presentation` |
| LLM | Chat UI, local model UX, context projection | `To Do List/LLM` |
| UI | SwiftUI/UIKit views and controllers | `To Do List/View`, `To Do List/Views`, `To Do List/ViewControllers` |

## V3 Systems At A Glance

| System | What It Owns | Primary Code Anchors |
| --- | --- | --- |
| TaskDefinition-centric write model | canonical task identity, dependency/tag graph, mutation contracts | `To Do List/Domain/Models/Task.swift`, `To Do List/State/Repositories/CoreDataTaskDefinitionRepository.swift`, `To Do List/UseCases/Task/CreateTaskDefinitionUseCase.swift` |
| Read-model query layer | paged/sorted/filterable task slices and project aggregates for UI | `To Do List/Domain/Interfaces/TaskReadModelRepositoryProtocol.swift`, `To Do List/State/Repositories/CoreDataTaskReadModelRepository.swift`, `To Do List/UseCases/Task/GetHomeFilteredTasksUseCase.swift` |
| Scheduling and occurrence lifecycle | recurrence generation, occurrence maintenance, resolution/tombstone hygiene | `To Do List/State/Services/CoreSchedulingEngine.swift`, `To Do List/UseCases/Schedule/GenerateOccurrencesUseCase.swift`, `To Do List/UseCases/Schedule/MaintainOccurrencesUseCase.swift` |
| External reminders synchronization | provider mapping, merge-clock reconciliation, two-way convergence | `To Do List/State/Repositories/CoreDataExternalSyncRepository.swift`, `To Do List/UseCases/Sync/LinkExternalRemindersUseCase.swift`, `To Do List/UseCases/Sync/ReconcileExternalRemindersUseCase.swift` |
| Assistant action pipeline | propose/confirm/apply/undo transactional commands over `TaskDefinition` entities | `To Do List/UseCases/LLM/AssistantActionPipelineUseCase.swift`, `To Do List/UseCases/LLM/AssistantCommandExecutor.swift`, `To Do List/Domain/Models/AssistantAction.swift` |

## Quick Start

### Prerequisites
- macOS 14+
- Xcode 15+
- CocoaPods

### Install
```bash
git clone https://github.com/Saransh-Sharma/Tasker.git
cd Tasker
pod install
open Tasker.xcworkspace
```

### Build
```bash
./taskerctl build
./taskerctl build device
./taskerctl doctor
```

Use deterministic `xcodebuild` gates for migration/release validation; avoid `./taskerctl clean --all` as a phase gate because it mutates CocoaPods integration.

### Test
```bash
xcodebuild test -workspace Tasker.xcworkspace -scheme "To Do List" -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:TaskerTests
xcodebuild test -workspace Tasker.xcworkspace -scheme "To Do List" -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:TaskerUITests
```

## Documentation Catalog (Exhaustive)

| Doc | Type | Canonical/Reference | When to update | Primary audience |
| --- | --- | --- | --- | --- |
| `PRODUCT_REQUIREMENTS_DOCUMENT.md` | Product strategy and detailed requirements | Canonical | product promise, personas, feature requirements, acceptance criteria, or roadmap changes | product, design, engineering leads |
| `AGENTS.md` | Agent workflow instructions | Canonical | automation/agent behavior instruction changes | AI-assisted contributors |
| `docs/README.md` | Docs top-level index | Canonical | any docs structure or ownership change | all contributors |
| `docs/architecture/README.md` | Architecture index and update policy | Canonical | architecture doc set additions/ownership changes | engineers |
| `docs/architecture/data-model-v2.md` | V2 schema/domain invariants | Canonical | entity/field/relationship/migration changes | backend-state and feature engineers |
| `docs/architecture/clean-architecture-v2.md` | layering, DI/runtime, fail-closed behavior | Canonical | runtime wiring/feature-gate/bootstrapping changes | platform and feature engineers |
| `docs/architecture/usecases-v2.md` | usecase contracts and side effects | Canonical | usecase API/dependency/behavior changes | app engineers |
| `docs/architecture/gamification-v2-engine.md` | gamification engine runtime, correctness, reconciliation, and widget path | Canonical | any change in `UseCases/Gamification/*`, `CoreDataGamificationRepository`, XP mutation signal flow, or Insights event-driven projection behavior | feature engineers, platform engineers, incident responders |
| `docs/architecture/risk-register-v2.md` | migration risks and guardrails | Canonical | new risks, mitigations, release policy changes | tech leads, reviewers |
| `docs/architecture/state-repositories-and-services-v2.md` | repository/service internals | Canonical | State repository/service changes | state/data engineers |
| `docs/architecture/domain-events-and-observability-v2.md` | domain event system and handler behavior | Canonical | event schema/handler/notification changes | app + analytics engineers |
| `docs/architecture/notifications-local-strategy-v3.md` | local notification product + technical strategy | Canonical | notification catalog, routing, scheduling/reconcile, permission flow changes | app engineers, product, QA |
| `docs/architecture/llm-assistant-stack-v2.md` | LLM context + assistant transaction boundaries | Canonical | `/LLM` or `/UseCases/LLM` changes | AI feature engineers |
| `docs/architecture/llm-feature-integration-handbook.md` | mixed engineering/product AI runtime handbook | Canonical | AI routing, runtime semantics, flags, or release behavior changes | AI feature engineers, PMs, QA |
| `docs/operations/ci-release-and-guardrails.md` | CI workflows, script guardrails, release evidence flow | Canonical | workflow/script/release gate changes | release owners, maintainers |
| `docs/operations/developer-tooling-and-flowctl.md` | `taskerctl` + flowctl policy and troubleshooting | Canonical | tooling scripts or CI tooling rules change | contributors, CI maintainers |
| `docs/cloudkit-two-device-smoke.md` | CloudKit two-device runbook | Canonical | smoke scenarios/evidence rules change | QA, release managers |
| `docs/cloudkit-smoke-evidence/latest.md` | release smoke evidence pointer | Canonical pointer | each smoke run | release owners |
| `docs/release-gate-v2-efgh.md` | release block criteria | Canonical | gate criteria/workflow mapping changes | release owners |
| `To Do List/View/LiquidGlass/README.md` | component-specific UI notes | Canonical (component scope) | LiquidGlass component behavior updates | UI engineers |
| `clean.md` | clean-architecture conceptual guide | Reference | rarely; conceptual alignment updates | contributors learning architecture concepts |
| `claude.md` | retained historical architecture playbook | Reference | retained for historical context and migration intent | maintainers, reviewers |
| `docs/archive/qoder-repowiki/README.md` | archive policy for moved repowiki docs | Canonical (archive policy) | archive scope/policy changes | maintainers |

## Archived Docs

Legacy generated repowiki docs were moved out of active paths and are non-canonical:
- `docs/archive/qoder-repowiki/README.md`
- `docs/archive/qoder-repowiki/en/content/**`

## Documentation Maintenance Rules

1. Update canonical architecture docs in the same PR as code changes.
2. Keep PRD product-facing; put implementation details under `docs/architecture/*` or `docs/operations/*`.
3. Do not reintroduce archived docs into active runbooks.
4. Keep release runbooks aligned with:
- `.github/workflows/ios.yml`
- `.github/workflows/cloudkit-smoke.yml`
- `scripts/validate_cloudkit_smoke_evidence.sh`
5. Update both canonical LLM docs together when `/LLM` runtime behavior changes.

## Legacy Cleanup Status

- Legacy task runtime bridge is removed; app runtime is V3-only.
- Legacy debt doc removed (content absorbed into architecture/risk docs).
- Legacy root CLI guide removed (content absorbed into operations tooling docs).
- `clean.md` retained as historical reference.

## License

MIT (see distribution artifacts for license file details).
