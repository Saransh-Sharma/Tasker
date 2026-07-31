# LifeBoard — Daily Loop ("lifeOS") Developer & Designer Handoff

**Date:** 2026-07-31
**Branch:** `lifeOS` (base commit `ef7ba345`)
**Status:** M1–M4 complete and verified. M5 complete except two deletions deliberately deferred (§8).
**Audience:** the engineer and designer picking this up cold.

---

## 1. The problem we were solving

LifeBoard had a daily loop that was **five-sixths built and had no beginning or end**.

The loop a person actually lives is:

```
capture → triage → plan → act/focus → complete → close → carry → commit → (repeat)
```

Everything from *capture* to *complete* already shipped and works well: Inbox with commit + undo, a Plan day canvas with drag-move and boundary-aware resize, `PlanningScenario` preview/apply/undo, Focus with pomodoro + interruption logging + post-session reflection, and the Overdue Rescue deck.

What did not exist:

**1. Nothing ended the day.** `HomeSectionRole.closeLoop` ("Close the loop") was a taxonomy label over four static cards — Journal, Progress, Saved Eva Insight, Life Moment. Unfinished commitments silently rotted into overdue and got swept up days later by a *separate* rescue flow. There was no moment to see what happened, decide what carries, reflect once, and name tomorrow's first thing.

**2. Nothing began the day.** The loop ran Close → *nothing* → next Close. Nothing that happened in the evening changed what the next morning looked like.

**3. The loop had no memory.** Home displayed `"N day continuity"`, which rendered `GamificationEngine.profile.currentStreak` — *"consecutive days with any XP event"*. That is not a fact about the loop. It was XP wearing loop vocabulary.

**4. The loop was hard to reach even where it existed.** The ritual entry row was the 7th section down a scroll view; it rendered only 05:00–11:00 or 18:00+ (**invisible 11:00–18:00**); and it sat inside `budget.showsCloseLoop`, which is `false` for **both** Low Energy mode and Minimal density — the two states that most need a gentle close.

**5. The two halves disagreed.** The 21:00 "Day Retrospective" notification (default ON, shipping) routed to **Insights**. The Home evening row routed to the **ritual**. Same moment, two destinations.

**6. A whole engagement layer was built and rendered nowhere.** XP is awarded at 9 call sites with an idempotent ledger, achievements, and reconciliation. The only place a human ever saw it was a substring of the 9pm notification body. Four view files, three widgets and an entire celebration pipeline were compiled and unreachable.

---

## 2. What we set out to do

**Make the daily loop the primary way to use the app**, and give it a beginning, an end, and a memory.

Three product decisions were taken up front and should **not** be re-litigated:

| Decision | Meaning |
|---|---|
| **Rhythm, not points** | Surface loop continuity in the loop's own vocabulary. **No points, levels, or badges on Home.** The XP ledger keeps running underneath as a data source; the vocabulary changes. DESIGN.md's anti-guilt law binds: "overdue"→"rescue", streaks→"active days", no punitive red, and streak + consistency get **equal visual weight**. |
| **Home = loop spine on top, pinned dashboard below** | The loop leads and reorders by stage of day. Beneath it, a *separate* dashboard region preserves today's widget-customization model. `HomeSectionRole.userSpace` already means "whatever the user pinned" — build on it, don't invent a new concept. |
| **Ambient layer is a later phase** | Widgets / Siri / Watch come **after** the in-app loop is coherent. A widget showing a stage the in-app spine hasn't stabilised is a second source of truth. |

### The structural insight that set the milestone order

**Close already contains Commit.** `DayCloseAct.anchor` — "Tomorrow's first thing" — is act 4 of 5 of the evening ritual. It works, it's tested, it writes durably. So the cheapest way to give the loop a beginning is *not* to build a morning ritual; it's to make the anchor load-bearing.

That is why **the carry (M2) lands before the morning commit (M3)**. If the morning ritual turns out to be a thing people skip, the loop still opens without the user doing anything.

---

## 3. The architectural spine — read this before writing code

### 3.1 The loop's memory is the receipt ledger. There is no new entity.

This is the single most important thing to understand.

Every fact the loop remembers is derived from **applied `PlanningMutationReceipt` rows**:

| Question | Answer |
|---|---|
| Was today closed? | `hasAppliedReceipt(source: "planning.scenario.dayClose.YYYY-MM-DD")` |
| Was today committed to? | `hasAppliedReceipt(source: "planning.scenario.dayOpen.YYYY-MM-DD")` |
| What is the run / consistency? | `DayLoopLedger.summarize(records:)` over `fetchMutationReceipts(since:)` |
| What did last night choose as today's first thing? | `DayLoopLedger.anchorTaskID(in:closedOn:targetDay:)` — decodes the receipt's `forwardData` |

**Consequences:**
- **No new Core Data model version was needed, and none should be added for this work.**
- Undo flips receipt `state` to `.undone`, so an undone close **stops counting everywhere for free**. Do not add a parallel counter — it will drift.
- The ledger is also the product's own instrumentation. Every success signal in §7 is a query over it.

### 3.2 Do NOT use `pinOrder == 0` as provenance

`DayCloseScenarioBuilder.applyAnchor` writes the triple `pinOrder = 0 && commitmentLevel == .mustDo && planningDay == tomorrow`.

But `LifeOSFoundationShell.swift:4681` writes `after.pinOrder = index` on **any manual Plan reorder**. The field records a *position*, not a *provenance*. `DayLoopLedger.anchorTaskID` therefore decodes the receipt and requires all three fields together. Requiring only `planningDay` would make every ordinary carried task look like a deliberate choice.

### 3.3 One act = one batch = one receipt = one Undo

Both rituals build a `PlanningScenario` and hand it to the existing `DefaultPlanningScenarioCoordinator`, which wraps `proposedMutations` in a single `.batch`, applies it inside one Core Data `write`, and gets a correct reverse-order inverse for free.

**The reconciliation deck deliberately writes nothing per card.** Decisions accumulate in memory; the whole evening commits once. Per-card writes would produce one receipt per card — Undo would unwind the evening one task at a time — and backing out halfway would leave a half-applied reconciliation.

**Design consequence:** the deck must show *selection* feedback per card (`LifeBoardHaptic.pick`), never *success* feedback. Success (the mark, `.commit` haptic, the burst) fires only after the batch lands. DESIGN.md requires a persisted-state boundary before success feedback.

### 3.4 Absent ≠ zero. This is a hard rule, not a preference.

- `DayCloseRingSummary.plannedMinutes` is `Int?`. A day with no blocks renders a **bare ring track and the words "Open day"** — never a 0% arc.
- `focusRatio` is `nil` when nothing was planned, and is **not clamped to 1** — focusing past what you planned is a real thing that happened.
- `DayLoopSummary.hasNoHistory` suppresses the rhythm line entirely before a first close. "0 days running" is a verdict on nothing.
- The ribbon reports `externalCalendarUnavailable` rather than drawing an empty external lane. "We didn't look" ≠ "your calendar was clear".

### 3.5 Empty is a success state and must look different from a failure

An empty reconciliation deck renders **"Everything you committed to is done."** as a filled warm clay card. It must **never** be a `ContentUnavailableView` — that is what failure looks like on this surface. A failed load renders "The day's shape couldn't be loaded" + Retry.

---

## 4. Milestones — what each one was, and its state

### M1 — One door, always open ✅ COMPLETE

**Problem:** the ritual was behind three independent gates and the notification led somewhere else.

**Built:**
- `DayLoopStage` + `DayLoopStageResolver` (`Foundation/PhaseIII/DayLoopStage.swift`). Five stages: `.commit`, `.act`, `.repair`, `.close`, `.rest`. **Loop state dominates the clock** — a day closed at 15:00 resolves to `.rest` regardless of hour.
- Ritual row lifted **out of** `budget.showsCloseLoop`. The *placement section* stays budgeted; the door does not.
- `LifeBoardAppRouter.handle(notificationRoute:)`: `.dayCompass(.eveningReview)` and `.dailySummary(.nightly)` → `.dayClose(date)`; `.dayCompass(.morningPlan)` → `.dayOpen(date)`. The `yyyyMMdd` stamp was already parsed off the payload and then **discarded by a `_` binding** — now resolved via `notificationDate(from:)`, so a notification tapped after midnight closes the day it was written about.
- `DayLoopClosureLog` — a per-device UserDefaults cache the ritual writes on close and clears on undo. The 22:30 follow-up previously read `UserDefaultsDailyReflectionStore`, which the ritual **never wrote**, so it fired at people who had already closed.
- Rewrote the 22:30 body. Was: *"One quick reflection keeps your streak resilient. Claim it before day-end."* — that breaks the anti-guilt law twice (streak as motivation + an artificial deadline).

**Verified live:** row renders in Low Energy where it was previously hidden entirely; disappears after closing.

### M2 — The carry ✅ COMPLETE

**Problem:** the anchor was written and never read; `.dayOpen` showed the wrong day.

**Built:**
- **Fixed a real defect:** `.dayOpen` passed *today* to `DayCloseStore`, which filtered `planningDay == today`, so the morning showed **today's** open tasks under "What carried" / "Last night's decisions". On any day that wasn't closed, that was a false claim. `DayCloseStore` now takes a distinct `retrospectiveDay` (yesterday for `.open`, itself for `.close`).
- `DayLoopLedger` (`Foundation/PhaseIII/DayLoopLedger.swift`) — `summarize()` for continuity, `anchorTaskID()` for the carry.
- Carry surfaces on Home's Now region as a `HomeContextCandidate` at **priority 560** — above the next calendar commitment (420–520). A deliberate choice made with a clear head outranks whatever merely happens to be next. It disappears the moment the task is completed.
- `.open` mode states provenance honestly: *"Yesterday wasn't closed, so nothing was carried deliberately. Here's what's open today."*

### M3 — The morning commit ✅ COMPLETE

**Problem:** the loop had no beginning.

**Built:**
- `PlanningScenarioSource.dayOpen` (additive; deliberately distinct from `.minimumViableDay`, which builds a near-identical batch but means "make today small" rather than "this is today").
- `DayOpenScenarioBuilder` (`Foundation/PhaseIII/DayOpenScenarioBuilder.swift`) — proposal ranking + scenario construction. Receipt source `planning.scenario.dayOpen.YYYY-MM-DD`.
- Proposal is **capped at 3** and **pre-selected**. Primary action is **"Yes, start with this"**; editing is secondary ("Tap any line to leave it out").
- An empty selection still writes a receipt — agreeing that today is deliberately clear is a commitment, and a ledger that only records busy days misreports the loop.

**Verified live:** commit → *"Today is set."* → Undo restored the proposal exactly.

### M4 — Home spine over pinned dashboard ✅ COMPLETE

**Problem:** Home was a dashboard; the loop was buried inside it.

**Built (see §5 for the full IA):**
- `loopSpine(palette:ambientPalette:budget:)` in `LifeBoardFoundationGallery.swift` — leads Home, directly under the greeting.
- **The spine is not budgeted.** Low Energy changes its **stage set**, not its visibility.
- `.closeLoop` retired as a rendered section; coalesced into `.userSpace` at **read time** in `effectiveSectionRole(for:)`.
- "Your space" → **"Your dashboard"**.

**Verified live:** "Ending the day" leads Home; the Journal and Progress widgets that lived in "Close the loop" **moved into the dashboard rather than disappearing**.

### M5 — Rhythm, and the cut 🟡 MOSTLY COMPLETE

**Built:**
- Rhythm line: **"4 days running · 9 of 14 days"** from `DayLoopLedger`, replacing `"N day continuity"`.
- Insights: `planningEvent` now carries `receipt.source` through as `day_closed` / `day_opened` / `day_close_reversed` / `day_open_reversed`. It previously **dropped `source`**, so a day-close reached Insights as a generic `mutation_applied`, indistinguishable from dragging a block.
- Weekly Review now merges the week's `.dayClose` notes (`ReflectionNoteQuery(kinds: [.dayClose], limit: 7)`) instead of asking for a week's reflection cold. `.dayClose` notes carry no `linkedWeeklyPlanID`, so the existing query could never match them.
- Deleted: `HomeXPHeroView`, `LevelUpCelebrationView`, `BadgeGalleryView`, `MilestoneCelebrationView`, and the dead `eva_plan_repair_v1` flag.

**Not done — see §8.**

---

## 5. Home information architecture (for the designer)

```
┌─ GREETING ─────────────────────────────────────────────────────┐
│  "Good evening!" · Friday, July 31                             │
├─ LOOP SPINE  (app-owned · never pinnable · never budgeted) ────┤
│  stage title            [ rhythm line, right-aligned ]         │
│  ── stage body ──                                              │
│    .commit → the morning proposal                              │
│    .act    → Now card                                          │
│    .repair → Now card (drift surfacing is NOT yet built)       │
│    .close  → the ritual entry row                              │
│    .rest   → one sentence, no CTA                              │
├─ APP SECTIONS ─────────────────────────────────────────────────┤
│  Signals · Today · Day ahead · Needs attention · Keep steady    │
├─ YOUR DASHBOARD ───────────────────────────────────────────────┤
│  pinned widgets · drag to arrange · Undo · Add a widget         │
└────────────────────────────────────────────────────────────────┘
```

### Stage titles and bodies

| Stage | Title | Body | Notes |
|---|---|---|---|
| `.commit` | **Start today** | ritual entry → `.dayOpen` | morning window, not yet committed |
| `.act` | **Now** | `nowSection` verbatim | the default |
| `.repair` | **Worth a look** | `nowSection` (placeholder) | **drift detection is not built** — see §6 |
| `.close` | **Ending the day** | ritual entry → `.dayClose` | evening, or any hour once M1 landed |
| `.rest` | **Today is closed** | *"Nothing more is being asked of you today."* | **no CTA by design** |

`.rest` deliberately asks for nothing. **Closing a day must not open a new obligation.** Do not add a "plan tomorrow" button here.

### `HomeSectionRole` disposition

| Role | Fate |
|---|---|
| `.anchored` | Survives, subsumed. `nowSection` reused verbatim; only its call site moved under the spine. |
| `.today` | Unchanged, above the dashboard. |
| `.keepSteady` | Unchanged. Care and routines are not loop stages. |
| `.closeLoop` | **Retired as a rendered section.** Coalesced to `.userSpace` at read time in `effectiveSectionRole`. **Do not delete the enum case** — it is persisted in `sectionOverride`, and removing it breaks decoding of layouts users already have. |
| `.userSpace` | **Promoted** to "Your dashboard". `userSpaceSection` reused verbatim. |

### DashboardMode behaviour

- **Low Energy** now changes the spine's *stage set*: `.repair` is suppressed entirely (`suppressesRepair: true`). It no longer hides the close. This is the first time Low Energy means something at the loop level rather than being the mode that hides the gentle close.
- **Work / Personal** still differ only by the context filter. Making them meaningful is open work.

### The rhythm line — design spec

Renders as `"4 days running · 9 of 14 days"`.

- **Both numbers must render at the same size, in the same label.** The anti-guilt mechanism is *arithmetic, not copy*: a broken run drops the first number to 1 while the second moves by one-fourteenth, and the second is the one that stays true after a bad week.
- Wraps to 2 lines rather than truncating. It truncated to `"1 day running · 1 of…"` in the 2-up Progress card during testing — hiding exactly the half that survives a bad week. DESIGN.md forbids shrinking type to preserve a grid.
- Hidden entirely when `hasNoHistory`.
- **No red, no flame, no "lost", no recovery offer.**

**Acceptance test (run this, it is not optional):** deliberately break a 10-day run and screenshot Home. If the eye lands on the `1` before the `9 of 14`, if anything turns warm-red, or if any copy offers to help you recover — it fails and gets re-laid-out.

---

## 6. What remains to be built

### 6.1 Drift detection for `.repair` — **highest priority**

`DayLoopStage.repair` exists, is tested, and is wired into the resolver via `driftCount`. **Nothing computes `driftCount`, so the stage is currently unreachable.** The spine falls back to `nowSection` for it.

Build a pure resolver: unstarted commitments whose planned time has passed. Feed `DayLoopStageResolver.resolve(driftCount:)`. Then give `.repair` a real body — the Plan Repair deck (`LifeBoardPlanViews.swift:2393`) and the Overdue Rescue entry already exist and should be reused, not rebuilt.

**Design note:** this is the stage most at risk of feeling like nagging. Low Energy already suppresses it. Consider a threshold (2+ drifted items?) rather than surfacing on the first.

### 6.2 The `.dayOpen` proposal needs real-world tuning

Ranking today is: anchor first → carried → must-do → UUID. That is deterministic but naïve. Once §7's "unedited proposal" signal exists, tune it.

### 6.3 Insights `.review` lens

`planningEvent` now emits `day_closed`/`day_opened`, but the `.review` lens still renders one prose line off `sourceCounts`. It now has real material — use it. Keep the 3-day floor in `InsightsInterpretationEngine`.

### 6.4 The ambient layer (deferred phase)

- **Widget "Complete" bounces you into the app.** Only `CaptureToInboxIntent` is a true background intent; the other four widget intents stash a command and launch the app.
- **No intent is ever donated** — zero `donate()` calls repo-wide, so Siri Suggestions and Spotlight never surface LifeBoard actions.
- **`TodayXPWidget` / `NextMilestoneWidget` / `WeeklyScoreboardWidget`** are compiled but absent from `LifeBoardWidgetBundle.body` — unreachable. Given the "rhythm not points" decision, **delete them** rather than register them. Note `LifeBoardTests.swift` `testWidgetViewsDoNotReintroduceLegacyBrandLiterals` lists them by path; remove those entries too.
- A Watch path for the close, and a Live Activity for the day itself.

### 6.5 The evening notification is deliberately unchanged in cadence

We re-routed it; we did not make it more insistent. **A notification that pulls someone into a reflective ritual is the fastest way to make it feel like nagging.** Ship the in-app entry, watch whether people find it, then decide.

---

## 7. How to tell if this worked

Local-first — no telemetry. Every signal is a query over `fetchMutationReceipts(since:)`.

| Milestone | Signal | Why this one |
|---|---|---|
| M1 | Close receipts with `appliedAt` between 11:00–18:00; **zero** `daily.reflection.*.followup` deliveries on days holding a close receipt | The second is binary and is the honest test |
| M2 | Of days whose close named an anchor, the share where that task is **started or completed by 12:00** the next day | Not "did they see it". If it's indistinguishable from a random must-do, the carry is decoration |
| M3 | Of days with a close receipt the night before, the share getting a `dayOpen` receipt **before 11:00**. Plus: share of commits that are the **unedited** proposal | The first decides the thesis; the second says whether the proposal is any good |
| M4 | Share of days with **both** an open and a close receipt rises; share of pinned placements still pinned after two weeks does **not** fall | The second is the falsification test for spine/dashboard coexistence |
| M5 | The adversarial screenshot test in §5 | No metric — a design review with a specific input |

### The riskiest assumption, stated in advance

**That people will do a morning commit at all.** The evening has a natural trigger — the day ends, you want to put it down. The morning has a hostile one: you're rushed, already moving, and you believe you know what today is.

**Falsification:** if fewer than ~40% of days-following-a-close get a `dayOpen` receipt before 11:00 over two weeks of real use, **the right response is not a better morning screen.** It is to move the commit into `DayCloseAct.anchor` (where it already half-lives), make the morning a zero-interaction confirmation, and write the `dayOpen` receipt implicitly on first foreground. "Commit" would then have a record but no user-facing surface — a legitimate outcome, and materially cheaper.

The plan is arranged to survive this: **M2's carry uses only the write the evening already makes**, so if M3 underperforms the loop still opens without the user doing anything.

---

## 8. Deliberately NOT done — and why

The roadmap listed these as "orphan" deletions. **On inspection both are live.** Do not delete them without first retiring the legacy Sunrise shell.

### 8.1 The `DailyReflection*` family

~1500 lines. Still:
- constructed in `EnhancedDependencyContainer.swift:131` (`UserDefaultsDailyReflectionStore`)
- wired into `UseCaseCoordinator.swift:204,298` (`MarkDailyReflectionCompleteUseCase`)
- spread through `CoreDataWeeklyRepositories.swift:1189–1459` (`DailyPlanDraft`, `fetchPlanDraft`, `savePlanDraft`)
- plus `DailyReflectionLoadCoordinator.swift` and the Sunrise screens

**`DailyPlanDraft` is the loudest reason to eventually delete this:** it is a second, competing "the user committed to a day" record. Leaving it in the tree means someone will eventually re-wire the morning to it instead of the receipt ledger. **If you touch the morning, use the receipt.**

M1 removed its last *live production read* (the notification), so the blocker is now only the legacy shell.

### 8.2 The celebration pipeline

Not an orphan either: `lastXPResult` has a live consumer at `SunriseAppShellView+ObserversSearchAndBackdrop.swift:74`, and `DefaultCelebrationRouter` has four real tests. Removing it entangles the legacy Sunrise shell.

---

## 9. Engineering constraints — these will bite you

### 9.1 The test baseline is stale

`scripts/lifeboard-test-failure-baseline.txt` is empty and both older handoffs say *"any `+` is a regression you introduced."* **That is no longer true.** Five tests fail on a clean tree at `ef7ba345`:

- `ArchitectureBoundaryTests.testViewLayerDoesNotUseSingletonDependencyContainers` — `HomeViewController+Presentation.swift:1035` uses `EnhancedDependencyContainer.shared`
- `HabitCoreDataSchemaRegressionTests.testBootstrapSchemaValidationRejectsMissingTaskIconField`
- `LifeBoardPlanningTrackFoundationTests.testCanonicalHabitProjectionUsesHistoryWithoutInventingFutureDueWork` — pins `now` to 2024-07-14 but the service appears to consult the real clock, so it only began failing once that date passed
- `PhaseOneRealCoreDataMutationJourneyTests.testEveryBatchFamilyPersistsAndUndoRestoresCanonicalRows` — **claims inbox batch undo does not restore `sectionID`**
- `PhaseOneRealCoreDataMutationJourneyTests.testPendingToTaskMergeUndoRestoresCoreDataTagRelationshipsExactly`

**At least the first and fourth look like genuine defects.** The fourth is an undo-fidelity claim on the path this whole feature depends on and deserves triage.

**To tell your failures from these:** `git stash push -u`, re-run the suspects with `-only-testing:`, compare.

### 9.2 A targeted test run is not evidence

During this work a `-only-testing:` run reported 59 green. The full suite then found two failures — one real contract broken, one flaky test that assumed the deck's first card was `tasks[0]` when it sorts by must-do then UUID (it passed on lucky identifiers). **Always run `./scripts/run-baseline-aware-tests.sh` before claiming green.**

### 9.3 Build serialisation

The documented guard `until ! pgrep -q xcodebuild` **hangs forever** — it matches the persistent `xcodebuildmcp` MCP server. Use:

```bash
until ! pgrep -x xcodebuild; do sleep 15; done
```

Symptom of getting this wrong: a build that produces no output and an `etime` far older than your session. Check `df -h /System/Volumes/Data` first — disk pressure evicts the entire iOS platform.

### 9.4 Adding a Swift file

Every new `.swift` needs **four hand-written `project.pbxproj` inserts**: `PBXBuildFile`, `PBXFileReference` (with `name` *and* group-relative `path`), group `children`, Sources phase. **Never use the `xcodeproj` Ruby gem** — it silently deletes Core Data model versions. Verify:

```bash
python3 -c "import re;s=open('LifeBoard.xcodeproj/project.pbxproj').read();m=re.search(r'isa = XCVersionGroup.*?children = \((.*?)\);',s,re.S);print(len(re.findall(r'xcdatamodel \*/',m.group(1))))"
# must print 23
```

### 9.5 Guardrails

`scripts/token-law-guardrails.sh` is **diff-scoped** — it inspects only *added* lines under `LifeBoard/{View,Views,ViewControllers,Presentation,Foundation,LLM/Views,Onboarding}`. Easiest ways to trip it: a bare `.shadow(`, a raw `.spring(`, `Color.white`/`.black`, `.glassEffect(`, or `.font(.system(`.

`LifeBoard/DesignSystem/` is **not** scanned — it is the correct home for custom `Shape`s that need a raw spring or stroke.

`scripts/phase1-foundation-guardrails.sh` bans `#RRGGBB` anywhere under `LifeBoard/Foundation/**` except `LifeBoardDaypartTokens.swift`.

### 9.6 Signature effects are a closed list of exactly 17

The `.metal` file, `LifeBoardSignatureShaders.functionNames`, the `LifeBoardSignatureEffect` enum and `LifeOSFoundationTests.swift:92` are **one atomic contract**. `warmUp()` is all-or-nothing — one bad name disables **all 17 at runtime**, and `check-xcode-target-membership.sh` only scans `.swift`, so an orphaned `.metal` sails past CI.

**This feature added zero new shaders.** It mounted three that previously existed only in the gallery: `paperGrain` (ritual canvas), `daypartCrossDissolve` (night handoff on close), `dissolveAway` (released rows). `fastingEmberRing` was **declined** — it is a continuous `TimelineView` loop, and DESIGN.md forbids turning any effect into an ambient loop. A closed day is settled state; its ring must not shimmer.

### 9.7 Swift type-checker budget

Chained `filter`/`map` collection expressions have repeatedly blown the type-checker's budget in this target, and the failure mode is a **hanging build**, not a clear error. Two places in this feature were written as explicit `for` loops for exactly that reason (`DayLoopLedger.stamps`, `DayOpenScenarioBuilder.proposal`). Prefer loops over long chains here.

### 9.8 Feature flags

Every new flag needs a `promotedDefaults` entry or `AppOnboardingTests.swift:1054` fails **in both directions**. **DEBUG returns `true` for every staged flag**, so a plain Debug run proves nothing about rollback — use `-LIFEBOARD_DISABLE_<ARG>`.

Flags added by this work, all promoted `true`, all presentation-only:

| Flag | Launch arg | Gates |
|---|---|---|
| `feature.life_os.day_close_v1` | `DAY_CLOSE_V1` | the evening ritual + routes |
| `feature.life_os.day_open_commit_v1` | `DAY_OPEN_COMMIT_V1` | the morning commit act only |
| `feature.life_os.home_loop_spine_v1` | `HOME_LOOP_SPINE_V1` | spine + `.closeLoop` coalesce + "Your dashboard" |

Rolling any of them back hides presentation and **strands nothing** — everything written lives in Plan's own ledger and stays undoable.

---

## 10. File map

### New — production

| File | Lines | Role |
|---|---|---|
| `Foundation/PhaseIII/DayLoopStage.swift` | 139 | `DayLoopStage`, `DayLoopStageResolver`, `DayLoopClosureLog` |
| `Foundation/PhaseIII/DayLoopLedger.swift` | 154 | `DayLoopSummary`, continuity + anchor read-back |
| `Foundation/PhaseIII/DayCloseContracts.swift` | 254 | directions, ribbon, ring summary, acts, load state |
| `Foundation/PhaseIII/DayCloseScenarioBuilder.swift` | 356 | reconciliation → scenario; ribbon builder |
| `Foundation/PhaseIII/DayOpenScenarioBuilder.swift` | 167 | proposal ranking + commitment scenario |
| `Foundation/PhaseIII/DayCloseStore.swift` | 534 | `@Observable` store for both rituals |
| `Foundation/PhaseIII/LifeBoardDayCloseViews.swift` | 777 | both ritual surfaces |
| `DesignSystem/LifeBoardDayRing.swift` | 194 | dual mirrored arcs; composes `LifeBoardCompletionMark` |

### New — tests (1,728 lines)

`DayCloseScenarioBuilderTests`, `DayCloseStoreTests`, `DayLoopStageTests`, `DayLoopLedgerTests`, `DayOpenScenarioBuilderTests`.

### Modified

`LifeBoardFoundationGallery.swift` (spine, ritual entry, rhythm), `LifeOSFoundationShell.swift` (routes, `planningEvent`, chrome), `LifeBoardAppRouter.swift` (routes + stamp), `PlanningCoreModels.swift` (scenario sources, carry candidate), `PlanStore.swift`, `LifeBoardPlanViews.swift` (exhaustive switches), `V2FeatureFlags.swift`, `LocalNotificationService.swift`, `ReflectionNote.swift` (`.dayClose` kind), `PresentationDependencyContainer.swift`, `SceneDelegate.swift`, `WeeklyOperatingUseCases.swift`.

### Design-system primitives reused — do not reinvent

`LifeBoardDirectionalDeck` + `LifeBoardDeckPhysics` (threshold 96, dominance 1.15, VoiceOver action per direction), `LifeBoardCommitControl`, `LifeBoardCompletionMark`, `LifeBoardNumericRoll`, `LifeBoardClaySurface`, `LifeBoardArcDial`, `LifeBoardMotionProfile` / `lifeBoardMotion`, `LifeBoardHaptic`, `DayCompassEngine` + `DayCompassSnoozeStore`.

**Note for the designer:** the SwiftUI-Animations sample repo has already been mined into `LifeBoard/DesignSystem/`. `LifeBoardArcDial` is the CurvedSlider port (with correct gap/wraparound handling) and `LifeBoardCompletionMark` is the ring→tick morph. **Grep before porting anything.** Ports carry an Apache-2.0 attribution header naming the source file; there is a bundled `SwiftUI-Animations-NOTICE.txt`.

---

## 11. Copy rules encoded in this feature

| Rule | Example |
|---|---|
| Say what happened, not what it became | "3 moved to tomorrow" — never "your day is 78% complete" |
| No "overdue" for today's work | These are *unfinished*; the verb is "carry" |
| "Let it go" means `.archived`, never `.deleted` | Kept and never chased. `.deleted` is a sync tombstone and would make the copy a lie |
| Absent renders as words, not zero | "Open day", "not recorded" — never `0%` |
| Two writes are named as two writes | *"Undo puts your tasks back. Your note stays."* |
| Nothing expires | Evening nudge: *"Whenever you're ready — see how the day went and carry what's left."* |
| `.rest` asks for nothing | *"Nothing more is being asked of you today."* No CTA |

---

## 12. Verification — run all of this per change

Serially. Never two concurrent `xcodebuild`.

```bash
bash scripts/check-xcode-target-membership.sh && bash scripts/token-law-guardrails.sh && bash scripts/premium-ui-guardrails.sh && bash scripts/phase1-foundation-guardrails.sh && bash scripts/check-no-print-logs.sh
```

```bash
./scripts/run-baseline-aware-tests.sh   # expect exactly the 5 failures in §9.1
```

```bash
xcodebuild build -workspace LifeBoard.xcworkspace -scheme LifeBoard -destination 'platform=iOS Simulator,id=A2C21181-4F6B-4883-B2FF-1D1B0DB04BBF'
```

```bash
xcodebuild build -workspace LifeBoard.xcworkspace -scheme LifeBoard -destination 'platform=macOS,variant=Mac Catalyst'
```

`LifeOSFoundationTests.swift:92` must stay green asserting **17**. If a change had to edit it, the shader decision was wrong.

### Simulator journeys

DEBUG launch arguments exist specifically so these do not depend on the wall clock (the windows are 05:00–11:00 and 18:00+):

```
-LIFEBOARD_FORCE_DAY_CLOSE     forces the .close stage
-LIFEBOARD_FORCE_DAY_OPEN      forces the .commit stage
-LIFEBOARD_TEST_SEED_DAY_CLOSE seeds 3 tasks committed to today (one .mustDo)
```

Combine with `-UI_TESTING -SKIP_ONBOARDING -LIFEBOARD_TEST_SEED_ESTABLISHED_WORKSPACE`.

1. **M1** — force close at midday in Low Energy → row present → notification route lands on `.dayClose`
2. **M2** — close naming an anchor, relaunch next day → Home names that task; yesterday's line readable
3. **M3** — commit → one `dayOpen` receipt → Undo restores the proposal
4. **M4** — spine order per stage; pinned widgets still render beneath
5. **M5** — break a run, screenshot, run the §5 acceptance test

### Rollback proof

Relaunch with `-LIFEBOARD_DISABLE_DAY_CLOSE_V1`, `-LIFEBOARD_DISABLE_DAY_OPEN_COMMIT_V1`, `-LIFEBOARD_DISABLE_HOME_LOOP_SPINE_V1`. Confirm the surface disappears, the previous section order returns, and everything written while the flag was on survives and stays undoable.

---

## 13. Current state

- **2065 tests, exactly the 5 pre-existing failures.** No regressions.
- **Both destinations build.** All five guardrail scripts pass.
- **Zero new Metal shaders** (registry still 17). **Zero new Core Data model versions.**
- 13 new files (~3,900 lines incl. tests), 19 modified, 4 deleted.
- **Nothing is committed** — the entire change set is in the working tree for review.
