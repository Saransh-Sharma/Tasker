# LifeBoard — Daily Loop Experience Handoff

**Last reconciled:** 2026-08-03
**Branch:** `lifeOS`
**Last commit:** `0615e939`
**Audience:** the engineer and the designer continuing this, cold.
**Companion docs:** `DAILY_LOOP_HANDOFF.md` (the loop's architecture — read §3 first), `DESIGN.md` (the visual law).

---

## 0. The one-paragraph version

The Daily Loop is functionally complete and has a persistence-backed interaction design. `.repair` is reachable, Review exposes local loop evidence, the deck has directional previews, the liquid ring answers it, four settled clay knots mark completed acts, and ritual routes share zoom transitions. Morning policy is evidence-driven after 14 eligible days; the evening cadence is one suppressible nudge. Overdue Rescue extraction and legacy Home retirement remain later program phases.

---

## 1. State of the tree

### Committed (Phases 0–6)

| Commit | What |
|---|---|
| `dc6f6fc4` | Removed the three unreachable XP widgets |
| `6ab5a1eb` | Drift resolver, repair deck extraction, projection store, Plan views |
| `120a475f` | Day-loop / planning / board tests + accessibility, drift, token-bridge tests |
| `248ab1c6` | Lens picker and token bridge |
| `0615e939` | Handoff docs + token-law guardrail ratchet |

### Uncommitted working tree — 13 modified, 1 new

This is the experience work from the most recent session. It **builds on both destinations, passes all five guardrails, and the suite is at 2092 tests with exactly the five known pre-existing failures** (§6.1).

```
M DESIGN.md                                  ← shader law: 17 → 18
M LifeBoard.xcodeproj/project.pbxproj
M LifeBoard/DesignSystem/LifeBoardAnimations.swift        ← deckSettle, threadAdvance, firstLight
M LifeBoard/DesignSystem/LifeBoardCardPrimitives.swift    ← deck depth cues
M LifeBoard/DesignSystem/LifeBoardDayRing.swift           ← liquid level
M LifeBoard/DesignSystem/LifeBoardSignatureEffects.swift  ← FirstLight registry + modifier
M LifeBoard/Foundation/Design/LifeBoardFoundationGallery.swift  ← .rest, kinetic rhythm, zoom source
M LifeBoard/Foundation/LifeOSFoundationContracts.swift    ← 3 new motion profiles
M LifeBoard/Foundation/Navigation/LifeOSFoundationShell.swift   ← calendar re-point, zoom destinations
M LifeBoard/Foundation/PhaseIII/DayCloseStore.swift       ← remainingCards, reconciliationProgress
M LifeBoard/Foundation/PhaseIII/LifeBoardDayCloseViews.swift    ← deck fix, act thread, previews, proposal settle
M LifeBoard/View/Effects/LifeBoardSignatureEffects.metal  ← LifeBoardFirstLight
M LifeBoardTests/LifeOSFoundationTests.swift              ← shader count 17 → 18
?? LifeBoard/DesignSystem/LifeBoardLiquidLevel.swift      ← 3 shapes + transition ids
```

---

## 2. Read this before you touch anything

These are not style preferences. Each one is load-bearing and each has already caused a real defect.

**`LifeBoard/Foundation/**` is token-law scoped.** In `LifeBoardDayCloseViews.swift` and `LifeBoardFoundationGallery.swift` you cannot write `.spring(`, `.shadow(`, `.glassEffect(`, `.font(.system(`, `UIColor(`, `Color.white/.black/…`, or `LBColorTokens.`. New springs go in `LifeBoard/DesignSystem/LifeBoardAnimations.swift` (unscanned) and are consumed via `lifeBoardMotion(_:value:)`. New depth comes from `lifeBoardClaySurface`. New geometry goes in a `Shape` under `DesignSystem/`. The guardrail is **diff-scoped**, so *moving* existing code into Foundation converts baselined debt into a CI failure.

**The shader registry is one atomic four-part contract.** `LifeBoard/View/Effects/LifeBoardSignatureEffects.metal` (the only `.metal` file), `LifeBoardSignatureShaders.functionNames`, the count in `LifeOSFoundationTests.swift`, and `DESIGN.md`'s approved list. `warmUp()` is **all-or-nothing** — one bad name disables *every* signature effect at runtime, silently, with nothing logged at the UI layer. `check-xcode-target-membership.sh` only scans `.swift`, so an orphaned `.metal` sails past CI. The count is now **18**.

> There is existing drift here: `LifeBoardCTABezel.metal` is a second `.metal` file whose function is absent from the registry. Do not add to that mistake.

**Absent ≠ zero.** `plannedMinutes` is `Int?` and renders "Open day", never a 0% arc. `focusRatio` is `nil` when nothing was planned and is **not clamped to 1**. `reconciliationProgress` returns `Double?` — `nil` when there was never anything to decide. `hasNoHistory` suppresses the rhythm line entirely.

**Empty is a success state.** A cleared deck renders a filled warm clay card reading "Everything you committed to is done." It must **never** be a `ContentUnavailableView` — that is what failure looks like here.

**Persisted-state boundary before success feedback.** The deck plays `.pick` on arm and `.commit` only after the batch lands. The morning commit fires `FirstLight` *after* `await store.commitOpen()` behind an `alreadyCommitted` check. Do not "simplify" these into the tap handler.

**No ambient loops.** Every effect except static `paperGrain` is one-shot and settles. A closed day must not shimmer. The liquid level advances its phase once per decision and stops; `FirstLightModifier` unmounts its own `TimelineView` after 0.72 s for exactly this reason.

**No new Core Data model version.** The loop's memory is applied `PlanningMutationReceipt` rows. Undo flips receipt state to `.undone`, so an undone close stops counting everywhere for free. Never add a parallel counter — it will drift. Never use `pinOrder == 0` as provenance.

---

## 3. What was built, and why it is the way it is

### 3.1 The deck bug (the highest-leverage fix in the whole effort)

`LifeBoardDayCloseViews.swift` passed `items: [card]` — a **single-element array** — to `LifeBoardDirectionalDeck`. `lifeBoardDeckDepth(remaining:)` sizes the backing stack from `count`, so it always saw `1` and **never drew backing cards**. An eight-task evening looked identical to a one-task evening.

Fixed by adding `DayCloseStore.remainingCards` and passing the real queue. The deck still renders only `items.first`; the rest is depth.

### 3.2 The ring answers the deck

The ring sits at the top of the ritual and the deck sits below it, so deciding a card used to change nothing you could see without scrolling back up. `LifeBoardDayRing` now takes `settledLevel: Double?` and draws `LifeBoardLiquidLevel` inside the inner track, rising with `decidedCount / (decidedCount + remainingCount)`.

Both `phase` and `level` live in one `AnimatablePair`, so a level change carries its own ripple. Amplitude tapers via `sin(level * π)` — empty and full sit dead flat, because a settled day should not slosh.

### 3.3 Each direction previews itself

All four directions used to differ only by a label. Now, while armed:

| Direction | Behaviour | Why |
|---|---|---|
| `.tomorrow` | leans in (scale 1.012) | being carried forward |
| `.someday` | recedes (scale 0.955, opacity 0.82) | being put off, not thrown away |
| `.doneAnyway` | stays square and firm | its one-shot burst belongs only on the persisted summary |
| `.release` | begins to erode via `dissolveAway` at 0.22 | "let it go" should *look* like letting go |

You feel the consequence before you commit, and you can back out by returning to centre. Nothing is persisted until the batch lands.

### 3.4 The act thread

`DayCloseAct` was modelled and never rendered. A 2 pt `LifeBoardActThread` runs down the left of the four close acts, filling on **settled** acts — deck cleared, note saved, anchor chosen, day closed — not on scroll position. Scrolling past the reflection without writing one has not settled it.

Deliberately not a step indicator: the ritual stays one scroll, because paging it would turn "I only wanted to write the line" into four taps.

### 3.5 Entering through a zoom

`dayRitualEntry` carries `lifeBoardTransitionSource`; both ritual routes carry `lifeBoardZoomDestination`. Ids are named once in `LifeBoardDayLoopTransition` because the source lives on Home and the destination lives in the shell's route switch — a typo would silently degrade to a plain push, which reads as "the animation is broken" rather than "the ids don't match".

### 3.6 The morning gets a signature moment

The evening has the ring morph, the cross-dissolve and the burst. The morning had nothing. `LifeBoardFirstLight` (shader #18) sweeps one warm band across the committed proposal, ~700 ms, screen-blended so readable ink keeps its contrast. The proposal rows sit loosely leaned and square up on commit — chaos to intention, which is what the act means.

`daypartBloom` was rejected for this: it is root-atmosphere-only by law and semantically wrong, because committing to a day does not change the hour.

### 3.7 `.rest`

The closed-day ring at 64 pt beside the sentence — a record, not a second celebration. No `TimelineView`, no CTA. Closing a day must not open a new obligation.

---

## 4. What remains — for the developer

### 4.1 Seeded verification (do this first — it gates everything else)

**Most of §3 has never been watched.** The redesign compiles, is covered by unit tests, and the surfaces render — but the deck was never populated on device because the seeder produced zero tasks.

Verified on device: the spine renders with stage title "Ending the day"; the ritual row navigates in; the act thread draws; the ring reads "Open day" not 0%; the empty deck is a filled success card; Metal initialises with no shader warnings.

**Not exercised:** backing cards, ring liquid level, direction previews, bring-back shuffle, rolling counter, proposal settle, `FirstLight`, `.rest`.

The blocker is that `-LIFEBOARD_TEST_SEED_DAY_CLOSE` produced no tasks even alongside `-LIFEBOARD_TEST_SEED_ESTABLISHED_WORKSPACE`. Start at `LifeBoard/TestingSupport/` and check its preconditions, or create three tasks by hand in Plan (one `.mustDo`) and force the stage. Then run the table in §6.3.

### 4.2 Finish the direction vocabulary

`.doneAnyway` still has no distinct feeling. `completionBurst` is built, sanctioned and currently unused on this surface — fire it at the card centre on commit. This is ~10 lines and completes §3.3.

### 4.3 Overdue Rescue extraction (the real remaining engineering)

`presentPlanOverdueRescue` (`LifeOSFoundationShell.swift`) calls `homeViewModel.openOverdueRescueFromHome`. That is **not** analytics — it is the entire fetch → eligibility-filter → plan → present pipeline.

**The deck is already decoupled.** `grep HomeViewModel` across all 40 files / 3,861 lines under `Presentation/Home/Modals/OverdueRescue/` returns **zero hits**. Only the launch is entangled, in one file (`SunriseAppShellView+RescueOverlays.swift`).

Build `OverdueRescueLaunchCoordinator` (`@MainActor @Observable`) owning `launcherState / plan / tasksByID / referenceDate / isPresented`, fed by `useCaseCoordinator.getTasks.getOverdueTasks` + `getOverdueRescuePlanUseCase` — both reachable without `HomeViewModel`.

Two extractions:
1. **Eligibility — nearly free.** `isOverdueRescueDeckEligibleTask` is a one-line wrapper over the already-free static `OverdueRescueEligibilityPolicy.isStaleOverdueTask`. Call that directly.
2. **Batch apply/undo — the real cost.** `applyRescuePlan` / `undoRescueRun` route through `applyEvaBatchPlan` (~120 lines: task resolution, staleness re-validation, `buildEvaBatchProposalUseCase`, `assistantActionPipeline.propose/confirm`). Extract to a `RescueBatchApplier`. The logic moves; the behaviour must not.

Defer the `.universalInputDayRescue` origin — it needs `dayRescueTasksByID`, a second `HomeViewModel` pipeline, to serve one entry point.

### 4.4 Token consolidation — read the measurement before planning it

**Of 13 foundation statics with a plausible semantic role, only 2 resolve identically.** These are not two names for one palette; they are two palettes that drifted apart, mostly in dark mode and under Increased Contrast. `LifeBoardTokenBridge` records which is which and `TokenBridgeEquivalenceTests` pins both sets.

Only `foundationCanvas` and `foundationDanger` are safe renames. Everything else **moves pixels** and needs a design decision first.

Two of those divergences look like live defects, worth fixing independently of any migration:
- `.strokeHairline` does **not** strengthen under Increased Contrast while `foundationHairline` does. Surfaces on the role are not honouring the setting.
- `.actionFocus` is 42 % alpha against an opaque `foundationFocusRing`. A focus ring is an accessibility affordance; these are materially different rings.

The guardrail ratchet already blocks *new* `LBColorTokens.` on added lines. Migrate file-by-file, densest first, one commit each: `LifeBoardPlanViews.swift` → `LifeBoardFoundationGallery.swift` → `LifeOSFoundationShell.swift` → `LifeBoardTrackFoundationViews.swift`. **The 702 raw `.font(.headline)` calls are out of scope** — they are Dynamic Type-backed and `DESIGN.md` bans raw *fixed* sizes, which these are not.

### 4.5 Plan's remaining IA work

`taskCard` still renders every task as a raised clay card; `DESIGN.md` says task rows stay open. On a ten-task day the screen is ~95 % card. Converting it is behavioural, not cosmetic: `.foundationClayCard()` currently supplies the padding and full-width frame that `.draggable`, `lifeBoardTransitionSource` and the canvas drop targets depend on, so the open row needs an explicit `contentShape`. **Do it alone, in its own commit.**

### 4.6 Ambient layer

`CompleteTaskFromWidgetIntent` / `DeferTaskFromWidgetIntent` stash a command and launch the app; only `CaptureToInboxIntent` is truly background. Making them background needs a write path from the extension — spike before committing. Watch path and Live Activity remain deferred, and §6.5 of the original handoff still stands: **do not make the evening notification more insistent.**

---

## 5. Decisions waiting on a human

### 5.1 The legacy Home branch — the one real judgement call

`LegacyHomeControllerHost` is now referenced by exactly one thing. The calendar deep link that used to reach into `HomeViewController` has been re-pointed at `.planDay` (the same route `lifeboard://calendar/schedule` already used, so two paths that disagreed now agree).

**But deleting it is not free.** It is the fallback when `adaptiveHomeV2Enabled` is false *or* `homeProjectionAdapter` is nil. Delete it and `-LIFEBOARD_DISABLE_ADAPTIVE_HOME_V2` renders a **blank Home** — losing a rollback guarantee this project treats as load-bearing.

Choose deliberately:
- **(a)** keep the branch, accept the legacy render path stays; or
- **(b)** delete it *and* drop the flag to non-optional, accepting no rollback.

Do not delete it silently as "cleanup".

### 5.2 `HomeViewController` cannot be deleted either way

Three things still hang off it: `HomeProjectionAdapter` (which is what drives *LifeOS Home itself*), onboarding/first-run (`SceneDelegate` — without `loadViewIfNeeded()` **first run never appears**), and the notification deep-link bridge (`HomeNavigationEventAdapter`, serving focus/chat/quickadd/weekly/habit links).

So the §8 deletions in the original handoff — the `DailyReflection*` family (~1500 lines, including `DailyPlanDraft`, a second competing "the user committed to a day" record) and the celebration pipeline — **remain blocked**. This is a five-dependency problem, not a two-dependency one.

### 5.3 The "unedited proposal" signal is local evidence

It cannot be derived from receipts, so `DayOpenProposalSignalStore` writes a versioned local sidecar only after `scenarios.apply` succeeds. It is keyed by receipt ID and joined only to currently applied open receipts. A missing or failed sidecar remains unknown, never “edited,” and cannot fail or roll back the commitment. Receipt source strings and shared planning payloads are unchanged.

### 5.4 Shared copy change

`.leaveUnchanged` now reads **"Leave it as it is"** in both Plan and Home (was "Leave unchanged"). Deliberately not "Leave *today* as it is" — Plan can show the deck for a day the person scrolled back to. This was changed during an extraction that otherwise promised visual parity; revert if you disagree.

---

## 6. Verification

### 6.1 The gate

```bash
./scripts/run-baseline-aware-tests.sh
```

**Exits `1` on a clean tree, and that is the expected state.** `scripts/lifeboard-test-failure-baseline.txt` is 0 bytes, and five tests genuinely fail:

- `ArchitectureBoundaryTests/testViewLayerDoesNotUseSingletonDependencyContainers`
- `HabitCoreDataSchemaRegressionTests/testBootstrapSchemaValidationRejectsMissingTaskIconField`
- `LifeBoardPlanningTrackFoundationTests/testCanonicalHabitProjectionUsesHistoryWithoutInventingFutureDueWork`
- `PhaseOneRealCoreDataMutationJourneyTests/testEveryBatchFamilyPersistsAndUndoRestoresCanonicalRows`
- `PhaseOneRealCoreDataMutationJourneyTests/testPendingToTaskMergeUndoRestoresCoreDataTagRelationshipsExactly`

**Green means exactly this five-line diff and nothing more** — never a zero exit code. Do not fill the baseline back in: all 51 entries once baselined there turned out to be real defects, eight of which reached users.

### 6.2 Everything else, serially — never two concurrent `xcodebuild`

```bash
until ! pgrep -x xcodebuild; do sleep 15; done
```
> `pgrep -q` matches the persistent MCP server and hangs forever. Use `-x`.

```bash
bash scripts/token-law-guardrails.sh && bash scripts/premium-ui-guardrails.sh && bash scripts/phase1-foundation-guardrails.sh && bash scripts/check-no-print-logs.sh && bash scripts/check-xcode-target-membership.sh
```

```bash
xcodebuild build -workspace LifeBoard.xcworkspace -scheme LifeBoard -destination 'platform=iOS Simulator,id=A2C21181-4F6B-4883-B2FF-1D1B0DB04BBF'
xcodebuild build -workspace LifeBoard.xcworkspace -scheme LifeBoard -destination 'platform=macOS,variant=Mac Catalyst'
```

Shader parity — all three must agree at **18**:
```bash
grep -c '\[\[ stitchable \]\]' LifeBoard/View/Effects/LifeBoardSignatureEffects.metal
```

Core Data model versions must still print **23**:
```bash
python3 -c "import re;s=open('LifeBoard.xcodeproj/project.pbxproj').read();m=re.search(r'isa = XCVersionGroup.*?children = \((.*?)\);',s,re.S);print(len(re.findall(r'xcdatamodel \*/',m.group(1))))"
```

### 6.3 Simulator journeys

| Journey | What must be true |
|---|---|
| Evening ritual | Backing cards visible with 3+ pending; ring level rises per decision; each direction feels distinct; `.release` erodes; undo shuffles back |
| Enter / exit | Zooms from the Home row, not a push |
| Morning | Proposal settles into order; `FirstLight` fires once, on commit only |
| `.rest` | Arrives, settles, and is completely still |
| Rhythm | Break a 10-day run: the eye must land on "9 of 14" before "1"; nothing warm-red; no recovery offer |
| Reduce Motion | Every surface complete and operable; no travel |
| VoiceOver | All four deck directions reachable as rotor actions |
| Rollback | `-LIFEBOARD_DISABLE_DAY_CLOSE_V1` etc. — surfaces vanish, nothing is stranded |

### 6.4 Simulator traps — each of these silently verifies the wrong thing

**1. There are multiple DerivedData directories. Pick by mtime, never by glob order.** This cost hours: the alphabetically-first directory held a build from *a day earlier*, predating whole milestones. It rendered pre-M4 Home ("Close the loop" as a section, "0 day continuity", "Your space") and made every `-LIFEBOARD_FORCE_*` argument look broken.

```bash
for d in ~/Library/Developer/Xcode/DerivedData/LifeBoard-*; do
  A="$d/Build/Products/Debug-iphonesimulator/LifeBoard.app/LifeBoard"
  [ -f "$A" ] && echo "$(stat -f '%Sm' "$A")  $d"
done
```

**2. Debug builds split code into `LifeBoard.debug.dylib`.** `strings` on the app binary finds none of your literals even in a correct build. Grep the dylib — fastest way to confirm the binary contains your work *before* installing:

```bash
strings "…/LifeBoard.app/LifeBoard.debug.dylib" | grep -F "Your dashboard"
```

**3. `run-baseline-aware-tests.sh` drives `LifeBoard Test iPhone` — the same device you screenshot on.** Driving the simulator during a suite run produced a spurious sixth failure that vanished on a clean re-run. Never do both at once.

**4. `-SKIP_ONBOARDING` does not take on a fresh install.** The first launch after `simctl install` always shows onboarding; the second honours it. Script two launches.

Also: bundle id is `com.saransh1337.To-Do-List`. App Group is `group.com.saransh1337.tasker.shared`. Test runs pollute the app container and can leave a stale pending command that pushes a dead `.task` route at every launch, unpoppable — `xcrun simctl erase` is the only reliable fix. There is **no URL host** for `.dayClose`/`.dayOpen` (only a notification route), so the rituals cannot be deep-linked; reach them via the Home spine with `-LIFEBOARD_FORCE_DAY_CLOSE`.

---

## 7. For the designer

### 7.1 The thesis

**A day is gathered, decided, settled, released, and put down.** Warm, tactile, unhurried. The loop should feel like closing a notebook, not submitting a form. Nothing celebratory fires before something is actually persisted.

### 7.2 Copy law, already encoded

| Rule | Example |
|---|---|
| Say what happened, not what it became | "3 moved to tomorrow" — never "your day is 78% complete" |
| No "overdue" for today's work | These are *unfinished*; the verb is "carry" |
| "Let it go" means `.archived`, never `.deleted` | Kept and never chased |
| Absent renders as words | "Open day", "not recorded" — never `0%` |
| Two writes are named as two writes | "Undo puts your tasks back. Your note stays." |
| Nothing expires | "Whenever you're ready — see how the day went and carry what's left." |
| `.rest` asks for nothing | "Nothing more is being asked of you today." No CTA |

### 7.3 The rhythm line — the acceptance test that is not optional

Renders as `"9 of 14 days · 4 days running"`.

Both numbers render **at the same size, in the same label**. Consistency leads so the smaller broken-run number does not become the first fact. It wraps to two lines rather than truncating.

**Run this:** deliberately break a 10-day run and screenshot Home. If the eye lands on the `1` before the `9 of 14`, if anything turns warm-red, or if any copy offers to help you recover — it fails and gets re-laid-out.

### 7.4 What needs design attention next

| Surface | State | Note |
|---|---|---|
| **Reconcile deck** | Implemented; visual approval pending | Backing cards, four direction previews, liquid ring, Undo shuffle, and zoom entry are wired. |
| **Act thread** | Implemented; visual approval pending | Four clay knots settle from completed acts, not scroll position. |
| **`.doneAnyway`** | Implemented; visual approval pending | Square and firm while armed; burst only after persistence. |
| **`.rest`** | Rebuilt, unverified | Should be the calmest screen in the app |
| **Morning proposal** | Loose-to-settled | Lean magnitudes are `[6, -4, 9, -7, 3]` pt with 0.22× rotation — tune to taste |
| **Plan day** | Card wall | Ten tasks = ten raised cards; §4.5 |

### 7.5 Design-system primitives — grep before you invent

`LifeBoardDirectionalDeck`, `LifeBoardDeckPhysics`, `LifeBoardCommitControl`, `LifeBoardCompletionMark` (ring→tick morph), `LifeBoardNumericRoll`, `LifeBoardClaySurface`, `LifeBoardArcDial`, `LifeBoardDayRing`, `LifeBoardLiquidLevel`, `LifeBoardActThread`, `LifeBoardLensPicker`, `LifeBoardKineticText`, `LifeBoardMotionProfile`, `LifeBoardHaptic`, `LifeBoardAtmosphereRenderer`.

The 18 signature effects include `dissolveAway`, `completionBurst`, `daypartBloom`, `daypartCrossDissolve`, `chartRevealSweep`, `cardMorphWarp`, `paperGrain`, `contextLens`, `firstLight`.

The SwiftUI-Animations sample repo has already been mined into `LifeBoard/DesignSystem/` — `LifeBoardArcDial` is the CurvedSlider port, `LifeBoardCompletionMark` the ring→tick morph, `LifeBoardLiquidLevel` the wave fill, and the deck depth cues come from Cards Shuffle. Ports carry an Apache-2.0 attribution header naming the source file. **No fonts or image assets were ported** — ClashGrotesk ships in that repo with no license file.

### 7.6 Accessibility is a design constraint here, not a QA step

Contrast is enforced by test across 72 ink-on-surface pairs in light/dark × normal/high contrast. The redesign brief's `ink.secondary #746757` and `ink.tertiary #9B8F7E` are **rejected and pinned** — they measured 4.446:1 and ~2.95:1 against the 4.5:1 and 3:1 floors. A future "align with the design doc" pass cannot quietly reintroduce them.

Every motion profile must return `nil` under Reduce Motion (tested). Selection must be carried by shape *and* weight, never tint alone. Every gesture needs a labelled alternative and a VoiceOver action — the deck's direction pad is not decoration.

---

## 8. Suggested order

1. **§4.1 seeded verification** — unblocks judging everything else
2. **§4.2 `.doneAnyway`** — ~10 lines, completes the direction vocabulary
3. **§5.1 decide the legacy Home branch** — a conversation, not a task
4. **§4.3 Overdue Rescue extraction** — the real remaining engineering
5. **§4.5 Plan open rows** — alone, own commit
6. **§4.4 token migration** — continuous, file-by-file, lowest risk per step
7. **§4.6 ambient layer** — spike first

Items 1–2 are hours. Item 4 is the only one that is genuinely days.
