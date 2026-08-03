# LifeBoard "Beyond Notes" — Engineering & Design Handoff

> **Historical snapshot, superseded for implementation status.** Use
> `LIFEBOARD_PHASE_1_2_IMPLEMENTATION_HANDOFF.md` and `DESIGN.md` as the current
> authorities. As of 2026-08-03, the complete simulator suite executes 2,070
> tests with zero failures and three environment-qualified skips. Native capture
> interruption recovery and the App Group Inbox termination → file → canonical
> Undo journey pass. Remaining signed App Group, paired-Watch, protection,
> haptics, thermal, and frame-pacing checks are release-device evidence.

**Date:** 2026-07-28
**Scope of this document:** everything needed to continue the Beyond Notes roadmap without re-deriving what was already learned.
**Plan of record:** `LifeBoard Beyond Notes — Best-in-Class Product and Experience Roadmap.md`

---

## 1. Read this first: the test baseline is now empty, and that means something

`scripts/lifeboard-test-failure-baseline.txt` used to hold **51 entries** described as accepted legacy debt. It is now **empty**, and the full suite passes (~1889 tests).

Every one of those 51 was investigated. **Not one was a flake.** They were real defects, stale contracts, or broken test infrastructure. Eight reached users:

| Defect | User-visible effect |
|---|---|
| Widget calendar defaulted to `.empty` for absent data | Rendered "nothing scheduled today" when we had no calendar info at all — a missable meeting |
| `TaskCaptureParser` resolved bare times via `NSDataDetector` | A capture queued yesterday saying "3pm" got **today's** date, silently, on a task whose title had also been rewritten |
| `HabitRuntimeSupport.streaks` ignored `.failed` | Streaks were **never broken** by a failed day; every streak inflated and the failure state did nothing |
| `LLMChatOutputClassifier` only caught labelled preambles | A model narrating its reasoning had that shown to the user **as the answer** |
| `HomeCalendarSnapshot.empty` was a computed `var` with `Date()` inside | Two `.empty` values were never equal, so Home re-rendered its calendar slice on **every** transaction |
| `HealthPrivacyMigrationAccess.requireValidated` fetched a possibly-absent entity | Uncatchable ObjC exception on any older model |
| Six `knowledge_notes_*` flags had no `promotedDefaults` entry | The entire Notes flagship — TextKit editor, FTS5 search, encryption, EVA actions — shipped **off** in Release |
| `FilterCalendarEventsUseCase` treated empty selection as "all" | Every calendar read for a user who never chose any — a consent issue |

**Implication for how you work:** treat a failing test here as a bug report until proven otherwise. The instinct to add it to a baseline is what let these sit.

### The gate

```bash
./scripts/run-baseline-aware-tests.sh
```

Reading its diff: `+` lines are failures **not** in the baseline (real signal). `-` lines are baseline entries that passed. With the baseline empty, any `+` is a regression you introduced.

---

## 2. Environment traps that will cost you hours

These are not hypothetical; each one happened.

**Never run two `xcodebuild` invocations concurrently against this DerivedData.** Symptoms lie: `Missing package product 'MLX'`, SPM checkout failures, `build.db: database is locked`. One collision wiped DerivedData entirely (29 GB → 1.1 GB). Serialize with `until ! pgrep -q xcodebuild; do sleep 20; done`.

**Disk pressure evicts the whole iOS platform, not just caches.** At 118 MiB free, macOS purged iOS 26.5 — simulator runtimes *and* device support. `simctl list runtimes` went empty and the connected iPhone became an ineligible destination. Recovery is `xcodebuild -downloadPlatform iOS` (10.6 GB, ~40 min). The data volume runs 85–90% full. **Check `df -h /System/Volumes/Data` before long sessions.**

**HealthKit is not a provisionable Mac Catalyst entitlement.** Adding `com.apple.developer.healthkit` to `LifeBoard/LifeBoardCatalyst.entitlements` fails the *entire* Catalyst build. It must live only in `LifeBoard.entitlements`; `CODE_SIGN_ENTITLEMENTS[sdk=macosx*]` already overrides for Catalyst. All call sites guard `HKHealthStore.isHealthDataAvailable()`, so Catalyst degrades correctly without it.

**Adding a Swift file requires registering it in `project.pbxproj`.** No filesystem-synchronized groups. Register the four sibling-matching entries by hand (`PBXBuildFile`, `PBXFileReference`, group child, Sources phase); do not use the `xcodeproj` Ruby gem because it rewrites this project's formatting and ordering. Verify with `bash scripts/check-xcode-target-membership.sh`.

**Before calling a test flaky, check its timeout against its actual duration.** Two "flakes" here were 1-second budgets against ~1.05-second operations. One failed *in isolation* (paying test-host cold start) and passed in-suite — the opposite of what "flaky" usually looks like. Both were fixed by raising the ceiling to 5s; a condition-based wait returns as soon as it's satisfied, so a larger ceiling costs a passing run nothing.

**`.xccurrentversion` is not the source of truth for the Core Data model version.** Xcode regenerates it from `XCVersionGroup.currentVersion` in `project.pbxproj`. Editing the plist alone silently reverts on the next build. See §5.

---

## 3. What shipped

### Stage 0 — Trust, Recovery, Release Closure ✅

- **Catalyst build restored** (entitlement fix above).
- **Migration coverage derives from the compiled `.momd`** instead of a hardcoded list — `testEveryPreviousModelMigratesToCurrentModelWithoutChangingStableIDs`. It asserts the predecessor **count** so a *removed* model is caught too. Update the count when you add a version.
- **Recovery Center** — `LifeBoard/Foundation/Persistence/LifeBoardRecoveryStatus.swift`, `LifeBoard/Views/Settings/RecoveryCenterView.swift`, reachable from Settings ▸ Data. `lifeBoardTrustClosureV1Enabled` is **on**.
- **`-SKIP_ONBOARDING` bypass fixed** — the resume branch ran ahead of `evaluate()`, the only place the argument was honoured.

### Stage 1.1 — Universal Capture and Inbox 🟡

`LifeBoard/Foundation/PhaseIII/InboxTriageContracts.swift`, `LifeBoardInboxView.swift`.

Working end to end: **Control Center / Siri → App Group queue → Plan ▸ Inbox → review chips → normal editor.**

- `LifeBoardInboxQuery`, `InboxItem`, `InboxTriageMutation` (exact inverses), `InboxDuplicatePolicy`, `InboxReader`
- Inbox lens is **first** in the Plan picker — triage precedes planning
- Triage routes through `InboxTriageMutation.planMutation(resolve:)` → canonical `PlanMutation` ledger, inheriting receipts, Undo and the Insights projection
- `AddTaskIntent` and `CaptureToInboxIntent` queue **raw text**; they never parse-and-commit

### Stage 1.2 — Tasks and Projects 🟡

`LifeBoard/Foundation/PhaseIII/TaskExecutionContracts.swift`.

- `TaskExecutionQuery` — scopes, filters, deterministic sort, pagination
- `ProjectExecutionSnapshot`, `ProjectMilestone`, `TaskExecutionProjection`
- `PlanningTaskMetadata.startDay` — **persisted**, with the new model version

---

## 4. Decisions already made — please don't silently reverse these

Each has a comment at the code site explaining it. If you disagree, that's fine — but change it deliberately.

**Captures never commit silently.** An extension has no UI to review in, so it must not decide. Siri says *"Added to your inbox to review"*, not *"Scheduled for tomorrow"*. `CaptureInboxDrain` was **deleted** — it auto-committed and was never wired; resurrecting it would reintroduce the violation.

**Absent data must never be reported as a confident value.** The widget calendar has `.empty` (a calendar with nothing on it) and `.unavailable` (no calendar information). A legacy payload decodes to `.unavailable`. The Recovery Center **omits** any subsystem it cannot observe rather than showing it healthy. An empty project reports `nil` progress, not 0%.

**Reference ≠ Someday.** `UnscheduledDisposition.reference` and `BacklogGroup.reference` are distinct cases. Someday is "not now"; Reference is "never scheduled". Folding them would drag reference material into deferral reviews.

**Empty calendar selection means *none selected*.** Fixed in `FilterCalendarEventsUseCase`. This is a consent question, not a style one.

**The habit write fan-out is accepted, not a bug.** One logical habit update produces three writes — user change, derived streaks, derived bookkeeping — each computing something the previous couldn't know. Measured by call-stack instrumentation. Two no-op guards remove genuinely wasted writes. Collapsing to one write means threading a mutable record through three use cases: a core refactor of the least-covered chain in the app. Tests assert the real number (5 for 2 logical updates) with an explanatory comment.

**View files must not name a DI container.** `ArchitectureBoundaryTests` scans `LifeBoard/View`, `Views`, `ViewControllers`. Resolution belongs in `Presentation/DI` — see `HabitViewModelFactoryEnvironment.swift` (`HabitViewModelFactory` via `@Environment`, `HabitComposerViewModels`, `SettingsServices`, `RecoveryServices`). **Note:** the check is a plain substring match, so even a doc comment mentioning the symbol trips it.

**Reasoning-leak detection is deliberately narrow.** Keyed on first-person AI self-reference in the opening 400 characters. Broadening it to "any line starting *Thinking*" would match a genuine answer like *"Thinking about your week, here's…"* — and discarding a real answer is worse than showing a clumsy one.

---

## 5. Adding a Core Data model version (you will need this)

Current version: **`TaskModelV3_TaskStartDay`** (21 predecessors).

1. `cp -R TaskModelV3_<Current>.xcdatamodel TaskModelV3_<New>.xcdatamodel` inside `LifeBoard/TaskModelV3.xcdatamodeld/`
2. Edit the new `contents` XML. Validate: `python3 -c "import xml.etree.ElementTree as ET; ET.parse('…/contents')"`
3. **Register it in `project.pbxproj`** — add to `XCVersionGroup.children` *and* set `currentVersion`. Editing `.xccurrentversion` alone silently reverts.
4. Assign new entities to a configuration. `CloudSync` = private sync; `LocalOnly` = rebuildable/derived. Getting this wrong is a privacy bug.
5. Update `testEveryPreviousModelMigratesToCurrentModelWithoutChangingStableIDs` (predecessor count) and `testTaskModelCurrentVersionPointsToAnExistingSourceModel` (pinned name).
6. Retarget any test loading the previous `.mom` **by name** — they'll write attributes the old model lacks. Grep for `TaskModelV3_<Previous>.mom`.

**Two write paths exist for planning metadata.** `CoreDataPlanningRepository.saveTaskMetadata` writes directly; `PlanMutation.saveTaskMetadata` writes through `apply(_:)`. Patch **both** — see `PlanningCorePersistence.swift` ~line 65 and ~line 531. A round-trip test caught this; without it, values would persist one way and vanish the other.

**Health-sensitive entities are dual-homed** in `CloudSync` *and* `LocalOnly` — deliberate, so `HealthPrivacyMigrationCoordinator` can copy each row into the private store before `purgeLegacyCloudRowsIfEligible` removes the cloud copy after a 30-day window. Do not "fix" that overlap. Any test writing `FoodItem`, `NutritionLogEntry`, `NutritionGoal`, `Medication*`, `Fasting*`, `BodyMetricSample`, `WorkoutRecord`, `SleepNote`, `MovementContextRecord`, `Hydration*`, `MoodEnergyCheckIn` or `SleepContextRecord` must use a two-configuration container with a validated `HealthMigrationCheckpoint` — see `makeHealthPrivacyValidatedContainer(name:)` in `LifeOSFoundationTests.swift`.

**Never assert configuration membership via `NSManagedObjectModel.mergedModel(from:)`.** It unions all 21 versions and reports memberships no store ever loads.

---

## 6. For the designer

### Copy rules already encoded in code

**Plain language in primary copy.** No "Core Data", "CloudKit", "FTS5", "index generation". The Recovery Center says *"Your data is safe; search is rebuilding"*, and internal reason tokens like `persistent_store_schema_invalid` go to diagnostics only.

**Say what happened, not what it became.** Siri: *"Added "X" to your inbox to review."* Claiming it was scheduled would be the silent-commit problem in a nicer sentence.

**Empty is a success state, not a void.** Inbox empty reads *"Inbox clear — everything you captured has somewhere to be."* A **failed load** must look different from empty; the app must never congratulate someone for a fetch that didn't complete.

**Four health states, deliberately not two** (`LifeBoardRecoveryStatus.Health`): `healthy`, `working` (in progress — reads as progress, not damage), `attention` (degraded but safe), `unavailable`. Conflating `working` or `attention` with `unavailable` is what makes recovery UI frightening.

**Anti-guilt language.** "Overdue" → "rescue". Streaks → "active days". No punitive red, no unavoidable streak celebrations. Streak and consistency grade get **equal** visual weight.

**Shape carries state, not just colour** — Differentiate Without Color must still distinguish healthy from degraded. See `RecoveryCenterView.indicator(for:)`.

### Screens that exist and need design attention

| Surface | State | Note |
|---|---|---|
| **Plan ▸ Inbox** | Functional, unstyled | Scope picker, triage menu, batch bar, Undo row. Needs the warm paper/clay treatment. Review chips currently show only the parsed date |
| **Settings ▸ Data ▸ Recovery** | Functional, thin | Renders one row (store health) plus journal search when observable. Calm open rows, not diagnostic cards |
| **Capture review** | Reuses the normal task editor | Deliberate: filing an unreviewed capture goes through the same editor as anything typed by hand |

### Visual system

`DESIGN.md` is the contract: warm paper, cocoa ink, apricot, sage, atmospheric dayparts, SF Pro Text with selective SF Rounded. **The roadmap's generic "vibrant block interface" recommendation is explicitly rejected.** Opaque paper for reading/editing/charts/forms; Regular Liquid Glass only for navigation, compact filters, menus, toolbars, capture and EVA's composer. Cards only for movable modules, decisions, or independently actionable summaries — open rows and typography for ordinary grouping.

Guardrails: `scripts/token-law-guardrails.sh`, `scripts/premium-ui-guardrails.sh`.

---

## 7. What to do next, in order

### Immediately actionable

1. **Milestone persistence** — the `ProjectMilestone` entity exists in `TaskModelV3_TaskStartDay` (CloudSync). Needs a repository mirroring `CoreDataPlanningRepository`, wired into `TaskExecutionProjection.projectSnapshot`.
2. **Finish capture producers** — Share Extension and an interactive widget button. Both reuse `CaptureToInboxIntent`; the Share Extension needs its own target.
3. **Extend `TaskCaptureParser`** past title/dueDate to duration, project, tags, recurrence, context. Review chips are already designed to display proposals.
4. **Batch operations with receipts** — `InboxTriageMutation.batch` inverts correctly (last write unwinds first) and is all-or-nothing; the Backlog UI needs wiring.

### Needs a decision before building

- **`moveToProject` and `commitCapture`** need the task repository, not the planning ledger — see `InboxTriageMutation.TranslationFailure`. Decide where that lives.
- **Provisional drafts surviving interruption** — the plan requires local-only-until-applied. No storage decided.

### Not started

Stage 1.3 (Plan spine, capacity, repair), 1.4 (Focus environment), 1.5 (Adaptive Home decision quality), and all of Stage 2 (habits, routines, goals, medication, trackers, wellness/nutrition/fasting).

---

## 8. Known open items

- **`lifeBoardDailyLoopV1Enabled` / `taskProjectFlagshipV1Enabled`** are promoted on. `eva_fm_responder_v1` is deliberately held back (an A/B phrasing path, not a feature).
- **Recovery Center rebuild actions are not wired.** The button says *"Open Journal to rebuild its search index"* rather than calling `invalidate()`, which clears without repopulating — search would get **worse**. Wiring a real rebuild needs the source entries, which live in the Journal module.
- **Signed-device gates remain unverified**: performance, thermal, haptics, App Group, paired Watch, biometrics, Live Activities, and local-model EVA. These block final `lifeBoardFlagshipV1Enabled` promotion.
- **`CalendarIntegrationService` guards `selectedCalendarIDs.isEmpty` before fetching**, so the permissive filter branch was unreachable — it was a trap for the next caller rather than live behaviour. Now fixed.

---

## 9. Verification checklist for any change

```bash
# 1. Both destinations build
xcodebuild build -workspace LifeBoard.xcworkspace -scheme LifeBoard \
  -destination 'platform=iOS Simulator,id=<UDID>'
xcodebuild build -workspace LifeBoard.xcworkspace -scheme LifeBoard \
  -destination 'platform=macOS,variant=Mac Catalyst'

# 2. Suite is green against an empty baseline
./scripts/run-baseline-aware-tests.sh

# 3. Guardrails
bash scripts/check-xcode-target-membership.sh
bash scripts/token-law-guardrails.sh
bash scripts/premium-ui-guardrails.sh
```

Use a **dedicated, clean simulator** for LifeBoard (`LifeBoard Test iPhone`). Other apps installed on a shared simulator can be hit by stray automation.

**A stage is done when** canonical persistence, empty/loading/error/denied states, an accessibility path, contract tests, and one seeded simulator journey all pass — not when the screen renders.
