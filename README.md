# Tasker (iOS)

Tasker is an ADHD-focused todo and life-management app built for low-friction planning, fast execution, and momentum-preserving follow-through.

## Runtime Snapshot

Current V2 runtime composition:
1. `AppDelegate` bootstraps `TaskModelV2` stores and executes fail-closed readiness checks.
2. `EnhancedDependencyContainer` wires repositories/services and builds `UseCaseCoordinator`.
3. `PresentationDependencyContainer` exposes ViewModels and validates presentation-side V2 readiness.

Primary source anchors:
- `To Do List/AppDelegate.swift`
- `To Do List/State/DI/EnhancedDependencyContainer.swift`
- `To Do List/Presentation/DI/PresentationDependencyContainer.swift`
- `To Do List/UseCases/Coordinator/UseCaseCoordinator.swift`

## Repository Map

| Layer | Purpose | Primary Paths |
| --- | --- | --- |
| Domain | Models, repository interfaces, domain events | `To Do List/Domain` |
| UseCases | Business workflows and orchestration | `To Do List/UseCases` |
| State | CoreData repositories, services, DI composition | `To Do List/State` |
| Presentation | ViewModels and presentation DI | `To Do List/Presentation` |
| LLM | Chat UI, local model UX, context projection | `To Do List/LLM` |
| UI | SwiftUI/UIKit views and controllers | `To Do List/View`, `To Do List/Views`, `To Do List/ViewControllers` |

## V2 Systems At A Glance

| System | What It Owns | Primary Code Anchors |
| --- | --- | --- |
| TaskDefinition-centric write model | canonical task identity, dependency/tag graph, mutation contracts | `To Do List/Domain/Models/Task.swift`, `To Do List/State/Repositories/CoreDataTaskDefinitionRepository.swift`, `To Do List/UseCases/Task/CreateTaskDefinitionUseCase.swift` |
| Read-model query layer | paged/sorted/filterable task slices and project aggregates for UI | `To Do List/Domain/Interfaces/TaskReadModelRepositoryProtocol.swift`, `To Do List/State/Repositories/CoreDataTaskReadModelRepository.swift`, `To Do List/UseCases/Task/GetHomeFilteredTasksUseCase.swift` |
| Scheduling and occurrence lifecycle | recurrence generation, occurrence maintenance, resolution/tombstone hygiene | `To Do List/State/Services/CoreSchedulingEngine.swift`, `To Do List/UseCases/Schedule/GenerateOccurrencesUseCase.swift`, `To Do List/UseCases/Schedule/MaintainOccurrencesUseCase.swift` |
| External reminders synchronization | provider mapping, merge-clock reconciliation, two-way convergence | `To Do List/State/Repositories/CoreDataExternalSyncRepository.swift`, `To Do List/UseCases/Sync/LinkExternalRemindersUseCase.swift`, `To Do List/UseCases/Sync/ReconcileExternalRemindersUseCase.swift` |
| Assistant action pipeline | propose/confirm/apply/undo transactional commands over V2 tasks | `To Do List/UseCases/LLM/AssistantActionPipelineUseCase.swift`, `To Do List/UseCases/LLM/AssistantCommandExecutor.swift`, `To Do List/Domain/Models/AssistantAction.swift` |

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
./taskerctl clean --all
./taskerctl doctor
```

### Test
```bash
xcodebuild test -workspace Tasker.xcworkspace -scheme "To Do List" -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:TaskerTests
xcodebuild test -workspace Tasker.xcworkspace -scheme "To Do List" -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:TaskerUITests
```

## Documentation Catalog (Exhaustive)

| Doc | Type | Canonical/Reference | When to update | Primary audience |
| --- | --- | --- | --- | --- |
| `PRODUCT_REQUIREMENTS_DOCUMENT.md` | Product strategy/requirements | Canonical | persona/pillar/metric/roadmap changes | product, design, engineering leads |
| `AGENTS.md` | Agent workflow instructions | Canonical | automation/agent behavior instruction changes | AI-assisted contributors |
| `docs/README.md` | Docs top-level index | Canonical | any docs structure or ownership change | all contributors |
| `docs/architecture/README.md` | Architecture index and update policy | Canonical | architecture doc set additions/ownership changes | engineers |
| `docs/architecture/data-model-v2.md` | V2 schema/domain invariants | Canonical | entity/field/relationship/migration changes | backend-state and feature engineers |
| `docs/architecture/clean-architecture-v2.md` | layering, DI/runtime, fail-closed behavior | Canonical | runtime wiring/feature-gate/bootstrapping changes | platform and feature engineers |
| `docs/architecture/usecases-v2.md` | usecase contracts and side effects | Canonical | usecase API/dependency/behavior changes | app engineers |
| `docs/architecture/risk-register-v2.md` | migration risks and guardrails | Canonical | new risks, mitigations, release policy changes | tech leads, reviewers |
| `docs/architecture/state-repositories-and-services-v2.md` | repository/service internals | Canonical | State repository/service changes | state/data engineers |
| `docs/architecture/domain-events-and-observability-v2.md` | domain event system and handler behavior | Canonical | event schema/handler/notification changes | app + analytics engineers |
| `docs/architecture/llm-assistant-stack-v2.md` | LLM context + assistant transaction boundaries | Canonical | `/LLM` or `/UseCases/LLM` changes | AI feature engineers |
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

## Legacy Cleanup Status

- Legacy debt doc removed (content absorbed into architecture/risk docs).
- Legacy root CLI guide removed (content absorbed into operations tooling docs).
- `clean.md` and `claude.md` retained as reference docs.

## License

MIT (see distribution artifacts for license file details).
