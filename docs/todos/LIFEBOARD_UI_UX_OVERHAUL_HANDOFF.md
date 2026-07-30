# LifeBoard Phase 1 & 2 UI/UX Overhaul — Handoff

**Date:** 2026-07-30
**Branch:** `lifeOS`
**Baseline commit:** `cd4a96a6` (pre-overhaul checkpoint)
**Head at handoff:** `c4e2eefb`
**Audience:** the engineer continuing this work

---

## 1. Read this first — three corrections to the existing docs

These matter more than anything else here. Acting on the old docs will cost you hours.

### 1.1 The Foundation UI suite is NOT green

`LIFEBOARD_PHASE_1_2_IMPLEMENTATION_HANDOFF.md` says *"the suite is green and the
baseline is empty… Any failure you see is one you introduced."* **That is false for
the UI suite.** It also repeatedly records that UI test execution "stalls before
test-host launch" on this machine. **It does not** — tests run fine, 15–55 s each.

Because the doc believed UI tests were unrunnable, the UI suite was evidently never
executed while Phase 1/2 landed. Six tests failed on a clean tree at `cd4a96a6`,
verified by stashing every local change and re-running.

**Current status of those six:**

| Test | Status |
|---|---|
| `testFoundationBacklogDeletionConfirmsUndoesAndPersistsAcrossRelaunch` | ✅ **fixed** in `f753f0fb` |
| `testFoundationHomeExposesCompletePhaseIIHierarchy` | ❌ stale expectation — see §5.1 |
| `testAddToHomeUsesSizePreviewAndProducesUndoReceipt` | ❌ needs seeded user-space widget — §5.1 |
| `testAdaptiveHomeCustomizationCancelAndComposerHandoff` | ❌ needs seeded user-space widget — §5.1 |
| `testFoundationCompactChromeRemainsReadableAcrossScrollAndCapture` | ❌ stale expectation — §5.1 |
| `testFoundationHabitResilienceThirtyDayEditorAtLargestAccessibilitySize` | ❌ not yet investigated |

**Working baseline: those five.** Anything beyond them is yours.
`scripts/lifeboard-test-failure-baseline.txt` is empty and per repo policy must stay
empty — do not add them there.

### 1.2 `-DISABLE_ANIMATIONS` breaks XCUITest scrolling

Do **not** add it to `launchFoundationApp`. It calls
`UIView.setAnimationsEnabled(false)`, which also disables the UIKit animation
machinery `swipeUp()` drives — six tests then fail their "reachable by scrolling"
assertions for a second, unrelated reason. I tried this and reverted it; the reason
is recorded at the call site.

`LifeBoardAnimation.areProcessAnimationsDisabled` already treats plain `-UI_TESTING`
as animations-off, so anything routed through
`LifeBoardMotionProfile.animation(reduceMotion:)` is suppressed in tests without it.

**Consequence:** zoom route transitions are suppressed under `-UI_TESTING`. To *see*
a zoom morph you must launch without that flag (see §6).

### 1.3 The Core Data model check is stale

`LIFEBOARD_PHASE_1_2_IMPLEMENTATION_HANDOFF.md` §2 says the `XCVersionGroup` child
count "must print 22". **It is 23** — `TaskModelV3_BehaviorFlagship` was added by
Phase 2, and there are 23 `.xcdatamodel` directories on disk. Use:

```bash
python3 -c "import re;s=open('LifeBoard.xcodeproj/project.pbxproj').read();m=re.search(r'isa = XCVersionGroup.*?children = \((.*?)\);',s,re.S);print(len(re.findall(r'xcdatamodel \*/',m.group(1))))"
```

Expect **23**. Everything else in that section (hand-edit the pbxproj, never use the
`xcodeproj` gem) is correct and still applies.

---

## 2. Environment (better than the old doc claims)

- iOS **26.5** simulator runtime installed; `LifeBoard Test iPhone`
  (`A2C21181-4F6B-4883-B2FF-1D1B0DB04BBF`) boots and runs tests.
- Xcode 26.5, iOS 26.0 deployment target, Swift 6.
- Disk had 69 GB free. Still check `df -h /System/Volumes/Data` before long sessions.
- **Never run two `xcodebuild` processes concurrently** against this DerivedData.
  `until ! pgrep -q xcodebuild; do sleep 5; done` before each invocation.
- SourceKit is badly unreliable here — it reports `No such module 'UIKit'` and
  `Cannot find type 'InboxItem' in scope` for perfectly valid same-target code.
  **Only `xcodebuild` is ground truth.** Ignore editor diagnostics entirely.
- `timeout` is not available on macOS; don't wrap `xcodebuild` in it.

---

## 3. What shipped (8 commits, `cd4a96a6..c4e2eefb`)

| Commit | Content |
|---|---|
| `2b7adb49` | Shared directional deck primitive; central motion routing; Plan Repair `asyncAfter` correctness fix |
| `3beb0193` | Pending-capture seeder + `resetAppState` leak fix |
| `9ed30f86` | Inbox capture-deck redesign |
| `efd16932` | Documented why Plan rows had no zoom source (superseded by `f753f0fb`) |
| `f753f0fb` | Plan rows open the canonical task route + zoom continuity |
| `0ec813af` | Home solo-card width + customization bootstrap fix |
| `da0dcf28` | Inbox skip persistence + repeated-pass nudge |
| `c4e2eefb` | `LifeBoardCommitControl` + Inbox review sheet primary action |

### 3.1 New design-system API you should reuse

**`LifeBoard/DesignSystem/LifeBoardDirectionalDeck.swift`**
- `LifeBoardDeckDirection` — non-generic top-level enum (`right/left/up/down`). Kept
  non-generic deliberately so `Direction.allCases.count` still works at its Plan call
  site.
- `LifeBoardDeckPhysics` — `direction(translation:predictedEndTranslation:)`,
  `action(for:candidates:)` (generic over action type), `exitOffset`, `tiltDegrees`.
  Thresholds: 96 pt commit, 24 pt minimum intent, 1.15 axis dominance.
- `LifeBoardDirectionalDeck` — renders **only the front card**; depth comes from
  `lifeBoardDeckDepth(remaining:)`. Rendering live sibling cards leaked their content
  when heights differed; don't reintroduce that.
- `PlanRepairDeckDragResolver` (`LifeBoardPlanViews.swift:120`) is now a forwarding
  shim so its 13 test references are untouched.
- `LifeBoardDeckStack` was **deleted** — zero call sites, duplicated the concept with
  its own hardcoded springs.

**`LifeBoard/DesignSystem/LifeBoardCommitControl.swift`**
```swift
LifeBoardCommitControl(
    title: "File It", runningTitle: "Filing", successTitle: "Filed",
    phase: commitPhase,          // AsyncActionPhase<Receipt>
    isEnabled: draft.isValid,
    action: commit
)
```
Label → 48 pt circle → orbiting arc → drawn tick. Uses `KeyframeAnimator` with one
value carrying both mark progress and settle scale, over the existing animatable
`LifeBoardCompletionMark`. Reduce Motion → system indicator + pre-drawn tick.

**`.lifeBoardMotion(_ profile:value:)`** (in `LifeBoardSignatureEffects.swift`) —
use this instead of `.animation(_:value:)` in feature code. It is the only form that
resolves accessibility *and* process-animation flags centrally. Feature code was
writing `reduceMotion ? nil : LifeBoardAnimation.x`, which still animates under
`-UI_TESTING`.

### 3.2 Testing support

- **`-LIFEBOARD_TEST_SEED_INBOX_CAPTURES`** stages three `PendingCapture`s with fixed
  UUIDs (`A1B2C3D4-000{1,2,3}-4000-8000-00000000FEED`): a rich parse (date + duration
  + tag + context), one that duplicates a title the established seed creates (reaches
  the merge path), and one with nothing to parse. Pair it with
  `-LIFEBOARD_TEST_SEED_ESTABLISHED_WORKSPACE`.
- Before this, **nothing seeded `PendingCapture`**, so the Inbox commit and
  duplicate-merge paths were unreachable in any automated run — they gate on
  `InboxItem.requiresCommitBeforeScheduling`, true only for a `.pendingCapture` origin.
- `AppDelegate.resetAppState()` now also clears the App Group pending-capture JSON.
  It previously leaked captures across `-RESET_APP_STATE` launches.

---

## 4. Product decisions already made — do not silently reverse

| Decision | Rationale |
|---|---|
| **Inbox deck has exactly two flick directions** (right = File it, left = Skip) | Only two honest decisions exist. A capture is not a task yet, so there is no disposition to set — `InboxStore` offers `fileCapture`, `mergeCapture`, `discardCapture` and nothing else. Someday/Reference would have to commit first, which is the silent commit this screen exists to prevent. |
| **Right-flick opens review, never commits** | Preserves the locked "captures never commit silently" decision. |
| **Discard is menu-only, never a gesture** | A capture is often the only copy of something typed once from a lock screen. |
| **Skip is not a mutation** | The count lives in `InboxSkipLedger` (App Group defaults), never in the capture record; text, timestamp and id must survive a skip untouched. |
| **Nudge states the count and stops** | `DESIGN.md` bans moralised productivity language. "You've come back to this N times." — no implication it should already be done. |
| **Review sheet stays open until the write succeeds** | A capture survives a failed file by design; dismissing first leaves the failure nowhere to report. |
| **Task card body opens the task; ellipsis owns the menu** | Chosen over tap-for-menu. Required updating `requestBacklogDeletion`. |
| **Menu identifiers are `plan.taskMenu.` / `plan.weekTaskMenu.`** | **Not** `plan.task.menu.` — the backlog test's row query matches the `plan.task.` prefix, so a nested identifier is counted as an extra task and breaks every cardinality assertion. This bit me; don't undo it. |

---

## 5. Remaining work

Ordered. Each step should end buildable with the §1.1 baseline unchanged.

### 5.1 Finish the Home test failures (needs a product decision first)

Three of the five remaining failures encode expectations the product moved past.
**Each needs a decision about the canonical default Home, then a test update:**

- `testFoundationCompactChromeRemainsReadableAcrossScrollAndCapture` expects
  `app.buttons["foundation.capture"]` on Home. The header deliberately yields capture
  to the floating composer on every root except Eva
  (`LifeOSFoundationShell.swift:655`, `headerOwnsCapture`), so two "+" controls don't
  offer the same tray twice. **Decide:** update the test to drive the composer's
  capture control, or restore a header "+" on Home.
- `testFoundationHomeExposesCompletePhaseIIHierarchy` walks seven widgets in a fixed
  order with cumulative `swipeUp()` and no scroll-back, expecting `care` before
  `tasks`. `sectionRole` now places tasks in Today and care in Keep steady, so the
  walk can never succeed. Two of the seven (`scheduleCapacity`, `compactTimeline`) are
  also not placed by default at all. **Decide:** the canonical default placement set
  and order, then rewrite the expected list.
- `testAddToHome…` and `testAdaptiveHomeCustomization…` need at least one user-space
  widget present to find an "Edit widget" control. **Likely fix:** extend the
  established-workspace seed with one user-space placement.
- `testFoundationHabitResilienceThirtyDayEditorAtLargestAccessibilitySize` — not yet
  investigated. Its constraints are strict: the `Toggle` must keep its switch trait,
  `Save` must survive, `"30-day history"` must be reachable by **real vertical
  scrolling** (a plain `VStack` makes the helper spin 10 times and fail), and
  horizontal bounds must hold at AX XXXL.

### 5.2 R4 remainder — Focus depth

`LifeBoardCommitControl` is built and adopted in the Inbox. Still to do:

- Adopt at `task.editor.save` (`LifeOSFoundationShell.swift:2729`), the Focus session
  end (`LifeBoardPlanViews.swift` `activeFocusCard`, ~:1634), and the Track composers.
- Focus countdown: arc-dial / ember treatment on `focusClock` (~:1701). **Leave the
  `.contentTransition(.numericText())` alone** — it already works.
- `focusReflectionCard` (~:1744) onto clay.
- `LifeBoardNumericRoll` on the Plan capacity figure (`capacityCard`, ~:1594).
- `scrollTransition` rise on the daypart-grouped schedule (~:2084).

### 5.3 R5 — Habit graph + Track polish (**riskiest surface**)

- `chartRevealSweep` on `HabitGraphGrid` (`HabitBoardViews.swift:2118`). Note this
  effect is **already live** inside `LifeBoardTrendChart`
  (`LifeBoardCardPrimitives.swift:270`) — only `daypartBloom` is genuinely unmounted.
- Day/Week/Graph lens change via `.lifeBoardMotion(.selection)`.
- Hydration quick-add chips stack vertically and inflate their card, which is what
  drags the row partner into dead space (`LifeBoardTrackFoundationViews.swift`, the
  `hydrationTile` region).
- **Do not** swap `HabitGraphGrid` for `LifeBoardStreakGrid`. It would lose month
  labels and the year-scale horizontal layout — a feature regression the tests cannot
  catch, because the Graph lens is `accessibilityHidden(true)`.
- **HabitBoard tests assert element *types* and pixel geometry**
  (`HabitBoardUITests.swift:112`, `:175`): `habitBoard.pinned.header` and
  `habitBoard.cell.*` must be `otherElements`, `rangeTitle`/`pinnedTitle.*` must be
  `staticTexts`, `window.previous/next` must be `buttons` ≥44×44 with exact labels,
  exactly 7 day headers, and `abs(firstPinnedTitle.minX - pinnedHeader.minX) < 40`.
  Wrapping a row in a `Button` or adding `.accessibilityElement(children: .combine)`
  breaks them.

### 5.4 R6 — Routine guided mode full-screen

- `.sheet` → `.fullScreenCover` at `LifeBoardTrackFoundationViews.swift:212`. It
  already draws full-bleed canvas inside a sheet.
- **Critical:** verify an explicit abandon is reachable in **every** status, including
  `.paused` and `.interrupted` where the body swaps to a Resume block (`RoutineRunner`,
  ~:1362, branch ~:1409). `fullScreenCover` removes the swipe-dismiss path that
  currently triggers `store.abandonRoutine()` via the sheet's `isPresented` setter
  (:213–216), so without this a paused routine becomes an inescapable modal.
- `RoutineRunner`'s body carries two `.font(.system(` lines (~:1381, ~:1389).
  Tokenize them in a separate prior commit **or touch only the call site** — reflowing
  that body makes them added lines and token law fires.

### 5.5 R7 — One new shader + mount `daypartBloom`

- Add `LifeBoardTriageSettle(position, currentColor, size, direction, progress, tint)`
  to the **existing** `LifeBoard/View/Effects/LifeBoardSignatureEffects.metal` and to
  `functionNames` (`LifeBoardSignatureEffects.swift:309`). A one-shot directional warm
  streak on the plane under the Inbox deck, so the surface remembers which way a
  capture went. Nothing in the current list expresses "this went somewhere specific."
- **Never create a new `.metal` file.** `check-xcode-target-membership.sh` only scans
  `.swift`, so an orphaned `.metal` passes CI and then fails
  `LifeBoardSignatureShaders.warmUp()`, which is all-or-nothing and disables **every**
  effect at runtime.
- **Mandatory test:** assert `functionNames.count` equals the `[[stitchable]]` count in
  the `.metal` source. That agreement is currently unenforced, and a misspelling
  silently kills all 16 effects with no failing test.
- Mount `daypartBloom` as a one-shot on a daypart boundary. It takes a `time`
  parameter but must **not** become an ambient loop — `paperGrain` is the only
  sanctioned non-one-shot.

### 5.6 R8 — Documentation truth-up

- `DESIGN.md:344` lists **16** approved effects;
  `docs/design/LIFEBOARD_PRODUCT_UI_UX_GUIDE.md:141` lists **11** and omits five that
  already ship (`chartRevealSweep`, `liquidGlassRefract`, `cardMorphWarp`,
  `paperGrain`, `dissolveAway`). Reconcile both, then add `triageSettle`.
- Fold §1 of this document into
  `LIFEBOARD_PHASE_1_2_IMPLEMENTATION_HANDOFF.md` so the false "suite is green" and
  "tests stall" claims stop misleading the next person.

### 5.7 R9 — Verification matrix (not yet started)

All verification so far has been **iPhone, light appearance only**. Owed:

- **iPad** regular width: Home 8/12-column spans, Plan Week's seven day destinations,
  sidebar navigation. `DashboardFlowLayout`'s new solo-widen pass has only been
  exercised at 4 columns.
- **Mac Catalyst**: proves graceful degradation (shaders and haptics are disabled by
  policy there). Keep `com.apple.developer.healthkit` **out of**
  `LifeBoardCatalyst.entitlements` or the entire Catalyst build fails.
- **Dark appearance** — a designed warm-indigo composition, not an inversion, so it
  breaks independently. Launch with `-AppleInterfaceStyle Dark`.
- Per surface: Reduce Motion, Reduce Transparency, accessibility XXXL, and a VoiceOver
  action for every gesture.
- **No snapshot tests exist anywhere** in this repo (`ChatTranscriptSnapshotTests` and
  `HomeChromeSnapshotPresentationTests` assert on presentation *models*, not images).
  Visual regressions are caught only by looking.

---

## 6. How to run and verify

Per step, serially:

```bash
bash scripts/check-xcode-target-membership.sh && bash scripts/token-law-guardrails.sh && bash scripts/premium-ui-guardrails.sh && bash scripts/phase1-foundation-guardrails.sh && bash scripts/check-no-print-logs.sh
```

Build and install:

```bash
xcodebuild build -workspace LifeBoard.xcworkspace -scheme LifeBoard -destination 'platform=iOS Simulator,id=A2C21181-4F6B-4883-B2FF-1D1B0DB04BBF' -quiet
```

```bash
xcrun simctl install A2C21181-4F6B-4883-B2FF-1D1B0DB04BBF ~/Library/Developer/Xcode/DerivedData/LifeBoard-fqsmzjbjnruqkvdrfnfoftpzpiez/Build/Products/Debug-iphonesimulator/LifeBoard.app
```

Launch with the seeded Inbox. **Omit `-UI_TESTING` when you want to see motion** —
it suppresses token-routed animation and zoom transitions:

```bash
xcrun simctl launch A2C21181-4F6B-4883-B2FF-1D1B0DB04BBF com.saransh1337.To-Do-List -RESET_APP_STATE -SKIP_ONBOARDING -DISABLE_CLOUD_SYNC -LIFEBOARD_ENABLE_LIFE_OS_FOUNDATION -LIFEBOARD_ENABLE_ADAPTIVE_HOME_V2 -LIFEBOARD_ENABLE_LIFE_OS_UNIFIED_PRESENTATION_V2 -LIFEBOARD_ENABLE_PLANNING_CORE_V1 -LIFEBOARD_ENABLE_PLAN_DESTINATION_V1 -LIFEBOARD_TEST_SEED_ESTABLISHED_WORKSPACE -LIFEBOARD_TEST_SEED_INBOX_CAPTURES
```

Reaching the Inbox deck: **Plan** tab → **Inbox** lens.

### Gotchas found while verifying

- Editing the App Group plist with `PlistBuddy` while the app is installed **has no
  effect** — `cfprefsd` caches the domain. Drive state through the app, or delete the
  container.
- Card heights differ, so the deck's control row moves vertically between captures.
  Tall card (with parse chips) puts it near y≈507 pt; short cards near y≈429 pt. Don't
  blind-repeat taps at one coordinate.
- Phase 2 surfaces are gated by `track_behavior_flagship_v1`, which is `false` in
  `promotedDefaults`. They appear on Debug launches only (DEBUG returns `true` for any
  staged flag without an explicit override).

---

## 7. Known defects found but not fixed

| Defect | Location | Notes |
|---|---|---|
| Plan task cards had no route to the task detail | fixed in `f753f0fb` | Contradicted the Stage 2 ledger claim that "every row opens the shared canonical task route" — worth auditing that ledger's other claims. |
| Home customization was unreachable on a fresh install | fixed in `0ec813af` | Bootstrap dead-end: the only control that starts customization lived in a section that only rendered once customization had produced a placement. |
| `homeSectionHeading` ends in a greedy `Spacer` | `LifeBoardFoundationGallery.swift:1150` | It compresses every sibling in its row. It squashed the customize control to 17×14 pt. **Any control you put beside a section heading needs `.fixedSize()`.** |
| Competing zoom identity for notes | `LifeBoardKnowledgeViews.swift:755`, `:1248`, `:1306` | Declares `matchedTransitionSource(id: note.id, in: noteTransition)` in a *private* namespace while `AppRoute.note` also produces `route.note.<uuid>` in the shared one. Resolve before adding note sources. |
| `scheduleCapacity` / `compactTimeline` widgets never placed by default | Home | Surfaced by the hierarchy test; may be intentional, needs a decision. |
| 2-up Home cards with internal `Spacer`s show large dead space | e.g. `careWidget` | The layout no longer force-stretches; the remaining empty space is each widget's own content distribution. Per-widget fix. |

---

## 8. Design contract reminders that bit me

- **Token law scans newly-added lines only**, under
  `LifeBoard/{View,Views,ViewControllers,Presentation,Foundation,LLM/Views,Onboarding}`.
  Forbidden: `.shadow(`, `.spring(`, `.glassEffect(`, `.font(.system(`, `UIColor(`,
  `Color.{red,…,white,black}`, `foregroundStyle(.white)`.
- **`LifeBoard/DesignSystem/` is not scanned at all.** That is where raw springs and
  font construction legally live. This dictates file placement — put new primitives
  there, not in `Foundation/`.
- An **untracked file counts as 100% additions**, so a new file may not carry a line
  that passes today inside a tracked file. `LifeBoardFoundationGallery.swift` holds 25
  `.font(.system(` + 5 `.shadow(` + 2 `.spring(`; extracting any of it requires
  tokenizing first.
- No `#RRGGBB` under `LifeBoard/Foundation` except `LifeBoardDaypartTokens.swift`
  (`LifeBoardSceneHex` is the sanctioned escape hatch).
- Every new `.swift` must be referenced by **basename** in `project.pbxproj`. Four
  hand-edits: `PBXBuildFile`, `PBXFileReference`, group `children`, Sources phase.
  Mirror a sibling in the same group. Then re-check the model count from §1.3.
- Long SwiftUI modifier chains exceed the type-checker's budget in this project. Hoist
  ternaries into locals before the chain — I hit this twice in
  `LifeBoardDirectionalDeck`.
