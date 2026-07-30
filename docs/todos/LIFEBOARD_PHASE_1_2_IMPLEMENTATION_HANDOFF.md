# LifeBoard — Phase 1 & Phase 2 Implementation Handoff

## 2026-07-29–30 completion ledger

This ledger supersedes the older point-in-time counts below while preserving
their design and migration warnings.

### 2026-07-30 UI/UX completion addendum

The Phase 1/2 UI/UX overhaul is implemented. Its canonical detailed record is
[`LIFEBOARD_UI_UX_OVERHAUL_HANDOFF.md`](LIFEBOARD_UI_UX_OVERHAUL_HANDOFF.md).
The following decisions and contracts supersede older “remaining UI work”
statements later in this document:

| Area | Final state |
|---|---|
| Home capture | One shared Life Thread composer; no duplicate header capture |
| Home defaults | Tasks, care, routines, journal, progress/reflection |
| Home customization | Transactional mode; dock/composer hidden; one Cancel/Done bar |
| Plan | Scheduled-row entrance, rolling capacity value, canonical task zoom |
| Focus | Presentation-only dial, one primary Pause/Resume action, receipt-driven outcomes |
| Track | Intrinsic AX header, one-column accessibility layout, reachable hydration/resilience |
| Track editors | Bottom safe-area commit controls driven by awaited store mutations |
| Habit | Central lens motion and bounded first-data/material-range chart reveal |
| Routine | One non-interactively-dismissible full-screen runner with explicit abandonment |
| Signature effects | 17 exact Swift/Metal functions, including `triageSettle` |
| Automation | Feature-qualified identifiers and deterministic UI-test-only Home seed |

The final UI/UX verification record on the documented working tree is:

- five targeted Foundation UI journeys pass together;
- Focus dial progress mapping and exact shader-registry tests pass;
- target membership, token-law, premium UI, Phase 1 foundation, and no-print
  guardrails pass;
- `git diff --check` passes;
- iPhone 17 Pro, iPad A16 on iOS 26.5, and Mac Catalyst builds pass.

Known non-blocking output remains the existing HealthKit `dance` deprecation,
Catalyst Metal-toolchain search-path warnings, test-target Core Data concurrency
warnings, and occasional Xcode LLDB version-store diagnostics during UI test
launch. New warnings must still be investigated.

This completion record does not claim that every release-only manual/device gate
has been executed. VoiceOver rotor/order, right-to-left layout, the complete
light/dark accessibility matrix, device haptics, lifecycle termination, and
Instruments profiling remain recommended promotion evidence.

- [x] 2026-07-30 UI-suite correction: the historical “suite is green” statement
  referred to the Swift/unit gate, not the Foundation XCUITest suite. Five
  targeted UI tests were still failing: four contained stale product
  assumptions and one exposed an AX XXXL Track layout defect. The tests now use
  the single Home composer, stable Add-to-Home/widget/lens identifiers, canonical
  Home defaults, independent navigation, and the Areas lens. Track now collapses
  to one column at accessibility sizes, uses an intrinsic header, reserves
  floating-chrome space, and keeps hydration and resilience controls reachable.
  Do not restore a second Home header capture button or treat the historical UI
  suite as previously verified.
- [x] Phase 1 and Phase 2 implementation scope is code-complete across the
  canonical app routes, persistence/services, rollback composition, widgets,
  Watch command transport, and fasting/routine Live Activities. The unchecked
  rows below are release evidence that requires executable simulator/device
  hosts or recorded visual/accessibility/performance runs; they are not
  placeholders for a parallel production implementation.
- [x] Audited the current 4,691-line WIP and confirmed the 23-model chain,
  feature rollback routes, Share Extension target, Phase 1 dependency
  composition, and native behavior route gate.
- [x] Re-ran the baseline on `LifeBoard Test iPhone`: 1,924 tests, 0 failures.
- [x] Phase 1 foundation, premium UI, token-law, target-membership, legacy
  runtime/test, and Core Data codegen guardrails pass.
- [x] Changed the baseline script default from the unavailable `iPhone 17` to
  the dedicated `LifeBoard Test iPhone`.
- [x] Added shared Watch app/widget schemes and a serialized Phase 1/2
  build-matrix script. Watch execution remains device/runtime-gated.
- [x] Checkpointed the audited foundation at commit `28559c75` before feature
  expansion.
- [x] Stage 1 contract slice: Inbox review is now a mutable
  `InboxCaptureReviewDraft`; File It no longer reparses raw text; duplicate
  comparison exposes editable title, field-source decisions, tag union, and
  explicit Keep Both/Merge/Cancel.
- [x] Stage 1 durability slice: App Group reads and read-modify-write mutations
  are file-coordinated, stable-ID retries are idempotent, queue-write failure
  compensates the canonical task mutation, and multi-capture restoration is
  atomic.
- [x] Stage 1 focused verification: 19 Inbox coordinator/queue tests pass,
  including edited-review equality, conflict acknowledgement, source
  selection, concurrent writers, compensation, merge restoration, and legacy
  JSON decoding.
- [x] Stage 1 real-persistence slice: `CoreDataInboxTaskWriter` now treats
  definition and `TaskTagLink` sidecars as one compensating mutation for
  create, delete, merge, and restore. A real in-memory Core Data journey covers
  pending-to-task merge plus exact task/tag/queue Undo restoration and compiles
  in the complete test target.
- [ ] Stage 1 remaining exit evidence: execute that real Core Data journey on a
  healthy simulator test host, add seeded process-interruption/relaunch UI
  coverage, and exercise App Group writers from every signed extension surface
  on device.
- [x] Stage 2 canonical-scope slice: `TaskExecutionStore` now feeds the
  production Inbox, Today, Upcoming, Waiting, Someday, Completed, and All
  library inside Plan; every row opens the shared canonical task route.
- [x] Stage 2 batch slice: `TaskBatchMutationCoordinator` snapshots rows,
  applies deterministic schedule/tag/move/defer/complete/archive/delete
  mutations, compensates partial definition and relationship failures, returns
  one receipt, and exposes one Undo. The production task library now provides
  selection plus 44-point Plan/Organize/Complete/Archive/Delete controls and
  VoiceOver selection actions. Four focused atomicity/Undo tests pass.
- [x] Stage 2 editor-contract slice: one `TaskEditorDraft` now carries the
  complete task and planning state submitted by every canonical task route.
  The editor adds life area, section, scheduled end, ordered subtasks,
  dependency cycle rejection, and daily/weekday/weekly/biweekly/monthly/
  yearly/custom recurrence controls with scheduled/completion anchors. Parent
  and child writes are one compensating transaction: every changed
  `parentTaskID`, the parent's ordered subtask array, relationship sidecars,
  planning data, save, and Undo restore together.
- [x] Stage 2 template-service slice: archived project template sources are
  deep-copied through `ProjectTemplateInstantiationService`, with complete
  project/section/task/milestone/dependency ID maps, hierarchy/tag/dependency
  remapping, stable recurrence-series remapping, graph-leak rejection,
  manual planning-order copying, compensating rollback, and Undo. Plan now
  exposes a 44-point template picker, editable destination name, creation
  receipt, Undo, and Open action. Project rows and the multi-select task library
  expose explicit project-section movement through the same atomic batch
  coordinator. Two focused graph/order identity tests plus four batch
  atomicity tests pass; the Debug simulator build succeeds.
- [x] Stage 2 route/persistence closure: one real in-memory Core Data journey
  covers schedule, tag, move, defer, complete/reopen, archive, delete, and Undo.
  Home, Plan, project, Inbox, search, notification, and deep-link task opens now
  converge on the canonical task route while Phase 1 is enabled; the Sunrise
  editor remains reachable only from the explicit rollback/onboarding path.
  `PlanFeatureDependencies` and canonical focus/task handlers are no longer
  composed when either Phase 1 rollback flag is disabled.
- [ ] Stage 2 remaining exit evidence: execute the compiled real Core Data
  journey on a healthy simulator test host and capture the seeded
  project-template/batch UI journey.
- [x] Stage 3 scenario/control slice: Minimum Viable Day, repair actions, and
  multi-item rescheduling now remain local `PlanningScenario` previews until
  Apply. MVD refuses partial care/outcome/rest composition and exposes a compact
  chooser; version conflicts rebuild the same scenario source/parameters,
  display the previous diff, and require a second explicit Apply. Repair
  receipt sources remain proposal-specific so acknowledgement suppression and
  Undo continue to work.
- [x] Stage 3 schedule-context slice: calendar context has typed not-requested,
  denied, loading, fresh, stale-cache, offline-cache, and failed states; stale
  commitments are retained and labeled. Fits Next now pairs each task with
  every specific eligible gap. Resize edges use the 15-minute grid except
  within 7.5 minutes of a real neighboring boundary, where five-minute
  correction activates; live geometry has no animated lag.
- [x] Stage 3 calibration slice: completed canonical focus history produces an
  estimate suggestion only after three sessions of at least five minutes,
  showing median, observed range, and sample count. Acceptance explicitly
  updates the canonical task estimate. The Debug simulator build and 220
  Plan/foundation tests pass; the final focused Stage 3 run contains 29 tests,
  0 failures.
- [ ] Stage 3 remaining exit evidence: seeded UI page-object journeys for
  conflict refresh, both resize alternatives, Fits Next, MVD selection,
  calendar cache/error states, and calibration acceptance.
- [x] Stage 4 canonical-focus slice: Phase 1 Home and Plan starts now share
  `FocusSessionCommands` over `FocusSessionV2`; the legacy Home timer models
  are presentation adapters only while the rollback route retains the old
  writer. Canonical completion publishes one durable `FocusExecutionReceipt`
  stream, and XP is an idempotent post-persistence subscriber keyed by the
  canonical session ID.
- [x] Stage 4 focus-depth slice: countdown, stopwatch, editable Pomodoro, and
  open-ended setup are reachable from task, block, and unscoped starts.
  Pomodoro round/phase, intention, checklist, and timestamped interruptions
  live in the seven-day companion record. Countdown expiry pauses for an
  explicit Finish/Continue Later/Abandon decision instead of inferring
  completion. Plan includes stable timer numerals, explicit interruption
  reasons, phase advancement, and a short energy/note reflection showing
  actual versus planned duration.
- [x] Stage 4 Home-judgment slice: semantic roles deduplicate before the cap,
  an available primary action deterministically owns Now, only one day-ahead
  story survives, and Low Energy projects essential care plus one explicitly
  smaller action. Context actions, edits, resizes, and manual repositioning
  pin through existing placement persistence; Move to Section remains
  available. Newly audited action controls meet the 44-point minimum.
- [x] Stage 4 focused verification: Debug simulator build succeeds and the
  combined LifeOS/focus foundation suites pass, including Pomodoro relaunch,
  interruption, terminal receipt, reflection persistence, primary-Now, and
  day-ahead invariants.
- [x] Stage 4 Live Activity compile closure: Debug and Release iOS compile the
  ActivityKit implementation while Catalyst compiles the non-ActivityKit
  fallback in the same serialized matrix.
- [ ] Stage 4 remaining exit evidence: execute the implemented Watch commands
  on a paired Watch runtime/device and capture seeded VoiceOver/large-type Home
  and focus journeys.
- [x] Stage 6 occurrence-identity slice: regenerated behavior occurrences use
  `BehaviorOccurrenceIdentity`, a deterministic UUID derived from behavior,
  canonical key, timezone, and sequence. Repeated generation retains the same
  rows and identifiers, exception rebuilds preserve unaffected identities, and
  projections distinguish missing, explicit zero, completed, skipped, off-day,
  paused, failed, and unresolved. Focused identity/exception tests pass.
- [x] Stage 6 single-model schema slice: the still-unshipped
  `TaskModelV3_BehaviorFlagship` remains the sole additive model and now
  includes recipe, ingredient, meal-template, grocery-list, serving-memory,
  nutrition-preference, and fasting-template persistence plus log provenance
  and session-template linkage. XML, current-model/configuration assertions,
  and Core Data codegen guardrails pass.
- [x] Stage 6 migration-fixture slice: the all-predecessor migration test now
  seeds every domain a source model actually contains rather than proving only
  a `LifeArea` row. It preserves Habit target payload/type/streak meaning,
  Tracker definition plus explicit-zero numeric/boolean/note columns,
  Medication definition/schedule/unresolved-event relationships, and Goal
  measurement shape/target/unit while retaining stable IDs. Models predating a
  domain skip only that unavailable fixture; the discovered 22-model chain
  remains authoritative.
- [x] Stage 6 cross-surface payload slice: task-list snapshot schema 7 carries
  one backward-compatible `BehaviorOccurrenceSurfaceSnapshot` for app,
  widgets, Watch, reminders, and history. It preserves the canonical
  occurrence row ID/key, behavior/template IDs, domain, scheduled/due time,
  timezone, and the complete missing/explicit-zero/completed/skipped/off-day/
  paused/failed/unresolved vocabulary. Widget refresh uses the canonical
  schedule and occurrence repositories; consumers do not regenerate IDs.
  Schema-5 snapshots decode without inventing occurrences, and projection/
  round-trip contracts compile in the complete test target.
- [x] Stage 6 iOS widget-action slice: `StreakResilienceWidget` is now mounted
  in the widget bundle and reads the canonical Habit plus behavior-occurrence
  snapshot instead of unrelated gamification totals. Its completion App Intent
  writes the canonical occurrence/behavior IDs; Home applies the command
  through `ResolveOccurrenceUseCase`, clears expired/already-resolved commands,
  and refreshes all snapshots after success. Resolution receipt IDs are
  deterministic per occurrence/result, so repeated extension delivery upserts
  the same Core Data receipt instead of duplicating history. Main app,
  standalone widget, and complete test-target builds succeed.
- [x] Stage 6 Watch action slice: Watch renders a 44-point completion action
  from the canonical behavior-occurrence snapshot and transports the same
  `BehaviorOccurrenceActionCommand` used by widgets. The phone validates flag,
  expiry, behavior/occurrence identity, and unresolved snapshot state before
  calling the canonical resolver, then refreshes snapshots. Transport
  round-trip and schema-rejection contracts compile; Watch sources also pass a
  standalone Swift parser check.
- [x] Stage 8/9 active-session parity slice: task-list snapshot schema 7 adds
  optional, backward-compatible canonical fasting and routine projections.
  Watch renders target/elapsed fasting state plus End/Cancel and routine
  step/progress plus Pause/Resume/Stop, all with 44-point actions. Commands
  carry canonical session/run identity, expiry, and schema; the phone validates
  the enabled Phase 2 route and current snapshot identity before invoking
  `FastingTimerStore` or `DefaultRoutineExecutionService`, then republishes the
  snapshot. Every canonical system-surface mutation also invalidates the task
  snapshot, so in-app starts/finishes reach Watch without waiting for an
  unrelated task refresh. Older snapshots decode both projections as nil.
- [x] Stage 8/9 ActivityKit slice: canonical fasting and routine stores now
  create, update, restore, and end their own Live Activities. Deep-link
  commands expose only explicit Finish/Cancel for fasting and lifecycle-only
  Pause/Resume/Stop for routines. The routine start path was also corrected to
  persist before publishing in-memory active state.
- [x] Stage 7 service-boundary slice: both legacy/native Track stores route
  tracker definitions/entries and medication definitions/schedules/events,
  corrections, snooze compensation, archive, and delete through
  `TrackerDefinitionService` / `MedicationScheduleService`. A real Core Data
  test proves invalid range, sensitive-Home, and active-date mutations are
  rejected before any repository row is written.
- [x] Stage 7 native-workflow slice: tracker creation now edits all eight
  tagged value shapes, optional ranges, type-appropriate aggregation, privacy
  class, explicit sensitive-Home authorization, choice membership, schedule,
  reminder, and Home eligibility through the validation service. One typed
  capture/correction sheet serves both native and rollback roots, preserves
  legacy scalar columns, rejects non-finite/out-of-range values, and prepares
  protected CSV/JSON exports with provenance. Six neutral templates create
  fresh definitions; pain and symptom templates are visibly non-clinical and
  sensitive by default.
- [x] Stage 7 medication-workflow slice: the native editor persists form,
  optional active dates, schedule window, weekdays, reminder state, and
  opt-in refill quantity/remaining/threshold/last-refill state. Schedule
  validation is preflighted before definition persistence. Native rows expose
  Taken, Skipped, Snoozed, Rescheduled, Unresolved, full correction/history,
  protected export, archive, and delete while retaining neutral informational
  copy and never inferring a decision from silence. Ordinary definitions use
  open rows rather than repeated raised cards, and all audited controls meet
  the 44-point minimum.
- [x] Stage 8 goal-contract slice: `GoalDraft` carries independent intent,
  baseline, confidence, why, cadence, evidence links, effort, and outcome.
  One lifecycle service normalizes definitions, appends immutable
  date-and-ID-ordered status events, and makes reversible transitions append a
  compensating event rather than deleting history. Assessment returns nil for
  absent evidence, limits percentages to quantitatively meaningful goals, and
  requires two missed check-ins or a meaningful four-sample/seven-day
  trajectory before At Risk. Focused goal lifecycle/assessment tests pass.
- [x] Stage 8 goal-workflow slice: the native composer now edits intent,
  baseline, confidence, why-it-matters, and check-in cadence in addition to
  measurement shape. Goal rows show intent/status and expose explicit
  pause/resume/revise/complete/reactivate/archive transitions. Each transition
  keeps immutable history, returns one receipt, and presents a one-tap Undo
  that appends a compensating status event.
- [x] Stage 8 routine-contract slice: the existing routine engine now validates
  duplicate ordinals/IDs, missing links and destinations, unreachable steps,
  branch loops, and invalid choice graphs before save. Morning, evening,
  work-start, shutdown, workout, and care templates ship through one catalog.
  Runs retain immutable version snapshots and durable paused/interrupted state;
  pause, resume, skip-with-reason, interrupt, and stop commands preserve
  exactly-once linked mutations. The production simulator build succeeds and
  the four new routine recovery/validation tests compile in the full test
  target.
- [x] Stage 8 habit-contract slice: `HabitTarget` now supports binary,
  avoidance, quantitative, quota-window, and timed targets with a compatible
  low-energy minimum and service-boundary validation. Interval cadence is
  encoded through the existing daily schedule rule and is editable in both
  create and canonical detail flows. `HabitResiliencePolicy` now persists
  intentional off-days, vacation ranges, correction windows, recovery
  receipts, and minimum targets in the existing metadata column. Habit
  evidence and 30-day grading distinguish missing, explicit zero, partial,
  completed, abstained, lapsed, skipped, off-day, paused, failed, unresolved,
  and recovered states; auto-completion accepts only one source/threshold
  mapping to one occurrence. The generic simulator build and complete
  test-target build succeed.
- [x] Stage 9 nutrition/fasting persistence slice: recipes retain ingredient
  and nutrition snapshots; meal templates instantiate compensating log
  batches with provenance; grocery generation, favorites/recents,
  serving-memory, calorie hiding, macro/micronutrient preferences, correction
  receipts, and Undo are repository-backed. User fasting templates feed the
  one canonical timer actor, sessions retain template identity, early ending
  stays neutral, and corrections are reversible. Three focused real Core Data
  journeys and two snapshot/Undo contract tests pass.
- [x] Stage 9 barcode-review slice: barcode scans are local-first and now open
  a provenance review before logging. A saved match retains its stable food
  ID, barcode, source, favorite state, and external reference instead of being
  recreated as a manual item. The optional remote lookup contract is disabled
  by default, accepts only an explicit request when enabled, presents local
  and online candidates side by side, never merges/replaces silently, and
  records `barcodeLocal`/`barcodeRemote` provenance plus source reference in
  the immutable log snapshot. Local-only, policy-denied, duplicate, explicit
  selection, and cancel contracts compile in the complete test target.
- [x] Stage 9 Wellness workflow slice: Body metrics now have persisted enabled
  metrics, manual ordering, and compatible preferred units. Close-in-time
  readings from different sources are reviewed side by side; choosing a
  preferred projection never rewrites manual, Health, Watch, or imported
  history. Body/workout/sleep annotations are visible, ordinary history uses
  open rows instead of nested raised cards, and the store carries typed
  not-requested/denied/loading/no-samples/fresh/stale/offline/failed states.
  Preference and source-conflict contracts compile with the complete test
  target.
- [ ] Stage 6 remaining exit evidence: execute the richer 22-predecessor
  migration fixture on a healthy simulator test host, complete DST/quota/
  vacation/backfill scheduling semantics in consumer journeys, run the Watch
  action on a paired device/runtime, and prove byte-identical reminder/history
  consumption of the shared payload.
- [ ] Stage 7/9 remaining exit evidence: seeded native medication/tracker
  create → resolve → correct → export journeys, reminder/device delivery,
  an enabled remote-provider integration journey for barcode duplicate review,
  paired-device Watch/Live Activity fasting execution, live permission/cache
  provenance wiring for Wellness, and the permission/offline/accessibility/
  visual matrices.
- [ ] Stage 8 remaining exit evidence: simulator execution of the newly
  compiled routine/Habit focused tests is currently blocked before test-host
  launch by the local Xcode simulator service (the same stall reproduces with
  `test-without-building`). The canonical widget and Watch Habit actions now
  share identity and command transport; routine Live Activity and Watch
  lifecycle controls are implemented. Paired-device parity remains a device
  gate. Still required: full Goal setup/review UI journeys and seeded
  interruption/relaunch coverage.
- [ ] Phase 1 exit blockers: the remaining Stage 1/2 evidence, scenario
  conflict UI evidence, seeded daily-loop UI coverage, and the complete
  accessibility/visual/performance matrices.
- [ ] Phase 2 exit blockers: executable simulator evidence for the compiled
  domain tests, full seeded goal/personal-care UI journeys, paired-device
  cross-surface parity, visual/accessibility/performance evidence, and
  device-only gates.

### Verification policy

Run `./scripts/run-baseline-aware-tests.sh`, all guardrails, then
`./scripts/run-phase1-phase2-build-matrix.sh`. Never run two `xcodebuild`
processes concurrently. Record device-only results separately.

Latest local verification for the Stage 7/8/9 slices: generic Debug simulator
build succeeds after the native medication/tracker expansion, and the full
`LifeBoardTests` target build succeeds with tagged-value, schedule-preflight,
template-identity, routine, Habit, Wellness, nutrition, and fasting contracts.
XML and `git diff --check` passed before this slice and all seven guardrails
passed; re-run them after the next cross-surface slice. Focused simulator test
execution still stalls before test-host launch in the local Xcode simulator
service; newly compiled tests have not been marked as executed.

The subsequent Stage 6 cross-surface/migration slice also passes complete
test-target compilation. A focused `test-without-building` attempt again
stalled before the test host emitted any test case and was terminated after
one minute; this remains recorded as local simulator infrastructure, not a
product failure.

After the shared snapshot schema moved to version 6, the standalone
`LifeBoardWidgets` scheme builds successfully for the generic iOS simulator.
The shared `LifeBoardWatchWidgets` scheme resolves correctly but cannot build
on this host because the watchOS 26.5 platform/runtime is not installed; Xcode
reports only the missing platform destination. All seven guardrails,
BehaviorFlagship XML validation, and `git diff --check` pass after the native
Track, behavior-policy, migration, and barcode-review slices.

Final 2026-07-29 local verification after routine/fasting cross-surface parity:
the complete `LifeBoardTests` bundle builds and signs, all seven guardrails
pass, the BehaviorFlagship XML is valid, and `git diff --check` passes. The
serialized build matrix produces five successful builds: Debug iOS, standalone
widgets, standalone Share Extension, Release iOS, and Catalyst. The shared
Watch app and Watch-widget schemes resolve, and the edited Watch sources pass
`swiftc -frontend -parse`; their builds are skipped because no watchOS
simulator runtime/platform is installed. Three focused test-execution retries,
including after a dedicated-simulator reset and local signing, stalled while
Xcode waited for the test worker to materialize before any test case started.
The compiled tests are therefore not misclassified as executed or failed.

The final accessibility/performance sweep gives Plan resize handles stable
automation identifiers while preserving their 44-point hit regions, expands
Nutrition's dismiss target to 44 points, and removes a perpetual decorative
Health sync `TimelineView`. Phase 2 native roots and leaf routes now mount only
while `trackBehaviorFlagshipV1Enabled`; disabling it restores the legacy Track
root without deleting or rewriting behavior data.

Final 2026-07-30 configuration verification after canonical system-surface
snapshot invalidation: Debug iOS, Release iOS Simulator (whole-module
optimization), and Debug Mac Catalyst all build successfully. The Release build
emits only the pre-existing `HKWorkoutActivityType.dance` deprecation warning;
Catalyst emits the existing missing Metal-toolchain search-path warning and
still links and validates successfully. The complete test bundle remains
buildable/signable, all seven guardrails pass, the BehaviorFlagship XML is
valid, and `git diff --check` is clean. Test execution remains blocked before
the first test case by local simulator worker materialization, and Watch
typechecking/runtime execution remains blocked by the absent watchOS 26.5
platform/runtime; neither external gate is recorded as a product failure or a
pass.

**Date:** 2026-07-28
**Branch:** `lifeOS` (head `f91af671`)
**Supersedes as the active tracker:** `LIFEBOARD_BEYOND_NOTES_HANDOFF.md` (still accurate except where noted in §2 and §11)
**Audience:** the engineer picking this up cold

---

## 1. Read this first

### The Swift/unit suite was green; the UI suite had a separate stale baseline.

```
LifeBoardTests: 1917 executed, 3 skipped, 0 failures
scripts/lifeboard-test-failure-baseline.txt: 0 bytes
```

The recorded Swift/unit gate and guardrails passed at that point, but this did not
establish that the Foundation XCUITest suite was green. Five targeted UI failures
were later reproduced: four stale expectations and one real AX XXXL Track defect.
Those contracts and layouts were repaired in the 2026-07-30 UI overhaul. Keep the
failure baseline empty; investigate new failures rather than normalizing them.

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

## 7. Phase 1 — Historical 2026-07-28 gap analysis

This section preserves the investigation that informed later implementation.
Its “Done,” “Missing,” and “Next” labels are point-in-time notes, not the current
status. The completion ledger above and the final UI/UX handoff supersede them.

### 7.1 Capture and Inbox — historical status

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

### 7.2 Tasks and Projects — historical status

This is the largest single item. `TaskExecutionContracts.swift` is complete and unwired.

- **`ProjectMilestoneRepository`** — new file mirroring `CoreDataPlanningRepository` over the shipping `ProjectMilestone` entity (`TaskModelV3_TaskStartDay.xcdatamodel/contents:1594`). Feed `TaskExecutionProjection.projectSnapshot(...)`.
- **Backlog on `TaskExecutionQuery`.** `backlogContent` (`LifeBoardPlanViews.swift:674`) already has filters, multi-select and delete-with-undo. Retarget its fetch so `waiting`/`someday`/`completed` scopes and `SortOrder` become real; then saved-filter views over the same query.
- **Editable task detail.** `LifeOSFoundationShell.swift:2549-2576` is read-only + "Open in Plan". Make it a compact paper editor on iPhone, inspector on iPad/Catalyst. Reuse `LifeBoard/View/TaskDetailComponents.swift` and `TaskScheduleEditor.swift` rather than authoring new fields. **This is where `startDay` finally gets a writer.**
- **Project board** driven by `ProjectExecutionSnapshot` — list and board only, **no timeline/Gantt**. Surface the already-modelled `ProjectExecutionMode` via `nextAction` (:226) and `isBlocked` (:250). Keep `completionFraction` nil-not-zero.
- Project templates, reusable checklists, archive; completion-date-based recurrence alongside the scheduled-date `TaskRepeatPattern`.
- Batch schedule/tag/move/defer/complete/archive/delete — reuse `InboxTriageMutation.batch`, which already inverts correctly (last write unwinds first, all-or-nothing).
- `TaskBreakdownService` must emit **proposals**, never mutations.

### 7.3 Plan, Calendar, Capacity — historical status

**Already good:** four `PlanLens` cases; `PlanDayTimeCanvas` (:1641) with hour grid, free-window drop targets, lane resolution, overlap clustering; `PlanBlockSnapResolver` (:313) with a real dual grid (5 min fine / 15 min coarse, switching at 30 min of travel); the four-direction Plan Repair deck (:1059) with accessibility actions; the capacity card (:548) → `PlanWorkingHoursComposer` (:2350).

**Missing:**
- **`PlanningScenario`** — absent entirely (zero hits repo-wide). Uncommitted schedule/repair previews, **local-only until Apply**, with a full diff and one Undo receipt.
- **Resize by drag.** Move exists (`LongPressGesture(0.28).sequenced(before: DragGesture)`, :2247); resize is menu-only ("Add/Remove 15 minutes", :2210). Add edge handles reusing `PlanBlockSnapResolver`; keep the button/menu/keyboard/VoiceOver equivalents.
- **Unscheduled tasks are not on the spine** — they sit in daypart lists below (:580-585), so the spine cannot answer "where is the next usable gap?" for unplanned work.
- Minimum-viable-day `PlanRepairAction` (essential care + one outcome + protected rest).
- **Surface `EstimateCalibrationSuggestion`** (`PlanningCoreModels.swift:622`, service `PlanningCoreServices.swift:379`), fed by completed focus sessions.
- Calendar freshness/permission/offline states via `PlanningCalendarAuthorization`. External events stay **read-only** and visually distinct.

### 7.4 Focus — historical gap list; UI depth is now implemented

Current UI update: Focus now has a presentation-only dial, one primary
Pause/Resume action, a secondary command menu, receipt-driven end outcomes, and
receipt-driven reflection. The dial’s elapsed mapping is unit-tested. A failed
end command cannot mark the companion completed. The legacy-stack convergence
warning below remains architecturally relevant.

**Already wired:** `FocusSessionV2` (:714), `FocusSessionCommand` (:774), `PlanStore.startFocus/pause/resume/end` → `FocusLiveActivityCoordinator.shared.synchronize`, orphan cleanup on load, session restore (`SceneDelegate.swift:497`), `activeFocusCard` (:734), `LifeBoardWidgets/FocusLiveActivityWidget.swift`.

**Add:** unscoped sessions; stopwatch/Pomodoro/open-ended alongside countdown; task/subtask checklist, intention, interruption log; post-session reflection feeding 7.3's calibration.

⚠️ **`FocusCompletionOutcome` has four cases but the plan names five outcomes** (pause / resume / abandon / finish / continue-later). Extend the enum additively or document the collapse — do not map two meanings onto one case silently.

⚠️ **A parallel legacy focus stack exists** — `LifeBoard/View/SunriseFocusZone.swift`, `SunriseFocusSessionSummaryView.swift`, `HomeViewModel+FocusSessions.swift` — and does **not** use `FocusSessionV2`. Two focus systems is a correctness risk. Converge them; do not add a third.

⚠️ `FocusLiveActivityCoordinator` declares the same actor **twice** (:89 and :166) under mutually exclusive availability branches. Verify both compile paths before extending.

### 7.5 Adaptive Home — historical gap list

Current UI update: production defaults remain curated, global chrome yields
during transactional customization, widget controls have stable identifiers,
and the UI-test workspace can seed one deterministic user-space widget without
changing production defaults. The semantic-dedup and decision-quality guidance
below remains valid.

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

## 8. Phase 2 — Historical 2026-07-28 gap analysis

This section is retained for domain-model rationale and constraints. The
completion ledger records the later native implementations. Treat “Add” and
“Missing” language as historical unless it also appears in the current release
ledger.

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

Current UI update: both runner entry points now use one full-screen route with
interactive dismissal disabled. Running, paused, and interrupted states expose
explicit End; abandonment is confirmed through the canonical mutation;
Continue/Resume is primary; step transitions crossfade under Reduce Motion; and
the runner uses persisted active-run state.

### 8.4 Goals

`GoalType` is `completion / count / quantity / duration / targetDate`; the roadmap wants outcome / maintenance / milestone / cumulative / directional. **These are measurement shapes vs intent shapes — add the intent axis as a new field. Do not rewrite `typeRaw`; it would break every persisted row.**

`GoalLinkSource` already covers project/task/habit/routine/trackerMeasure. Add baseline, confidence, why-it-matters, check-in cadence, status history, pause/revise/complete/archive, and a review separating effort / outcome / evidence. "At risk" needs a transparent rule **and** sufficient data. No generic percentage for qualitative goals; absent-vs-zero is a named test.

### 8.5 Medication and Trackers — historical gap list

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

### Current UI/UX overhaul gate (2026-07-30)

Run the following after any change to the revised surfaces:

```bash
./scripts/check-xcode-target-membership.sh
./scripts/token-law-guardrails.sh
./scripts/premium-ui-guardrails.sh
./scripts/phase1-foundation-guardrails.sh
./scripts/check-no-print-logs.sh
```

Focused contracts:

```bash
xcodebuild \
  -project LifeBoard.xcodeproj \
  -scheme LifeBoard \
  -destination 'platform=iOS Simulator,id=A2C21181-4F6B-4883-B2FF-1D1B0DB04BBF' \
  test \
  -only-testing:LifeBoardTests/LifeOSFoundationTests/testFocusDialProgressUsesElapsedFractionAndClampsDomainEdges \
  -only-testing:LifeBoardTests/LifeOSFoundationTests/testSignatureShaderRegistryExactlyMatchesMetalDeclarations
```

Targeted UI regression set:

```text
testAdaptiveHomeCustomizationCancelAndComposerHandoff
testFoundationCompactChromeRemainsReadableAcrossScrollAndCapture
testFoundationHabitResilienceThirtyDayEditorAtLargestAccessibilitySize
testAddToHomeUsesSizePreviewAndProducesUndoReceipt
testFoundationHomeExposesCompletePhaseIIHierarchy
```

Build iPhone, iPad, and Catalyst serially. The dedicated test devices used for
the final pass were:

```text
LifeBoard Test iPhone
A2C21181-4F6B-4883-B2FF-1D1B0DB04BBF

LifeBoard Test iPad (iPad A16, iOS 26.5)
DB626ACE-A9C1-4163-98E2-A4EF68C869F1
```

Do not add `-DISABLE_ANIMATIONS` to Foundation UI tests. It disables UIKit’s
scroll animation machinery and makes real reachability assertions fail.

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

The bullets below are the original 2026-07-28 snapshot and are retained for
historical architecture context. They are not the active UI/UX work list. In
particular, Inbox commit wiring, the Phase 1/2 UI overhaul, AX XXXL Track, Focus
depth, Routine full-screen behavior, and shader registry enforcement were
subsequently implemented. Use the completion ledger and the final UI/UX handoff
for current status.

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

## 13. Historical suggested order of work

This sequence records the plan at the 2026-07-28 handoff. Do not restart it as a
current backlog: multiple steps were completed by the later Phase 1/2 slices and
the UI/UX overhaul. Derive new work from current code, test results, and the
remaining release-evidence gates.

1. **Wire the Inbox commit path and verify it in the simulator** (§7.1a). Everything else in 7.1 depends on it, and it converts four commits of contract work into a working feature.
2. Duplicate resolution UI (§7.1b) — small, high user value, contracts already exist.
3. **§7.2 Tasks and Projects.** The biggest block. Start with `ProjectMilestoneRepository` (unlocks `ProjectExecutionSnapshot`), then editable task detail (first `startDay` writer), then the board.
4. §7.3 `PlanningScenario` + resize handles + surfacing calibration.
5. §7.4 Focus depth, **converging the legacy stack first** so you extend one system.
6. §7.5 Home decision quality — mostly tests and policy, little new UI.
7. Promote `daily_loop_v1` / `task_project_flagship_v1` for real, with rollback proven.
8. Phase 2, starting with the model version (§8.0), then §8.5 medication/trackers — the clearest user-visible gap and it finally retires the 4,338-line legacy sheet.
