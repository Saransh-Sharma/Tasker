# Performance remediation — implementation and evidence

Preserve visible motion, Metal effects, live values, navigation and accessibility.
Existing workspace modifications are user-owned. No device improvement is claimed
until paired Release measurements pass with animation and shaders verified active.

## Implementation TODO

- [ ] Measurement: animation-enabled launcher, Release scheme, policy readiness, root generations and metrics.
- [ ] Data: bounded repository reads, shared domain maintenance and immutable Home projections.
- [ ] Refresh: shared task ownership, merged invalidations, mutation ordering and privacy barriers.
- [ ] Derivation: pure Home mapper, complete render-plan inputs, presentation equality and layout revisions.
- [ ] Motion: visible leaf cadence, phase continuity, finite effect cleanup.
- [ ] Insights: cached interpretation, explicit time invalidation, lazy evidence and deep links.
- [x] Memory/search implementation: immutable provider captures, 32-query cap, background preparation and stale-work rejection. Long-session memory profiling remains pending.
- [x] Restoration: synchronous sequence assignment and ordered background flush; out-of-order regression tests pass.
- [x] Focused correctness tests and Debug build (latest: 104 unit tests in `hydration-subscription-4`; shared capture and navigation passed Release `release-9`; older suite counts overlap and must not be added).
- [ ] Release build and functional/visual simulator diagnostics.
- [ ] Physical-device baseline/candidate traces and motion parity.

## Evidence

| Item | Evidence | Label |
|---|---|---|
| Home provider ownership | Immutable captures; populated registry deallocation test passes | **automated correctness verified** |
| Home mutation completion | Tasks/undo, hydration and mood await their narrow projections; suspended providers and concurrent hydration regression pass | **automated correctness verified** |
| External source changes | Container-local save revisions; Home Plan and Track reject relevant stale reads | **automated correctness verified** |
| Track queries | Bounded tracker reads and journal summary parity at exclusive date boundaries | **automated correctness verified** |
| Hero settle timeline | A completed effect previously retained its timeline; finite cleanup added and hosted cleanup test passes | **source-confirmed defect** |
| Layout performance | Pure packing/reference parity passes through 500 cards; actual geometry, accessibility and rendering cost remain unmeasured | **unproven hypothesis** |
| CPU/GPU/hitches/memory/energy | No paired physical-device traces; no trace-confirmed bottleneck or demonstrated improvement | **unproven hypothesis** |

No item currently has the **trace-confirmed bottleneck** label. Correctness tests
and source-confirmed unnecessary work do not establish measured performance gains.

The sections below retain historical stage results. The latest execution entry is
at the end of this file; older “pending” statements describe their own checkpoint.

## Acceptance protocol

Use the oldest supported iPhone and a ProMotion iPhone, with iPad supplementary.
Record build/fixture revision, OS, power/thermal/accessibility policy and actual
display cadence. Five paired runs per steady workload; 100 warm selections and
30 cold mounts. Separate process launch, first content and control readiness.
Measure CPU/SwiftUI, GPU, memory and energy separately. Exclude setup/readiness
waits from measured scrolling. Test 500-row roots, long history, invalidation
bursts, active timers, search, streaming Eva and repeated navigation.

Gates: warm p95 <=100 ms, cold p95 <=300 ms; no >=100 ms unresponsive interval;
hitches <=5 ms/s; target 50% hitch improvement above measurement noise; maximum
Home steady-scroll CPU time >=30% lower; peak memory regression <=10%; retained
objects plateau. Preserve 60/120 Hz interaction deadlines and existing ambient
cadences. Screenshots AND motion recordings must preserve appearance and timing.
Invisible UI produces no recurring presentation work; domain work stays correct.

## Current implementation evidence (2026-09-06)

- Debug simulator: 127 tests passed across ComposerCompressionPolicyTests,
  LifeBoardPlanningTrackFoundationTests and WeeklyPlanningWorkspaceTests.
  Result: `/tmp/lifeboard-performance-domain-2.xcresult`.
- Bounded-query parity test passed against the shipping Core Data model.
  Result: `/tmp/lifeboard-performance-ui-1.xcresult` (the separate UI test in
  that bundle failed because its dock query matched two accessibility elements).
- Animation-enabled UI launch reached the policy-ready marker: token motion,
  UIKit animations, shader library readiness, Balanced comfort and ambient2D.
  This does **not** establish first actual Metal rendering or visual parity.
- The repository round-trip fixture reused a background-context object after
  seven external writes. It now refreshes that test object before its next write;
  no production merge policy was relaxed.
- Search review caught query-count pruning placed only on source invalidation;
  pruning now also runs after every query commit. Full repeated-search coverage
  remains pending.

## Stage details and remaining work

- Measurement implemented: opt-in animation flag with explicit-disable precedence,
  Release test scheme, policy marker, synchronous root generations, separate
  completed/superseded/failed outcomes and changed-presentation events.
  Pending: verify primary-control probe on every retained root/depth, first usable
  content vs interaction timing, first actual effects, complete repository/row and
  active-timeline counters, export paired distributions.
- Data implemented: Home uses an actor reading immutable input values and a shared
  pure day mapper; Track uses bounded tracker/journal evidence queries; repair
  acknowledgment lookup is batched. Application-owned maintenance handles default
  profile creation, focus recovery, medication reconciliation and Live Activities,
  with foreground/deadline/durable-mutation triggers.
  Pending: cross-root in-flight query sharing, source revisions, strict provider
  concurrency across domain reads, lens-specific history paging, maintenance
  lifecycle tests for every alternate presentation host.
- Refresh implemented: shared producer ownership for Plan/Track/Home, merged Home
  events, mutation and privacy generation barriers, warm loading, atomic Plan and
  Track publication, presentation equality. Optional cards retain prior values.
  Pending: independent failure/freshness reporting for every optional domain and
  comprehensive suspended-provider races; automatic height/reorder stabilization
  while scrolling and accessibility focus preservation are not complete.
- Derivation implemented: pure Home transaction mapping, stored render plans,
  candidate/configuration/calendar/locale/type/privacy inputs, explicit layout
  shape revisions and no-op snapshot equality. SwiftUI updateCache remains
  authoritative. Pending: equatable dashboard child, full frame-planner reference
  suite and Dynamic Type/async-content layout reproduction.
- Motion implemented: viewport/scene/root-aware leaf timeline wrappers, pushed-root
  gating, preserved atmosphere sample time, generation-aware finite-effect cleanup.
  Pending: cover visibility, transition-tail recordings, active-timeline counters
  and device GPU/energy traces. No shader math or visible cadence was reduced.
- Insights implemented: cached interpretation/evidence/source counts, significant
  time invalidation, direct lazy evidence rows and a layout-triggered one-time
  deep-link scroll. Pending: visual verification of contiguous styling, history
  paging and robust target loading for records outside the selected lens.
- Whole-app pending: long Eva streaming transcript, media/sprite/cache pressure,
  actual startup readiness replacing discretionary fixed delays, full 500-row
  benchmark fixtures and complete functional/accessibility/visual validation.
- MetricKit now records CPU, launch and responsiveness histogram data alongside
  existing hitch/memory/exit telemetry. Delivery and device samples remain pending.

No baseline was captured with the repaired instrumentation before these source
optimizations. The original dirty-workspace diff was preserved at
`/tmp/lifeboard-performance-preexisting.patch`; a reproducible instrumented baseline
still needs to be assembled and measured. There are no before/after performance
claims, no trace-confirmed CPU/GPU bottlenecks yet and no passed physical-device
gates. The oldest supported iPhone and ProMotion iPhone matrix remains required.

## Revised-plan execution checkpoint

- [x] Preserved a candidate checkpoint with SHA-256 hashes for tracked/untracked
  files, a tracked patch and an archive of untracked files/assets at
  `/tmp/lifeboard-performance-checkpoint-20260906`.
- [x] Corrected the actual performance scheme Test action to Release, disabled
  its debugger and removed unit-test targets requiring `@testable` modules.
- [x] Release motion-enabled root smoke passed, including the assertion that the
  native tab bar is absent: `/tmp/lifeboard-performance-release-2.xcresult`.
- [x] Initial maintenance ownership validation: service is now owned by CompositionRoot
  per persistence container; SceneDelegate supplies scene activity independently
  of SwiftUI root reads. Typed save invalidations carry affected UUIDs, domain
  subsets and container identity. Separate deadlines survive unrelated mutations.
  Focus title uses a one-row dictionary query. Debug domain/container and title-query tests pass; deadline and multiple-scene coverage remains pending.
- [ ] Source-revision vectors and command-level committed revisions remain pending;
  the maintenance notification revision is currently assigned on main-actor receipt.
- [x] Immediate Home refresh interrupts only an existing debounce; suspended-debounce regression passes.

The Release success above predates the container-owned maintenance refactor.
The earlier Release failure was a test-configuration failure, not a successful
Release acceptance run. The original baseline remains unreconstructed; the new
manifest establishes a reproducible candidate checkpoint, not the original baseline.

### Additional verified results

- `/tmp/lifeboard-performance-domain-5.xcresult`: Debug correctness plus
  motion-enabled root navigation passed after container-owned maintenance.
- `/tmp/lifeboard-performance-domain-7.xcresult`: populated Home no-op projection,
  maintenance invalidation domain/container isolation, one-row focus title lookup,
  immediate debounce bypass, timeline registration, bounded queries and selected
  planning tests passed.
- Replaced a simulator timing assumption in the burst test with the coordinator's
  completion contract; immediate debounce behavior uses a suspended injected gate.
- Home idle now applies cached context candidates without a new repository read.
  This covers context selection only; full card-height and accessibility-focus
  stabilization remain pending.
- Home provider preparation now filters requested kinds and semantic sizes and
  deduplicates repeated requests. Cross-size repository coalescing remains pending.
- Added transition-based active visual timeline counts for the shared wrappers;
  this does not yet instrument every atmosphere/media timer or prove offscreen GPU inactivity.
- Calendar failures no longer discard canonical Home tasks. Authorized same-day
  cache retention and explicit failure state implemented; populated calendar-failure regression passes in `domain-8` and `domain-9`.
- Release screenshots confirm a single dock. The Release bundle also contains a
  LifeBoardWidgets assertion in DomainWidgetConfiguration, separate from the passing
  app smoke; extension crash triage remains open.

### Continued correctness and lifecycle pass

- [x] `/tmp/lifeboard-performance-domain-9.xcresult` passes the selected Debug
  suites, including pure layout/reference parity across 1/4/8/12 columns,
  width-dependent heights and up to 500 mixed-span cards. The existing packing
  algorithm is unchanged; SwiftUI cache invalidation remains authoritative.
- [x] `/tmp/lifeboard-performance-search-1.xcresult` passes 40-query cache coverage:
  the 32-entry limit, current-query retention, old-query eviction, mutation
  invalidation, injected day rollover and purge/refetch. Search purge now clears
  ordering metadata and supersedes worker requests. Corpus preparation checks
  the originating request before and after worker execution.
- [x] `/tmp/lifeboard-performance-phase-1.xcresult` passes deterministic phase
  continuity and existing selected coordinator/layout tests. Atmosphere now
  explicitly excludes paused time and participates in active-timeline counts.
  Original 30 fps cadence and shader formulas are retained.
- [x] Home deactivation retains the active dirty request for replay on reactivation;
  suspended-provider regression passes in `/tmp/lifeboard-performance-reactivation-1.xcresult`,
  including rejection of the older completion after reactivation.
- [x] `/tmp/lifeboard-performance-release-3.xcresult`: Release motion-enabled
  navigation smoke passed after phase and reactivation changes. Six screenshots
  exported to `/tmp/lifeboard-release-3-attachments`; Home inspection confirms
  one dock. No widget crash attachment was emitted in this run, which does not
  resolve the earlier extension assertion.
  Recording: `/tmp/lifeboard-performance-release-3-motion.mp4` (45 seconds).
  This build predates the final search source/local revision separation.
- [ ] Verify atmosphere pause/resume using recordings, including covers and
  transition tails. Phase-clock tests establish arithmetic correctness only.

Remaining completion work is unchanged: committed source revisions and independent
core publication; full scroll/VoiceOver structural stability; shared query ownership
and concurrency limits; cursor history and off-lens deep links; Eva/media/startup;
real first-use Metal rendering and paired physical-device acceptance. None of the
new correctness results establish CPU, GPU, energy or memory improvements.

Candidate manifest before the final search revision fix:
`/tmp/lifeboard-performance-candidate-20260906-170059` (2,270 file hashes,
tracked patch and untracked archive). The broader `domain-9` run contains 134
passing tests; the focused `reactivation-1` run contains 31 passing tests. These
counts overlap and must not be added together.

- [x] `/tmp/lifeboard-performance-search-2.xcresult` passes independent source and local
  cache generations: repeated source revision delivery after day rollover must
  preserve the current cache, while the next mutation must fetch again.

Latest tested source checkpoint: `/tmp/lifeboard-performance-candidate-20260906-170704`. Release navigation evidence
predates only the final search-counter separation, which passed the focused Debug
regression. `git diff --check` passes. The recording is diagnostic evidence, not
a baseline/candidate motion-parity comparison.

### Core-content publication stage

- [x] Publish canonical task agenda and active focus before optional calendar,
  Track, fasting and meal inputs finish. Task-card loading uses core readiness.
- [x] Validate early and final publications against refresh ownership and mutation
  revision; preserve populated no-op behavior.
- [x] Suspended calendar regression with a populated repository (`core-1`).
- [x] Completed Plan inputs publish independently of Track and meal reads. A
  suspended Health reader verifies that populated Plan content and focus ranking
  become available while optional work remains in flight. Calendar capacity is
  never fabricated while its inputs are incomplete.
- [x] `/tmp/lifeboard-performance-core-3.xcresult`: 79 focused Debug tests pass,
  including early core/Plan publication, stale-selection rejection, reactivation,
  initial stale-result rejection and populated no-op behavior.
- [x] `/tmp/lifeboard-performance-release-4.xcresult`: Release navigation
  smoke passed with animations enabled. The active-focus regression also passed
  in `/tmp/lifeboard-performance-core-focus.xcresult`. Recording:
  `/tmp/lifeboard-performance-release-4-motion.mp4`.
- [ ] Track, fasting and optional card-provider completion still join at the end
  of the refresh. Domain-specific source revisions, independent card freshness
  and full structural deferral remain outstanding. These tests do not establish
  a measured latency, CPU, GPU, energy or memory improvement.

### Completion-plan execution

| Evidence class | Current evidence |
|---|---|
| Source-confirmed defect | Maintenance failures reset their next deadline to the following day; dependency registry strongly retains obsolete maintenance services. |
| Automated correctness verified | Core/Plan early publication, active-focus readiness, stale-selection rejection; Release motion-enabled navigation smoke. |
| Trace-confirmed bottleneck | None established by paired device traces yet. |
| Unproven hypothesis | CPU/GPU/energy savings, full invisible-work elimination, and animation parity. |

- [x] Bound maintenance failure retries independently per domain (5 seconds through 5 minutes); clear retry state on success.
- [x] Registry now weakly references maintenance services. Tests verify sharing while owners retain the service, isolation between containers, and release after the final owner disappears. Active scene/deadline integration coverage remains pending.
- [ ] Introduce committed source revisions and independent authorized domain publication.
- [ ] Complete structure/value separation, shared reads, history, visual lifecycle and secondary flows as specified in the approved completion plan.

### Independent-domain continuation results

- Prospective baseline manifest: `/tmp/lifeboard-performance-baseline-20260906-181136`.
  Includes tracked patch, untracked archive, hashes, Xcode version and links to
  existing test artifacts. Dedicated fixture versioning and complete measurement
  semantics still prevent Stage A acceptance.
- `/tmp/lifeboard-performance-maintenance-1.xcresult`: 81 focused Debug tests pass.
- `/tmp/lifeboard-performance-domains-1.xcresult`: 82 focused Debug tests pass.
  Populated Track hydration and fasting publish while calendar and health reads
  remain suspended. Repeated unchanged loads add no presentation commits.
- `/tmp/lifeboard-performance-cards-1.xcresult`: 83 focused Debug tests pass.
  Card results publish individually. A suspended Journal provider cannot restore
  cards or routes after privacy invalidation. An authorization generation protects
  this card boundary; it is not yet the full application authorization vector.
- Hydration's loading presentation now respects available Track/Health values
  instead of waiting for unrelated refresh completion.
- A final adjustment clears recovered aggregate failure state while preserving
  either Plan or Track failures. Focused rerun `/tmp/lifeboard-performance-cards-2.xcresult` passes all 83 tests.
- Remaining: command-level source revisions and mutation waiters; full hero/direct
  privacy revocation; structural deferral; container-scoped coalesced reads; paged
  history; actual visibility/transition coverage; Eva/media/startup and device gates.

These counts overlap. No new measured performance improvement is claimed.

- [x] Release motion-enabled navigation after the maintenance/card changes:
  `/tmp/lifeboard-performance-release-5.xcresult` passed. Recording:
  `/tmp/lifeboard-performance-release-5-motion.mp4`. Exported screenshots:
  `/tmp/lifeboard-release-5-attachments`. Home inspection confirms populated tasks
  and one dock. No crash attachment in this run; earlier widget assertion unresolved.

Tested candidate checkpoint: `/tmp/lifeboard-performance-candidate-20260906-182656`.
`git diff --check` passes. Baseline resolved build settings and dependency-lock
hashes are captured; device acceptance, complete fixtures and first-use rendering
validation remain pending.

### Committed-revision foundation (September 7)

- [x] Added container-scoped `ProjectionRevisionLedger`, `ProjectionDomain`,
  `SourceRevisionVector`, and immutable `DomainInvalidation`. Plan, Track and
  Phase II repositories retain one shared ledger per live store coordinator.
  Its save observer runs synchronously on the saving queue and records UUIDs,
  domain revisions and transaction author without carrying managed objects.
- [x] `/tmp/lifeboard-performance-revisions-2.xcresult` passes the selected
  Debug suites, including revision visibility before `context.save()` returns,
  domain/container isolation, shared repository ownership and rollback behavior.
- [x] Home core and Plan publication validate relevant committed revisions;
  `/tmp/lifeboard-performance-revisions-3.xcresult` passes 85 focused Debug tests.
  Suspended-calendar tests allow unrelated hydration saves and reject older Plan
  results after external task saves.
- [ ] This is not yet the full refresh contract: application mutations still need
  receipt/awaiter integration, domain-specific pending requests and stale-read
  retries. Global coordinator generations can still supersede unrelated work.
- [ ] Extend source dependency mappings and authorization generations to all
  remaining repositories/external providers, with failed-save and broader dependency
  coverage. No direct command invalidations are emitted yet, so duplicate command
  versus fallback notification handling has not been introduced.

The first sandboxed `revisions-1` attempt failed before compilation because Xcode
could not access its caches and Simulator services. The approved host-access rerun
succeeded; this environment failure is not counted as a product test failure.

- [x] `/tmp/lifeboard-performance-revisions-concurrent.xcresult` passes: 20 concurrent
  hydration saves advance tracking exactly 20 times without changing Plan domains.
- Current tested checkpoint: `/tmp/lifeboard-performance-candidate-20260907-005100`. Latest Release UI evidence
  remains `release-5`, which predates the revision ledger; this stage has Debug
  correctness evidence only. `git diff --check` passes with fsmonitor disabled
  for the restricted sandbox. No measured performance claims.

### Task mutation projection completion

- [x] Added `ProjectionRefreshOutcome` and a shared committed-refresh drain.
  Satisfied callers complete after their revisions publish rather than waiting
  for newer pending work. Caller cancellation releases only its waiter.
- [x] Home task completion and undo now await a core task read independent of
  optional calendar, Track and health providers. The existing Boolean continues
  to report durable write success. A separate refresh failure is displayed with
  a retry action that does not repeat the mutation.
- [x] `/tmp/lifeboard-performance-mutation-contract-1.xcresult` passes selected
  Debug tests, including task completion/undo during suspended calendar loading,
  early caller completion, cancellation and explicit rejection of old results.
- [x] `/tmp/lifeboard-performance-mutation-contract-2.xcresult` passes 91 focused
  Debug tests. Domain acknowledgement requires actual publication; observing a
  tracking revision during a task read cannot complete a tracking waiter.
- [ ] The application refresh coordinator still uses global generations. This
  drain currently owns Home task mutation projection only; hydration, mood,
  fasting and other mutations still need equivalent committed revision contracts.
- [ ] Deactivation/authorization integration and command receipt-level revision
  capture remain pending. The task wrapper captures the ledger immediately after
  successful persistence completion; this is a conservative revision requirement,
  not yet a revision returned atomically in the domain command receipt.

- [x] `/tmp/lifeboard-performance-release-6.xcresult` passed motion-enabled
  Release navigation for the revision ledger and task mutation contract.
- [x] Fixed the source-confirmed hero settle timeline leak using the shared finite
  cleanup modifier; preserved `hasSettled`, the 0.42-second duration and shader
  math. Added active-timeline registration. Hosted SwiftUI cleanup test passes in
  `/tmp/lifeboard-performance-hero-cleanup-1.xcresult`.
- [ ] Hero completion-tail recording remains required for motion parity; Release
  `release-6` predates this final cleanup and the stale-recommendation fix.
- Remaining timer inventory includes legacy Home/Timeline minute clocks, dial
  glow, LBDelight, DeviceStat, FocusTimerView and recording timers. References and
  domain versus presentation responsibilities must be established before changes.

- [x] Final mutation regression (`mutation-contract-3` passed): core task updates
  also remove completed tasks from focus ranking and Must Do hero recommendations
  while the full Plan snapshot remains stale; undo restores the recommendation.
  This prevents earlier agenda publication from leaving an actionable completed
  task in the hero. Optional card-resolution and full layout freshness remain
  subject to their existing refresh path and pending completion work.

Current checkpoint: `/tmp/lifeboard-performance-candidate-20260907-011806`. Final Debug result: Executed 93 tests, with 0 failures.
Latest Release success is `release-6`; it predates only the final hero cleanup
and stale task-recommendation correction. Those final edits passed the Debug
suites and still need Release/visual-tail coverage. Workspace diff check passes.


### Hydration and mood mutation projection completion (2026-09-07)

- [x] Home hydration and mood mutation methods now return `ProjectionRefreshOutcome`
  after a narrow authorized-repository read. Each has its own committed-refresh
  drain; neither waits for calendar, health meals, goal samples or unrelated Track
  collections. Existing callers may still discard the result.
- [x] Hydration reads today's logs and target, preserves other populated Track
  fields and uses partial completeness if the first full snapshot is still loading.
  Mood can publish with no Track repository. Changed values rebuild relevant
  hero/focus presentation; unchanged reads do not increment commit counters.
- [x] Full Track publication now checks its Track and mood persistence revisions,
  including external saves that bypass Home's mutation counter. The read cannot
  overwrite a more recent hydration/mood publication.
- [x] Mood save/refresh failures reach an alert in Home. Refresh-only methods do
  not repeat the durable mutation. Hydration's returned outcome is available to
  callers; the current Home water tile still uses the shared capture route, whose
  command-to-Home revision integration remains pending.
- [x] `hydration-mood-2`: 97 focused Debug tests passed. New tests cover mutations
  during suspended calendar/health/goal providers, partial Track publication,
  mood without Track, concurrent hydration totals, populated narrow no-ops and
  external hydration invalidation. This includes the previous task and effect tests.
- The first `hydration-mood-1` attempt failed compiling a new fixture because its
  hydration target omitted required ID/update-time arguments. Corrected before
  the successful rerun; no production failure was hidden.
- [x] Release `release-7` passed with shipping optimization, no debugger and
  motion-enabled UI smoke. This includes the previous final hero cleanup and
  stale task recommendation fixes as well as the initial hydration/mood stage.
  Exported screenshots show a populated Home and one dock. The 45-second
  `/tmp/lifeboard-performance-release-7-motion.mp4` is diagnostic evidence only;
  it was started during the smoke and does not prove initial effect-tail parity.
  This run predates the final protocol-provider revision fallback and hydration
  fetch timestamp correction; final-source Debug/Release reruns follow.
- [ ] Separate privacy authorization generations, revocation of all direct values,
  deactivation cancellation and atomic command receipt revisions remain unfinished.
  The new methods validate concrete Core Data revisions. Protocol-only mood
  providers use screen-owned committed revisions for Home saves; external writes
  still require a provider-level invalidation/revision contract.
- [ ] Global Home refresh scheduling, shared capture command integration, full
  structural deferral, cursor history and physical-device performance gates remain
  pending. These narrow mutation drains do not complete those contracts.

- [x] Final review corrected protocol-only mood completion: each successful Home
  write advances a local revision when no persistence ledger is available. A
  suspended older read must retry before it can acknowledge the newer caller.
  Added a real-persistence protocol adapter with a suspended read to exercise the
  actual Home store. `hydration-mood-3` passed all 98 selected Debug tests.
- Hydration updates now advance the snapshot fetch time only for a changed
  presentation; retaining the full per-domain source/fetch metadata independently
  of presentation equality remains part of the pending load-state work.


Next implementation slice remains committed invalidation delivery and lifecycle:

- [ ] Connect the ledger's immutable container/domain/ID revisions to the Home
  coordinator. `latestInvalidation()` is currently a snapshot, not a lossless
  event subscription; command completion cannot rely on observing only that value.
- [ ] Cover the actual water capture path in `HealthLogComposers.swift`, Track
  mutations, Eva actions and shortcuts. Preserve each existing write/reminder/
  health-sync contract while delivering committed revisions to active readers.
- [ ] Replace Home's broad `mutationRevision`/tracker refresh triggers with domain
  requirements. Ordinary events must merge without invalidating unrelated useful
  work; authorization and selection generations still reject old callbacks.
- [ ] Add cancellation/dirty-state ownership for the new narrow mutation drains
  before treating screen teardown or privacy revocation as complete. Then finish
  value/structure separation with scroll and VoiceOver geometry tests.

Final-source Release navigation diagnostic passed as `release-8`, across Home,
Plan, Track, Insights and repeated selections with the single-dock assertion.
Final Debug result is `hydration-mood-3`: 98 tests, zero failures. These counts
replace the earlier overlapping runs; they are not cumulative. Candidate manifest,
tracked patch, untracked archive, artifact hashes and resolved Debug/Release build
settings are captured at
`/tmp/lifeboard-performance-candidate-20260907-122500`. Release resolves `-O`,
whole-module compilation and `ENABLE_TESTABILITY = NO`; the Test action is Release
with no debugger. No device performance gate has passed.


Latest checkpoint: `/tmp/lifeboard-performance-candidate-20260907-122500`.
Only Home's projection store, the Home mood error UI, foundation regression tests
and this checklist changed relative to candidate `20260907-011806`. Existing
workspace modifications were preserved. `git diff --check` passes. No paired
CPU/GPU/memory/energy improvement, physical-device gate or motion parity is claimed.


### Shared hydration invalidation and presentation lifetime (2026-09-08)

- [x] The container revision ledger now exposes typed, filtered subscriptions.
  Hydration log/target saves on the same in-process persistence coordinator notify
  Home without routing writes through a Home store. This covers the shared
  `TrackUniversalCaptureView` composer,
  the Health hub water sheet, Track, Eva and shortcut repository commands.
- [x] Each subscriber retains one merged immutable event and one wake-up. Source
  revisions merge by per-domain maximum even if concurrent save delivery arrives
  out of order. Domains and record kinds are retained; above 256 affected IDs the
  event requests a full domain refresh instead of retaining unbounded identifiers.
- [x] Registration replays current revisions to cover the subscription/foreground
  gap. Home skips already-applied same-day revisions, updates local hydration
  independently of calendar/health/goal reads and cancels the subscription when
  presentation demand ends. Unrelated saves do not wake the hydration consumer.
- [x] Added explicit generation-aware cancellation to committed projection drains.
  It releases waiters and rejects late operations without letting an old worker
  clear or satisfy a newly active worker. Home's task, mood and hydration narrow
  reads check presentation generation before publishing. Durable saves and the
  Health outbox retain their existing behavior.
- [x] Hydration refresh failures retain current content with stale/unavailable
  signal state and an accessibility hint when the local value is the displayed
  source. Successful full or narrow reads clear the error. Changed error state is
  included in presentation commit accounting.
- [x] `hydration-subscription-3`: 103 focused Debug unit tests and one motion-enabled
  Debug UI capture test passed. New coverage includes burst merging/filtering,
  bounded IDs, out-of-order domain revisions, foreground catch-up with optional
  providers suspended, zero narrow reads after cancellation, cancelled worker
  isolation, and preservation of saved moods after presentation cancellation.
- [x] The UI test opens Home's actual hydration capture, saves the default glass,
  waits for sheet dismissal and verifies a 250 ml Home signal without refreshing.
  Release uses accessibility identifiers for the commit control.
- The first `hydration-subscription-1` run found a merge equality bug: explicit
  zero entries made logically equal revision dictionaries unequal. Merge now only
  inserts advancing domains. Both subsequent Debug runs pass; counts overlap.
- [x] `release-9` passed the shared capture flow and four-root navigation smoke
  under shipping Release optimization with motion/shader policies enabled. It
  predates the final inactive-save guard; that guard is being validated separately.

Evidence labels: the dropped connection between shared hydration saves and Home
was a **source-confirmed defect**; the new subscription/store behavior is
**automated correctness verified**. There is still no **trace-confirmed bottleneck**
or paired measured improvement. Read savings under sustained workloads remain an
**unproven hypothesis** until the device investigation.

Limits and next work:

- [ ] This closes hydration delivery only. Other record kinds still need their own
  independent consumers, command-returned revision receipts and coordinator-level
  domain merging. The broad Home refresh coordinator is still present.
- [ ] Screen cancellation does not implement privacy revocation. Direct sensitive
  values, pending structures and all asynchronous providers still need a separate
  authorization generation and synchronous clearing policy.
- [ ] Initial catch-up can overlap the existing full Track read; shared query
  coalescing and a global leaf-read concurrency limit remain pending.
- [ ] The Home signal still prefers a supplied Health aggregate. These changes do
  not redefine Health/local deduplication or guarantee immediate freshness of a
  previously cached Health value. The UI fixture verifies the local fallback;
  add an authorized Health fixture and reconcile freshness without double counting.
- [ ] Replay/retry after foreground and a later committed event are implemented;
  automatic backoff after a failed hydration read and full optional load-state
  reporting remain pending. No periodic presentation polling was added.
- [ ] Full structural deferral, cursor history, remaining visual lifetimes, Eva,
  media, startup and paired physical-device acceptance remain unfinished.


Final lifecycle review added an explicit presentation-active guard. A repository
save that returns after deactivation must not start a new read using the newer
cancellation generation. The durable save remains successful and can be projected
on reactivation. A suspended save-callback regression now covers this boundary;
its final-source validation follows the currently running Release run.

Additional limits: filtering avoids new hydration wakes for unrelated records,
but hydration still validates the coarse tracking-domain revision, so an in-flight
read can retry after another tracking subdomain changes. Per-query dependency
revisions and shared read ownership remain pending. Cancelling a presentation
task also cannot force a custom provider that ignores cancellation to return;
full suspended-provider teardown/deallocation coverage remains required.


- [x] `hydration-subscription-4`: 104 focused Debug tests passed, including the
  suspended save callback after deactivation. The active guard prevents a new
  hidden projection read; reactivation projects the already-durable record.
- [x] Final-source `release-10` passed both shared hydration capture and the
  motion-enabled navigation smoke. It includes the active-state guard and neutral
  automatic-refresh error wording (no claim that a water save occurred on initial
  catch-up). Final manifest/build settings are being saved at
  `/tmp/lifeboard-performance-candidate-20260908-hydration`.

The subscription observes in-process context saves for its persistence coordinator.
Cross-process/CloudKit persistent-history or remote-change delivery still needs
integration; a command in a different process does not share this ledger. Existing
full foreground loading remains in place. Source revisions must not be treated as
proof of remote-store freshness until that integration is covered.


Release `release-10` passed functional assertions, but its navigation test recorded
an unexplained accessibility-query gap from t=14.40s to t=115.96s before the Plan
tap. It must not be used as responsiveness or latency acceptance. A same-binary
navigation rerun without video recording is underway as `release-11`; no cause is
attributed to application, automation, host scheduling or recording without evidence.
The 75-second Release recording is diagnostic and does not cover the entire run
because of this gap. Motion parity remains unverified.
