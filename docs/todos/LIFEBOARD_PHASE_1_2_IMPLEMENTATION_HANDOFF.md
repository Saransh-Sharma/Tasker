# LifeBoard — Phase 1 & Phase 2 Implementation Handoff

**Date:** 2026-07-28
**Branch:** `lifeOS` (head `f91af671`)
**Supersedes as the active tracker:** `LIFEBOARD_BEYOND_NOTES_HANDOFF.md` (still accurate except where noted in §2 and §11)
**Audience:** the engineer picking this up cold

---

## 1. Read this first

### The suite is green and the baseline is empty. That means something.

```
LifeBoardTests: 1917 executed, 3 skipped, 0 failures
scripts/lifeboard-test-failure-baseline.txt: 0 bytes
```

All four guardrail scripts pass. Both destinations build. **Any failure you see is one you introduced.** Do not add entries to the baseline. The previous 51 baseline entries were all investigated and *not one was a flake* — eight were user-visible defects.

### Two status documents disagreed; this one is the resolution

`LIFEBOARD_5_REMAINING_EXECUTION_LEDGER.md` records a 2026-07-23 run with **44 failing methods**. That is **stale** — it predates the fixes described in `LIFEBOARD_BEYOND_NOTES_HANDOFF.md` §1. Verified by running the gate on 2026-07-28. Trust the gate, not the ledger row.

### The trap that shapes this whole project

Large parts of this codebase are **built, tested, and unreachable**. Before you implement anything, grep for it — it may already exist with zero call sites:

| Thing | State |
|---|---|
| `TaskExecutionContracts.swift` (362 lines, 3 test suites) | **Zero production call sites.** Every reference outside the file is in tests. |
| `ProjectMilestone` Core Data entity | Ships in the model, CloudKit-assigned, schema-tested. **No repository exists.** Nothing can read or write the table. |
| `PlanningTaskMetadata.startDay` | Persisted through both write paths. **No UI sets it.** |
| `EstimateCalibrationSuggestion` | Model + generating service exist. No view, no store property, no call site. |
| `taskProjectFlagshipV1Enabled` | Promoted **on**. Gates exactly one integer (`LifeBoardPlanViews.swift:1064`, repair deck 2→4 directions). |
| `InboxCommitCoordinator` (new, this session) | Tested against a spy. **`LifeBoardInboxView` does not call it.** |

Your first instinct on any Phase 1 item should be "is the contract already there and just unwired?" Usually yes.

---

## 2. Environment traps that will cost you hours

Each of these actually happened.

**Never run two `xcodebuild` invocations concurrently against this DerivedData.** Symptoms lie: `Missing package product 'MLX'`, SPM checkout failures, `build.db: database is locked`. One collision wiped DerivedData (29 GB → 1.1 GB). Serialize:
```bash
until ! pgrep -q xcodebuild; do sleep 20; done
```

**The `xcodeproj` Ruby gem silently deletes Core Data model versions.** ⚠️ **This contradicts `LIFEBOARD_BEYOND_NOTES_HANDOFF.md` §2, which calls the gem "the safest way to do it." It is not.** Using it on 2026-07-28 to register one Swift file printed:

```
<XCVersionGroup path='TaskModelV3.xcdatamodeld'> attempted to initialize an object
with an unknown UUID A12E00000000000000000022 ... the unknown UUID is being discarded
```

and the saved `project.pbxproj` had **`TaskModelV3_NotesCompletion.xcdatamodel` removed from `XCVersionGroup.children`** (22 → 21). That breaks the migration chain the `.momd`-enumerating test asserts. It also wrote a wrong `path = ../File.swift`.

**Register files by hand instead.** Four string inserts mirroring a sibling file — see `CoreDataInboxTaskWriter.swift` in `f91af671` for the exact pattern: `PBXBuildFile`, `PBXFileReference` (with `name` *and* group-relative `path`), group `children`, Sources phase. Then **always** verify:

```bash
python3 -c "import re;s=open('LifeBoard.xcodeproj/project.pbxproj').read();m=re.search(r'isa = XCVersionGroup.*?children = \((.*?)\);',s,re.S);print(len(re.findall(r'xcdatamodel \*/',m.group(1))))"
# must print 22
```

**Disk pressure evicts the entire iOS platform, not just caches.** At 118 MiB free, macOS purged iOS 26.5 — simulator runtimes *and* device support. Recovery is `xcodebuild -downloadPlatform iOS` (10.6 GB, ~40 min). The volume runs 94–95% full. **Check `df -h /System/Volumes/Data` before long sessions.**

**HealthKit is not a provisionable Mac Catalyst entitlement.** `com.apple.developer.healthkit` in `LifeBoardCatalyst.entitlements` fails the *entire* Catalyst build. It belongs only in `LifeBoard.entitlements`.

**SourceKit's inline diagnostics are unreliable here.** It routinely reports `Cannot find type 'TaskRepeatPattern' in scope` for same-target types and `No such module 'XCTest'` in test files. Verified spurious: the Sources build phase spans `project.pbxproj` lines 5089–6148 and all the "missing" files sit inside it. **A compile is the only ground truth.**

**Before calling a test flaky, check its timeout against its actual duration.** Two "flakes" were 1-second budgets against ~1.05-second operations.

---

## 3. What shipped this session (4 commits)

| Commit | Content |
|---|---|
| `3d0d1bf8` | Stage A baseline commit — 49 files of prior WIP, giving `token-law-guardrails.sh` a real diff base |
| `87eb1079` | `TaskCaptureParser` extended to duration, project, tags, context, recurrence, priority (+17 tests) |
| `244a61e7` | `InboxCommitCoordinator` + `.moveToProject` inverse fix (+11 tests) |
| `f91af671` | `CoreDataInboxTaskWriter` + `phase1-foundation-guardrails.sh` repair |

`phase1-foundation-guardrails.sh` **was red at `HEAD`** before this session (9 `#RRGGBB` literals under `LifeBoard/Foundation`). Fixed by relocating all nine verbatim into `LifeBoardSceneHex` in `LifeBoardDaypartTokens.swift` — the guardrail's sanctioned exception. Values are byte-identical; nothing renders differently.

---

## 4. Decisions already made — do not silently reverse

Each has a comment at its code site. Disagree deliberately, not by accident.

**Captures never commit silently.** An extension has no UI to review in, so it must not decide. Siri says *"Added to your inbox to review"*, never *"Scheduled for tomorrow."* `CaptureInboxDrain` was **deleted** — it auto-committed parsed captures. Do not resurrect it.

**Absent data is never reported as a confident value.** The widget calendar distinguishes `.empty` (a day with nothing on it) from `.unavailable` (no calendar information). The Recovery Center **omits** subsystems it cannot observe rather than showing them healthy. An empty project reports `nil` progress, not 0%.

**Reference ≠ Someday.** `UnscheduledDisposition.reference` and `.someday` are distinct. Someday is "not now"; Reference is "never scheduled". Folding them drags reference material into deferral reviews.

**Parser grammar decisions** (`TaskCaptureParser.swift`):
- **`@context` requires a letter after the sigil.** The time grammar accepts a leading `@` (`@3pm`), so a digit-tolerant context pattern would race it and win, giving "call mom @3pm" a context named "3pm" and no time. The letter requirement makes the grammars disjoint *by construction*, not by pass ordering — which would break on the next reorder.
- **Recurrence is matched before dates.** "standup every monday" would otherwise be claimed by the weekday matcher and become a one-off due date, silently demoting a repeating commitment.
- **Duration requires the word "for".** A bare "45 min" is usually part of the title ("watch 45 min yoga video").
- **An unresolvable date phrase returns its words to the title** rather than being stripped with no date to show for it.

**Commit-path decisions** (`InboxCommitCoordinator.swift`, `CoreDataInboxTaskWriter.swift`):
- **Never remove the capture until the task exists.** A capture is often the only copy of something typed once from a lock screen. Test: `testFailedTaskWriteLeavesTheCaptureInTheQueue`.
- **Undo restores the capture with its original id, text, timestamp and source.** Re-queuing it fresh would float it to the top of an age-ordered Inbox and make an undo read as a new capture.
- **Commit is built from the reviewed `ParsedCapture`, never re-parsed.** Re-parsing at commit time would let the chips show one proposal while the commit computed another, since relative dates resolve against a moved reference.
- **Unknown `@context` becomes a tag, not nothing.** `TaskContext` is a closed enum; discarding text the chip displayed is silent loss.
- **Tags are get-or-create; projects are not.** A tag is a lightweight label, so `#tag` must work first time. A project is a deliberate act with its own review — inventing one from a typo litters the sidebar permanently. Unknown `+project` files to Inbox; the name still shows on the chip.

**The habit write fan-out is accepted, not a bug.** One logical habit update produces three writes, each computing something the previous could not know. Tests assert the real number (5 for 2 logical updates).

**View files must not name a DI container.** `ArchitectureBoundaryTests` scans `LifeBoard/View`, `Views`, `ViewControllers` with a **plain substring match** — even a doc comment mentioning the symbol trips it. Resolution belongs in `Presentation/DI`; see `HabitViewModelFactoryEnvironment.swift`.

---

## 5. Adding a Core Data model version

Current version: **`TaskModelV3_TaskStartDay`** (21 predecessors, 22 total, 95 entities).

1. `cp -R TaskModelV3_TaskStartDay.xcdatamodel TaskModelV3_<New>.xcdatamodel` inside `LifeBoard/TaskModelV3.xcdatamodeld/`
2. Edit the new `contents` XML. Validate: `python3 -c "import xml.etree.ElementTree as ET; ET.parse('…/contents')"`
3. **Register in `project.pbxproj` by hand** — add to `XCVersionGroup.children` *and* set `currentVersion`. Editing `.xccurrentversion` alone silently reverts on the next build. **Do not use the `xcodeproj` gem** (§2).
4. Assign new entities to a configuration. `CloudSync` = private sync; `LocalOnly` = rebuildable/derived. Getting this wrong is a privacy bug.
5. Update `testEveryPreviousModelMigratesToCurrentModelWithoutChangingStableIDs` (predecessor count) and `testTaskModelCurrentVersionPointsToAnExistingSourceModel` (pinned name).
6. Grep for tests loading the previous `.mom` **by name** and retarget them.

**Two write paths exist for planning metadata.** `CoreDataPlanningRepository.saveTaskMetadata` writes directly; `PlanMutation.saveTaskMetadata` writes through `apply(_:)`. **Patch both** — `PlanningCorePersistence.swift` ~line 65 and ~line 531.

**Health-sensitive entities are dual-homed** in `CloudSync` *and* `LocalOnly` — deliberate, so `HealthPrivacyMigrationCoordinator` can copy rows into the private store before `purgeLegacyCloudRowsIfEligible` removes the cloud copy after 30 days. **Do not "fix" that overlap.** Any test writing `FoodItem`, `NutritionLogEntry`, `NutritionGoal`, `Medication*`, `Fasting*`, `BodyMetricSample`, `WorkoutRecord`, `SleepNote`, `MovementContextRecord`, `Hydration*`, `MoodEnergyCheckIn` or `SleepContextRecord` **must** use `makeHealthPrivacyValidatedContainer(name:)` in `LifeOSFoundationTests.swift`.

**Never assert configuration membership via `NSManagedObjectModel.mergedModel(from:)`.** It unions all 22 versions and reports memberships no store ever loads.

---

## 6. Feature flags

`LifeBoard/Services/V2FeatureFlags.swift`. Resolution order: DEBUG launch-arg → stored override → **DEBUG returns `true` unconditionally** → Release falls back to `promotedDefaults[key] ?? false`.

⚠️ **On a Debug build every staged flag reads `true` regardless of the table.** Rollback must be exercised with `-LIFEBOARD_DISABLE_<ARG>` or a Release build. A plain Debug run proves nothing.

Every new flag needs a `promotedDefaults` entry or `AppOnboardingTests.swift:1054` fails.

Currently promoted **on**: `trust_closure_v1`, `daily_loop_v1`, `task_project_flagship_v1`, `premium_ia_v5`, and all the domain flags. Held back: `eva_fm_responder_v1` (an A/B phrasing path, not a feature).

⚠️ **`daily_loop_v1` and `task_project_flagship_v1` ship on while their stages are incomplete**, and gate almost nothing. Extend their gating *before* adding surfaces behind them, or rollback stays decorative.

---

## 7. Phase 1 — Flagship Daily Execution Loop

### 7.1 Capture and Inbox — 4 of 5 done

**Done:** contracts (`InboxTriageContracts.swift`), `LifeBoardInboxView` mounted as the *first* Plan lens, raw-text capture from Siri/widget/Control Center, extended parser, `InboxCommitCoordinator`, `CoreDataInboxTaskWriter`.

**Next, and it is the highest-value item in the whole plan:**

**(a) Wire the commit path.** `LifeBoardInboxView` never calls the coordinator; `InboxStore.apply()` still flips `loadFailed` on `.failure`. You need to:
- Inject `InboxCommitCoordinator(writer: CoreDataInboxTaskWriter(...))` into `InboxStore` via `Presentation/DI` (**not** from the view — `ArchitectureBoundaryTests` forbids it).
- The Plan view currently only receives `CoreDataPlanningRepository`; it needs the task, project and tag repositories too.
- Add a "File it" row action building `InboxCaptureCommitRequest.reviewed(captureID:parsed:fallbackTitle:)`.
- Route Undo through `coordinator.undoCommit(_:restoring:)`.
- **Then verify capture → review → file → undo in the simulator against real Core Data. Nothing has exercised this path.**

**(b) Duplicate resolution UI.** `InboxDuplicatePolicy` ranks at 0.82 and is tested; the only surfaced treatment is a passive caption at `LifeBoardInboxView.swift:243`. Build Keep Both / Merge / Cancel. Merge must be a receipt-backed mutation, not delete-plus-create.

**(c) Share extension.** No `share-services` target exists — `project.pbxproj` has only two app extensions. Reuse `CaptureToInboxIntent`'s queue write.

**(d) Provisional drafts surviving interruption.** Local-only until applied; store in the App Group `PendingCapture` queue with a `provisional` marker rather than inventing storage.

### 7.2 Tasks and Projects — contracts exist, consumers do not

This is the largest single item. `TaskExecutionContracts.swift` is complete and unwired.

- **`ProjectMilestoneRepository`** — new file mirroring `CoreDataPlanningRepository` over the shipping `ProjectMilestone` entity (`TaskModelV3_TaskStartDay.xcdatamodel/contents:1594`). Feed `TaskExecutionProjection.projectSnapshot(...)`.
- **Backlog on `TaskExecutionQuery`.** `backlogContent` (`LifeBoardPlanViews.swift:674`) already has filters, multi-select and delete-with-undo. Retarget its fetch so `waiting`/`someday`/`completed` scopes and `SortOrder` become real; then saved-filter views over the same query.
- **Editable task detail.** `LifeOSFoundationShell.swift:2549-2576` is read-only + "Open in Plan". Make it a compact paper editor on iPhone, inspector on iPad/Catalyst. Reuse `LifeBoard/View/TaskDetailComponents.swift` and `TaskScheduleEditor.swift` rather than authoring new fields. **This is where `startDay` finally gets a writer.**
- **Project board** driven by `ProjectExecutionSnapshot` — list and board only, **no timeline/Gantt**. Surface the already-modelled `ProjectExecutionMode` via `nextAction` (:226) and `isBlocked` (:250). Keep `completionFraction` nil-not-zero.
- Project templates, reusable checklists, archive; completion-date-based recurrence alongside the scheduled-date `TaskRepeatPattern`.
- Batch schedule/tag/move/defer/complete/archive/delete — reuse `InboxTriageMutation.batch`, which already inverts correctly (last write unwinds first, all-or-nothing).
- `TaskBreakdownService` must emit **proposals**, never mutations.

### 7.3 Plan, Calendar, Capacity — mostly built

**Already good:** four `PlanLens` cases; `PlanDayTimeCanvas` (:1641) with hour grid, free-window drop targets, lane resolution, overlap clustering; `PlanBlockSnapResolver` (:313) with a real dual grid (5 min fine / 15 min coarse, switching at 30 min of travel); the four-direction Plan Repair deck (:1059) with accessibility actions; the capacity card (:548) → `PlanWorkingHoursComposer` (:2350).

**Missing:**
- **`PlanningScenario`** — absent entirely (zero hits repo-wide). Uncommitted schedule/repair previews, **local-only until Apply**, with a full diff and one Undo receipt.
- **Resize by drag.** Move exists (`LongPressGesture(0.28).sequenced(before: DragGesture)`, :2247); resize is menu-only ("Add/Remove 15 minutes", :2210). Add edge handles reusing `PlanBlockSnapResolver`; keep the button/menu/keyboard/VoiceOver equivalents.
- **Unscheduled tasks are not on the spine** — they sit in daypart lists below (:580-585), so the spine cannot answer "where is the next usable gap?" for unplanned work.
- Minimum-viable-day `PlanRepairAction` (essential care + one outcome + protected rest).
- **Surface `EstimateCalibrationSuggestion`** (`PlanningCoreModels.swift:622`, service `PlanningCoreServices.swift:379`), fed by completed focus sessions.
- Calendar freshness/permission/offline states via `PlanningCalendarAuthorization`. External events stay **read-only** and visually distinct.

### 7.4 Focus — works end to end, needs depth

**Already wired:** `FocusSessionV2` (:714), `FocusSessionCommand` (:774), `PlanStore.startFocus/pause/resume/end` → `FocusLiveActivityCoordinator.shared.synchronize`, orphan cleanup on load, session restore (`SceneDelegate.swift:497`), `activeFocusCard` (:734), `LifeBoardWidgets/FocusLiveActivityWidget.swift`.

**Add:** unscoped sessions; stopwatch/Pomodoro/open-ended alongside countdown; task/subtask checklist, intention, interruption log; post-session reflection feeding 7.3's calibration.

⚠️ **`FocusCompletionOutcome` has four cases but the plan names five outcomes** (pause / resume / abandon / finish / continue-later). Extend the enum additively or document the collapse — do not map two meanings onto one case silently.

⚠️ **A parallel legacy focus stack exists** — `LifeBoard/View/SunriseFocusZone.swift`, `SunriseFocusSessionSummaryView.swift`, `HomeViewModel+FocusSessions.swift` — and does **not** use `FocusSessionV2`. Two focus systems is a correctness risk. Converge them; do not add a third.

⚠️ `FocusLiveActivityCoordinator` declares the same actor **twice** (:89 and :166) under mutually exclusive availability branches. Verify both compile paths before extending.

### 7.5 Adaptive Home — decision quality only, do not add cards

**Already present:** `HomeContextDisposition` with all five cases (`LifeOSFoundationContracts.swift:447`); "Why this?" rendering reason + signal (`LifeBoardFoundationGallery.swift:1186`); the four disposition actions (:1189-1201); `DashboardModePolicy`; the candidate-cap contract test (`LifeOSFoundationTests.swift:3089`).

**Remaining is judgment:**
- Guarantee one Now card, one day-ahead story, **no semantic duplicates** — add a semantic-role dedup contract test, not just the count cap.
- Complete "Move to section" (the one disposition without a menu entry).
- Morning orientation / midday repair / evening close-loop as *variants of one dashboard*.
- Make Low Energy a genuine reduced-demand plan (essential care + one small achievable action), not just a section budget.
- Interacting with or repositioning an adaptive card **pins** it.
- Minimal / Balanced / Rich presets, orthogonal to Smart/Work/Personal/Low Energy.

**Exit Phase 1:** all of 7.1–7.5 pass acceptance; `daily_loop_v1` and `task_project_flagship_v1` genuinely gate their surfaces; rollback verified with `-LIFEBOARD_DISABLE_*`.

---

## 8. Phase 2 — Behaviour, Goals, Personal Care

New flag `trackBehaviorFlagshipV1Enabled`, `promotedDefaults` entry `false`, flipped at stage exit.

### The good news: the persistence already exists

`TaskModelV3_TaskStartDay` already contains `MedicationDefinition`/`Schedule`/`Event`, `TrackerDefinition`/`Entry`, `HabitDefinition`/`Group`/`ResiliencePolicy`, `ScheduleRule` (RRULE-shaped: `ruleType, interval, byDayMask, byMonthDay, byHour, byMinute`), `ScheduleException`, `ScheduleTemplate`, `RoutineDefinition`/`Step`/`Run`/`StepEvent`/`LinkedMutationReceipt`, `GoalDefinition`/`Link`, `StarterPackInstallation`. **Phase 2 is service + UI work, not a schema build-out.**

### 8.0 One additive model version — `TaskModelV3_BehaviorFlagship`

| Entity | Add |
|---|---|
| `MedicationDefinition` | `form`, `startDate`, `endDate`, refill fields |
| `TrackerDefinition` | `valueTypeRaw` (text/choice/timestamp), `rangeMin`/`rangeMax`, `aggregationRaw`, `privacyClassRaw`, `isHomeEligible` |
| `GoalDefinition` | `baselineValue`, `confidenceRaw`, `whyItMatters`, `checkInCadenceRaw`, `pausedAt`, status-history relation |
| `HabitDefinition` | quota/timed target fields (interval and selected-day are already expressible via `ScheduleRule`) |

Follow §5 exactly.

### 8.1 `BehaviorDefinition`

Shared scheduling semantics across habits and trackers **without merging their domain records**. Build over the existing `ScheduleRule` / `ScheduleException` / `ScheduleTemplate` — do **not** write a new recurrence engine.

### 8.2 Habits

`HabitCadenceDraft` (`LifeBoard/Domain/Models/HabitTypes.swift:48`) supports only `.daily` and `.weekly(daysOfWeek:)`. Against the target set: daily ✓, selected-day ✓, avoidance ✓ (`HabitKind.negative` + `lapseOnly` + `abstained`/`lapsed`), quantitative partial (`HabitTargetConfig.targetCountPerDay` + `HabitMetricConfig.unitLabel`). **Missing: interval, quota, timed.**

Also: HealthKit/tracker-backed auto-completion **only where source semantics are unambiguous**; vacations and backfill on the existing `HabitResiliencePolicy` (`offDayKeysData`, `recoveryEnabled`, `streakPresentationRaw`); 30-day grade, completion distribution, best time, recovery history; "minimum version" for low-energy days; interactive widgets and Watch completion.

UX: Day/Week/Graph lenses and daypart grouping already landed. **Streak and consistency grade get equal visual weight.** Missing / skipped / off-day / paused / explicit-zero / failed stay visually distinct. No guilt copy, no punitive red.

### 8.3 Guided Routines

Engine, immutable version snapshots (`RoutineDefinition.version`), run history, `RoutineStepKind` (task/habit/checkIn/timer/instruction/choice), `RoutineBranchOperator` and `RoutineLinkedMutationReceipt` all exist. `RoutineComposer` (`LifeBoardTrackFoundationViews.swift:1745`) and `RoutineRunner` (:1252) exist as basic forms.

Add: a real visual builder incl. branches and optional steps; the template set (morning, evening, work-start, shutdown, workout, care, custom); full-screen guided mode + Live Activity + Watch controls; pause / resume / skip-with-reason / stop / recover-interrupted-run; **linked-action exactly-once** (the receipt entity exists, so idempotency is a named test, not new storage); routine review.

### 8.4 Goals

`GoalType` is `completion / count / quantity / duration / targetDate`; the roadmap wants outcome / maintenance / milestone / cumulative / directional. **These are measurement shapes vs intent shapes — add the intent axis as a new field. Do not rewrite `typeRaw`; it would break every persisted row.**

`GoalLinkSource` already covers project/task/habit/routine/trackerMeasure. Add baseline, confidence, why-it-matters, check-in cadence, status history, pause/revise/complete/archive, and a review separating effort / outcome / evidence. "At risk" needs a transparent rule **and** sufficient data. No generic percentage for qualitative goals; absent-vs-zero is a named test.

### 8.5 Medication and Trackers — the clearest unfinished area

Both still live in the legacy sheet: `LifeBoardTrackRootView` (`LifeBoardTrackAndJournalViews.swift:326`) with `LifeBoardTrackerComposer` (:840), `TrackerHistoryView` (:931), `TrackerCorrectionView` (:985), `MedicationComposer` (:1036), `MedicationHistoryView` (:1139), `MedicationCorrectionView` (:1197). Mounted from **four** call sites: `LifeOSFoundationShell.swift:1054, 1543, 3177` and `LifeBoardTrackFoundationViews.swift:209`.

Introduce `MedicationScheduleService` and `TrackerDefinitionService`; make both **native Track Areas** under `TrackLens.areas`. **Fasting and Journal already made this exact move — follow that precedent.** Retire the legacy sheet only after all four call sites migrate.

- **Medication:** value layer already has definition/schedule/event with six statuses (`scheduled, taken, skipped, snoozed, rescheduled, unresolved`) and a `contributesToAdherence` rule; repository methods at `LifeBoardPhaseIIModels.swift:2047-2053`. Add form, start/end dates, schedule timeline, adherence history, export, reminders, opt-in refill. **No dosage advice, interaction warnings, diagnosis, or inferred adherence.**
- **Trackers:** `LifeBoardTrackerKind` is `boolean / count / quantity / rating / duration`. Add text, choice, timestamp. Then ranges, aggregation, privacy class, Home eligibility, CSV/JSON export, and templates (pain, symptoms, caffeine, reading, spending, screen time) — **without clinical claims**.

### 8.6 Wellness, Nutrition, Fasting

- **Wellness:** customizable Body dashboard; manual / Apple Health / imported source separation; workout detail, sleep timeline, body-metric trends, source conflicts; annotations for unusual days. **No universal readiness score.**
- **Nutrition:** recipes, meals, templates, favorites, recents, serving memory, grocery lists; optional remote lookup with provenance (currently off and honestly labelled — keep it that way); barcode review and duplicate handling; macro + selected micronutrient targets. Neutral language; option to hide calories.
- **Fasting:** user templates, flexible goals, corrections, history, reminders, Watch status, Live Activity. **No recommended protocols, no moralized completion, no punishment for ending early.**

---

## 9. Stages 3–8 (after Phase 2) — outline

Rollout order and new contracts, all currently **zero hits** in the codebase:

| Stage | Flag | New contracts |
|---|---|---|
| Evidence & Intelligence | `evidenceIntelligenceV1Enabled` | `EvidenceObservation`, `PersonalExperiment` |
| EVA Orchestration | `evaOrchestrationV2Enabled` | `AuthorizedContextScope`, `EvaActionProposal` |
| Global Search | `lifeBoardGlobalSearchV1Enabled` | `LifeBoardGlobalSearchIndex` |
| Continuity/Onboarding | `systemContinuityV3Enabled` | — |
| Flagship promotion | `lifeBoardFlagshipV1Enabled` | — |

**Evidence & Intelligence** must also **extract Insights out of `LifeOSFoundationShell.swift`** (`FoundationInsightsDestination`, ~440 lines at :1717) into `LifeBoard/Foundation/Insights/`. The shell is 3,720 lines; leaving it makes the file unmaintainable.

**Global Search:** two protected FTS5 indexes already exist (Journal `journal_chunks_fts`, Notes `notes_fts`). **Do not merge them.** The global index federates and owns rows only for the remaining domains, honouring each domain's authorization at query time.

**Stage 9 (shared spaces) stays a gated outline. Do not begin.**

---

## 10. Verification

Per stage, **serially**:

```bash
./scripts/run-baseline-aware-tests.sh
```
```bash
bash scripts/check-xcode-target-membership.sh && bash scripts/token-law-guardrails.sh && bash scripts/premium-ui-guardrails.sh && bash scripts/phase1-foundation-guardrails.sh
```
```bash
xcodebuild build -workspace LifeBoard.xcworkspace -scheme LifeBoard -destination 'platform=iOS Simulator,id=A2C21181-4F6B-4883-B2FF-1D1B0DB04BBF'
```
```bash
xcodebuild build -workspace LifeBoard.xcworkspace -scheme LifeBoard -destination 'platform=macOS,variant=Mac Catalyst'
```

Reading the gate's diff: `+` lines are failures **not** in the baseline (real signal); `-` lines are baseline entries that passed. With an empty baseline, any `+` is yours.

Use the dedicated simulator **`LifeBoard Test iPhone`** (`A2C21181-4F6B-4883-B2FF-1D1B0DB04BBF`). Seeded journeys go through `LifeBoard/TestingSupport/HomeUITestWorkspaceSeeder.swift` and `LifeBoardUITests/PageObjects`, **condition-based waits only, no fixed sleeps**.

**Rollback proof:** relaunch with `-LIFEBOARD_DISABLE_DAILY_LOOP_V1` etc. and confirm new presentation disappears while data created while on survives.

**Deferred to signed device** (named blockers on final promotion, never blocking an intermediate stage): performance, thermal, haptics, App Group, paired Watch, camera, microphone, biometrics, Live Activities, Metal shader warm-up, sustained frame pacing, local-model EVA.

**A stage is done when** canonical persistence + empty/loading/error/denied states + an accessibility path + contract tests + one seeded simulator journey all pass. **Not when the screen renders.**

---

## 11. Known open items and corrections

- **`LIFEBOARD_BEYOND_NOTES_HANDOFF.md` §2 is wrong about the `xcodeproj` gem.** See §2 here. Fix that line when you next touch the doc.
- **`LIFEBOARD_5_REMAINING_EXECUTION_LEDGER.md`'s Milestone 10 row claims 44 failing methods.** Stale — the gate is green. Update it.
- **The commit path has never run against real Core Data.** `InboxCommitCoordinator` is tested only against an in-memory spy. This is the single most important thing to verify next.
- **No visual/design-system audit was taken.** A planned sweep for hardcoded colours, contrast pairs and the light/dark matrix never ran. `phase1-foundation-guardrails.sh` now catches hex literals under `LifeBoard/Foundation` only — the rest of the tree is unaudited.
- **Recovery Center rebuild actions are not wired.** The button says *"Open Journal to rebuild its search index"* rather than calling `invalidate()`, which would clear without repopulating — search would get **worse**.
- **`JournalKit` is untracked in the OffRecord git repo** (`?? Packages/`) yet is a hard local package dependency of the LifeBoard app *and* Watch targets. A shared dependency that is not versioned will eventually bite.
- **Two rival focus stacks and two rival task-detail editors** coexist (§7.4, §7.2). Converge, don't extend.
- **`ProjectMilestone` has an entity and no repository.** The table is unreachable.

---

## 12. Design contract

`DESIGN.md` is authoritative: warm paper, cocoa ink, apricot, sage, atmospheric dayparts, SF Pro Text with selective SF Rounded. **The generic "vibrant block interface" recommendation from the roadmap is explicitly rejected.**

Opaque paper for reading/editing/charts/forms; Regular Liquid Glass **only** for navigation, compact filters, menus, toolbars, capture and EVA's composer. Cards only for movable modules, decisions, or independently actionable summaries — open rows and typography for ordinary grouping.

**Copy rules already encoded in code:**
- Plain language in primary copy. No "Core Data", "CloudKit", "FTS5". Internal reason tokens go to diagnostics only.
- Say what happened, not what it became. *"Added "X" to your inbox to review."*
- **Empty is a success state**: *"Inbox clear — everything you captured has somewhere to be."* A **failed load must look different from empty**; never congratulate someone for a fetch that did not complete.
- Four health states, deliberately not two (`LifeBoardRecoveryStatus.Health`): `healthy`, `working`, `attention`, `unavailable`. Conflating them is what makes recovery UI frightening.
- Anti-guilt language: "Overdue" → "rescue"; streaks → "active days".
- **Shape carries state, not just colour** — Differentiate Without Color must still distinguish healthy from degraded.

Approved signature effects are a closed list in `DESIGN.md`. Add new stitchable functions to `LifeBoard/View/Effects/LifeBoardSignatureEffects.metal` — **do not create a new `.metal` file**; `check-xcode-target-membership.sh` only scans `.swift`, so an orphaned `.metal` passes CI and then fails `LifeBoardSignatureShaders.warmUp()`, which is all-or-nothing and disables *every* effect at runtime.

---

## 13. Suggested order of work

1. **Wire the Inbox commit path and verify it in the simulator** (§7.1a). Everything else in 7.1 depends on it, and it converts four commits of contract work into a working feature.
2. Duplicate resolution UI (§7.1b) — small, high user value, contracts already exist.
3. **§7.2 Tasks and Projects.** The biggest block. Start with `ProjectMilestoneRepository` (unlocks `ProjectExecutionSnapshot`), then editable task detail (first `startDay` writer), then the board.
4. §7.3 `PlanningScenario` + resize handles + surfacing calibration.
5. §7.4 Focus depth, **converging the legacy stack first** so you extend one system.
6. §7.5 Home decision quality — mostly tests and policy, little new UI.
7. Promote `daily_loop_v1` / `task_project_flagship_v1` for real, with rollback proven.
8. Phase 2, starting with the model version (§8.0), then §8.5 medication/trackers — the clearest user-visible gap and it finally retires the 4,338-line legacy sheet.
