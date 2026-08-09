# LifeBoard Phase 1 & 2 UI/UX Overhaul — Final Implementation Record

**Status:** implemented and locally verified

**Last updated:** 2026-07-30

**Branch:** `lifeOS`

**Pre-overhaul baseline:** `cd4a96a6`

**Implementation state:** working-tree changes; not staged or committed at the time of this record

**Audience:** product, design, engineering, QA, and future coding agents

This document is the canonical handoff for the Phase 1 and Phase 2 UI/UX
overhaul. It supersedes the earlier “remaining work” status in this file. The
historical implementation handoff remains useful for persistence and migration
context, but this record is authoritative for the current interaction design,
accessibility behavior, motion system, test contracts, and verification results.

Normative references:

- [`DESIGN.md`](../../DESIGN.md) defines the visual and implementation laws.
- [`LIFEBOARD_PRODUCT_UI_UX_GUIDE.md`](../design/LIFEBOARD_PRODUCT_UI_UX_GUIDE.md)
  defines cross-feature product behavior.
- [`LIFEBOARD_PHASE_1_2_IMPLEMENTATION_HANDOFF.md`](LIFEBOARD_PHASE_1_2_IMPLEMENTATION_HANDOFF.md)
  contains the broader Phase 1/2 architecture and migration history.

---

## 1. Executive summary

The overhaul is implemented across Home, Inbox, Plan, Focus, Track, Habit, and
guided Routines. It preserves the warm paper/clay design language and canonical
domain semantics while making the experience more focused, truthful, accessible,
and motion-rich.

The final result includes:

- an accessibility-safe Track layout through AX XXXL;
- focused Home customization with no overlapping global chrome;
- stable, feature-qualified automation identifiers;
- real async commit state for task, Focus, reflection, and Track composer saves;
- a presentation-only Focus dial with one-Hz numeric updates;
- bounded Habit graph and Routine step motion;
- a non-interactively-dismissible full-screen Routine runner;
- a one-shot Inbox triage shader and semantic daypart bloom;
- an exact 17-function Swift/Metal shader registry contract;
- corrected UI tests that encode current product decisions instead of obsolete UI;
- reconciled design and implementation documentation.

No external API, production persistence schema, or production Home-default change
was required. A deterministic user-space widget is injected only in the UI-test
workspace.

### Acceptance status

| Slice | Status | Evidence |
|---|---:|---|
| Baseline contract and AX blocker | Complete | Five targeted UI journeys pass together |
| Home and Plan density | Complete | Focused customization test and visual evidence |
| Truthful async commits | Complete | Real store phases; focused unit/UI coverage |
| Signature Focus experience | Complete | Dial mapping test and successful platform builds |
| Habit, Track, and Routine motion | Complete | Central motion policies and build/test validation |
| Triage and daypart effects | Complete | Exact Swift/Metal registry test; count is 17 |
| Documentation and provenance | Complete | This record plus canonical guide updates |
| Platform compilation | Complete | iPhone 17 Pro, iPad A16, and Mac Catalyst |

---

## 2. Product decisions that are now locked

These decisions are deliberate. Do not reverse them to satisfy an old screenshot
or stale test.

### Home

- Home has one capture entry point: the shared Life Thread composer. Do not restore
  a second header capture button.
- Production defaults remain tasks, care, routines, journal, and
  progress/reflection.
- Schedule capacity and compact timeline remain optional widgets.
- Home customization is a distinct work mode. The dock and composer disappear
  while editing; one restrained Cancel/Done bar owns the bottom safe area.
- User-space emptiness is an intentional state, not an error.
- The UI-test-only seeded Life Moment does not alter persisted production defaults.

### Inbox

- The deck has two flick directions: right opens review; left skips.
- Right flick never silently commits a capture.
- Skip preserves the capture and records only skip history.
- Discard remains menu-only.
- `triageSettle` is decorative confirmation on the under-deck plane. It never
  communicates state by itself and never blocks input.

### Plan and Focus

- Task rows route to the canonical task editor with shared-element zoom continuity.
- Capacity is supporting context, not a second primary action.
- Active Focus has one dominant Pause/Resume action.
- Interruption, phase advance, completion, continuation, and abandonment live in
  the secondary menu.
- Ending Focus and saving reflection use real mutation state. Success is never
  synthesized with a timer.
- A failed Focus end must not mark its companion completed.

### Track and Routines

- Track has Today, Areas, and History lenses. Resilience settings live under Areas.
- Accessibility text sizes collapse multi-column card grids to one column.
- Hydration quick logging stays immediate; target editing is a quiet header action.
- Guided Routines use one full-screen presentation path.
- The runner cannot be dismissed by a swipe. Explicit End is always reachable and
  abandonment requires confirmation.
- Continue/Resume is primary. Pause and Skip are secondary.

---

## 3. Architecture and ownership

The overhaul intentionally separates domain state, presentation state, motion,
and effects.

| Concern | Owner | Rule |
|---|---|---|
| Task persistence | `TaskEditorStore` and canonical mutation services | Views observe `commitPhase`; they do not invent success |
| Focus timer/session state | `PlanStore` and Focus command services | `LifeBoardFocusDial` never owns or advances time |
| Track persistence | `TrackFoundationStore` and Phase II/IV repositories | Composer sheets await canonical store calls |
| Routine lifecycle | `TrackFoundationStore` and routine execution service | The full-screen runner dispatches canonical commands |
| Home layout transaction | `AdaptiveHomeStore` and `HomeLayoutDraft` | Cancel restores the pre-edit transaction |
| Motion timing | `LifeBoardMotionProfile` / `.lifeBoardMotion` | Feature views do not add independent implicit paths |
| Shader availability | `LifeBoardSignatureShaders` | Warm-up is all-or-nothing; every declaration must match |
| Accessibility fallback | environment and `LifeBoardMotionPolicy` | Meaning and operability cannot depend on animation |

### Key files

| Area | Primary implementation |
|---|---|
| Root chrome, capture, routing, daypart boundary | `LifeBoard/Foundation/Navigation/LifeOSFoundationShell.swift` |
| Adaptive Home and customization | `LifeBoard/Foundation/Design/LifeBoardFoundationGallery.swift` |
| Inbox deck and triage mounting | `LifeBoard/Foundation/PhaseIII/LifeBoardInboxView.swift` |
| Plan, Focus dial composition, reflection | `LifeBoard/Foundation/PhaseIII/LifeBoardPlanViews.swift` |
| Focus commit state | `LifeBoard/Foundation/PhaseIII/PlanStore.swift` |
| Task commit state | `LifeBoard/Foundation/PhaseIII/TaskExecutionContracts.swift` |
| Track, composers, and Routine runner | `LifeBoard/Foundation/PhaseIV/LifeBoardTrackFoundationViews.swift` |
| Habit lens and graph reveal | `LifeBoard/View/HabitBoardViews.swift` |
| Shared Focus dial | `LifeBoard/DesignSystem/LifeBoardCardPrimitives.swift` |
| Swift shader wrappers and policy | `LifeBoard/DesignSystem/LifeBoardSignatureEffects.swift` |
| Metal stitchables | `LifeBoard/View/Effects/LifeBoardSignatureEffects.metal` |

---

## 4. Detailed implementation

### 4.1 Track accessibility and layout

The high-severity baseline defect was fixed at the layout level rather than hidden
with truncation.

- `LifeBoardScreenScaffold` uses intrinsic geometry and switches header layout at
  accessibility sizes.
- Track avoids mounting a duplicate atmosphere when the shell already hosts it.
- The Track atmosphere header is compact at accessibility sizes and cannot clip
  the readable header.
- Care and area card grids use one column when
  `dynamicTypeSize.isAccessibilitySize`.
- Scroll content reserves additional bottom space for floating chrome.
- Lens controls remain horizontally reachable.
- Hydration uses two 44-point quick actions, `+250 ml` and `+500 ml`.
- Hydration target editing moved out of the quick-action row.
- The resilience editor remains vertically scrollable and preserves the native
  switch trait of “Allow recovery completions.”

The layout must continue to prefer stacking and scrolling over smaller type,
compressed controls, or letter-by-letter wrapping.

### 4.2 Home density and customization

Normal Home remains calm and curated. Customization becomes a focused editing
workspace:

- global dock and composer are hidden;
- the shell reserves no phantom chrome height;
- one bottom action bar exposes Cancel and Done;
- placement drag handles and edit menus use stable identifiers;
- persistent “Pinned” badges were removed;
- card edit chrome is subordinate to card content;
- UI-test seeding adds one pinned Life Moment in user space using deterministic ID
  `D6ED45B2-1267-4C2C-9A91-A3F5503D51AF`;
- the seed is gated by `-LIFEBOARD_TEST_SEED_HOME_USER_SPACE`.

The seed is built in memory after Home loads. It is not part of
`curatedHomePlacements()` and must never migrate into production defaults.

### 4.3 Plan density

- Scheduled entries use the shared scroll entrance.
- Capacity duration uses `LifeBoardNumericRoll`.
- Existing canonical task zoom transitions are preserved.
- Existing numeric Focus clock transitions are preserved.
- Supporting metrics remain visually quieter than the active planning decision.

### 4.4 Truthful async commit controls

`LifeBoardCommitControl` is the only full success-state commit animation used in
the overhaul. It consumes `AsyncActionPhase<Receipt>`:

```swift
enum AsyncActionPhase<Receipt> {
    case idle
    case running(progress: Double?)
    case success(receipt: Receipt)
    case recoverableFailure(RecoverableActionError)
    case cancelled
}
```

Behavioral contract:

1. The view validates local input.
2. The store sets `.running` immediately before the canonical mutation.
3. Duplicate taps are disabled while running.
4. The sheet or surface remains mounted.
5. Only a successful mutation produces a receipt and `.success`.
6. Failure preserves input and exposes inline recovery.
7. Dismissal occurs only after confirmed success.

Adopted surfaces:

- task editor save: `task.editor.save`;
- Focus end/continue/abandon: `plan.focus.commit`;
- Focus reflection: `plan.focus.reflection.commit`;
- Track mood, sleep, routine, hydration target, goal, and resilience composers.

Track mutations that do not return a domain receipt use `TrackComposerReceipt`,
containing only an operation ID and completion date created after the awaited store
call succeeds.

One-tap hydration logging intentionally does not use the full commit morph. It gives
immediate intent feedback and updates the numeric state.

### 4.5 Focus dial and active-session hierarchy

`LifeBoardFocusDial` is a presentation-only generic component. It receives settled
progress, pause state, an accessibility value, and center content. It does not own
a timer, session command, or persistence.

`LifeBoardFocusDialMetrics.elapsedFraction` maps total and remaining duration to a
clamped `0...1` elapsed fraction:

- absent or non-positive total duration produces `nil`;
- remaining time greater than total clamps to `0`;
- negative remaining time clamps to `1`.

The active Focus card:

- is one dominant opaque clay surface;
- presents the session phase and intention;
- centers the dial and numeric clock;
- updates through a one-Hz `TimelineView`;
- uses Pause/Resume as the sole primary action;
- moves interruption, next phase, and end outcomes into a More menu;
- asks for an explicit outcome before mounting the commit control;
- announces values such as “18 minutes remaining, paused.”

Reduce Motion keeps the dial static between supplied values. There is no
continuously running shader.

### 4.6 Habit graph motion

- Habit lens selection uses `.lifeBoardMotion(.selection, value:)`.
- Duplicate implicit animation paths were removed.
- `chartRevealSweep` runs once when valid chart data first appears or the material
  range changes.
- Reduce Motion presents the settled chart immediately.
- The existing month/year graph, labels, navigation buttons, accessibility element
  types, and geometry contracts remain intact.

Do not replace the graph with a generic streak grid. That would remove month labels
and year-scale layout.

### 4.7 Full-screen Routine runner

Both routine entry points route to the same `fullScreenCover`.

The runner is split into focused presentation components:

- `RoutineRunnerProgressHeader`;
- `RoutineStepCard`;
- `RoutineTimerProgress`;
- `RoutineResponseMenu`.

Lifecycle rules:

- interactive dismissal is disabled;
- End is present in running, paused, and interrupted states;
- abandonment uses a confirmation dialog and the canonical stop mutation;
- Continue/Resume is primary;
- Pause and Skip remain secondary;
- the current step uses a restrained card-swap spring;
- Reduce Motion uses crossfade-only transitions;
- type uses semantic design tokens;
- state restoration comes from the persisted `activeRoutineRun`.

The runner must never infer abandonment from presentation dismissal.

### 4.8 Inbox triage and daypart effects

`LifeBoardTriageSettle` was added to the existing Metal source. Its Swift wrapper is
bounded to approximately 480 ms and returns the plane to a static state.

Direction contract:

- skip/left triggers the reverse warm streak only after skip persistence succeeds;
- review/right triggers the forward streak as the review transition commits.

`daypartBloom` mounts at the root atmosphere boundary. It triggers only when the
semantic daypart changes, not on every body update or clock tick.

Both effects:

- mount behind readable content;
- do not change layout;
- do not block interaction;
- are never required to understand state;
- fall back to a short token-based tint crossfade under Reduce Motion, Reduce
  Transparency, Low Power Mode, Catalyst, shader unavailability, or failed warm-up.

---

## 5. Stable automation and accessibility identifiers

Identifiers are public test contracts. Prefer feature-qualified semantic names over
labels, localized copy, or element position.

### Global and Home

| Identifier | Meaning |
|---|---|
| `LifeBoardCompactChrome` | Shared compact composer/dock chrome |
| `lifeThread.composer.toolsToggle` | Opens the shared capture tools |
| `lifeThread.composer.tool.<type>` | A capture tool chip |
| `foundation.more.<destination>` | Root destination in overflow |
| `home.addToHome.<destination>` | Add-to-Home destination |
| `home.customize` | Enter Home customization |
| `home.customization.cancel` | Roll back the draft transaction |
| `home.customization.done` | Commit the draft transaction |
| `home.widget.drag.<placementID>` | Placement drag handle |
| `home.widget.edit.<placementID>` | Placement context menu |

### Plan and Focus

| Identifier | Meaning |
|---|---|
| `task.editor.save` | Canonical task commit control |
| `plan.activeFocus` | Active Focus surface |
| `plan.focus.more` | Secondary Focus command menu |
| `plan.focus.commit` | Focus outcome commit |
| `plan.focus.reflection.commit` | Reflection commit |

### Track and Habit

| Identifier | Meaning |
|---|---|
| `track.lens.<lens>` | Today, Areas, or History |
| `track.habits.resilience` | Opens resilience settings |
| `track.habit.resilience.<habitID>` | A habit resilience policy |
| `track.resilience.commit` | Saves resilience policy |
| `track.hydration.target` | Opens hydration target editing |
| `track.hydration.add250` | Immediate 250 ml log |
| `track.hydration.add500` | Immediate 500 ml log |
| `habitBoard.lens.<lens>` | Habit Day, Week, or Graph selection |

Do not nest menu identifiers under a row prefix when cardinality tests query that
prefix. Existing Plan menu identifiers intentionally use `plan.taskMenu.` and
`plan.weekTaskMenu.` rather than `plan.task.menu.`.

---

## 6. Accessibility contract

The overhaul treats accessibility as layout and interaction design, not as labels
added after the fact.

### Dynamic Type

- Primary and recovery controls remain reachable through accessibility XXXL.
- Multi-column content collapses before type shrinks.
- Headers use intrinsic height.
- Metadata and decorative atmosphere yield before meaningful text.
- Bottom commit actions live in the safe area and can wrap.
- Runner typography uses semantic roles.

### VoiceOver and non-gesture access

- Directional decks expose visible buttons and named accessibility actions.
- Focus dial exposes one combined timer value.
- Routine commands are visible controls; step motion is not the only cue.
- Graphs retain textual equivalents.
- Error, progress, and retry state remain in the same mounted context.

### Motion and transparency

- Reduce Motion removes spring travel, chart sweep, dial interpolation, and shader
  distortion while keeping immediate state changes.
- Reduce Transparency replaces glass-dependent readability with opaque surfaces.
- Increased Contrast and Differentiate Without Color retain shape, text, and border
  distinctions.

### Minimum targets

All new primary, menu, drag, hydration, and navigation controls have at least a
44-point effective hit area or an equivalent accessible action.

---

## 7. Motion and shader registry

The registry contains exactly 17 names, and the test suite asserts exact set
equality against Metal `[[ stitchable ]]` declarations.

| Effect | Mounting and trigger |
|---|---|
| `daypartBloom` | Root atmosphere; semantic daypart boundary |
| `evaInkReveal` | EVA response reveal |
| `journalMediaReveal` | Journal media boundary |
| `memoryDevelopReveal` | Memory reveal |
| `fastingEmberRing` | Bounded fasting state transition |
| `healthSyncPulse` | Health sync boundary |
| `vitalOrbWarp` | Bounded vital transition |
| `clayPressBloom` | Approved control plane |
| `daypartCrossDissolve` | Daypart scene handoff |
| `completionBurst` | Confirmed completion |
| `contextLens` | Capture/EVA control/background plane; maximum 8-point offset |
| `chartRevealSweep` | First valid/materially changed chart range |
| `liquidGlassRefract` | Approved glass control transition |
| `cardMorphWarp` | Bounded card morph |
| `paperGrain` | Static paper treatment; only non-one-shot visual treatment |
| `dissolveAway` | Confirmed removal |
| `triageSettle` | Inbox under-deck plane after committed direction |

Never add a second Metal file for signature effects. `warmUp()` resolves every
function as one registry; one missing or misspelled declaration disables the whole
signature set.

---

## 8. Verification record

### Static guardrails

The following passed on the final documented source state:

```bash
./scripts/check-xcode-target-membership.sh
./scripts/token-law-guardrails.sh
./scripts/premium-ui-guardrails.sh
./scripts/phase1-foundation-guardrails.sh
./scripts/check-no-print-logs.sh
```

`git diff --check` also passed.

### Focused unit tests

Passed:

- `testFocusDialProgressUsesElapsedFractionAndClampsDomainEdges`;
- `testSignatureShaderRegistryExactlyMatchesMetalDeclarations`;
- existing `AsyncActionPhase` and directional resolver contracts compile and remain
  part of the test target.

The shader test expects:

- 17 registered Swift function names;
- 17 Metal stitchable declarations;
- exact set equality, not only matching counts.

### Targeted UI regression suite

These five journeys pass together:

- `testAdaptiveHomeCustomizationCancelAndComposerHandoff`;
- `testFoundationCompactChromeRemainsReadableAcrossScrollAndCapture`;
- `testFoundationHabitResilienceThirtyDayEditorAtLargestAccessibilitySize`;
- `testAddToHomeUsesSizePreviewAndProducesUndoReceipt`;
- `testFoundationHomeExposesCompletePhaseIIHierarchy`.

Run them serially in one `xcodebuild` invocation:

```bash
xcodebuild \
  -project LifeBoard.xcodeproj \
  -scheme LifeBoard \
  -destination 'platform=iOS Simulator,id=A2C21181-4F6B-4883-B2FF-1D1B0DB04BBF' \
  test \
  -only-testing:LifeBoardUITests/LifeBoardUITests/testAdaptiveHomeCustomizationCancelAndComposerHandoff \
  -only-testing:LifeBoardUITests/LifeBoardUITests/testFoundationCompactChromeRemainsReadableAcrossScrollAndCapture \
  -only-testing:LifeBoardUITests/LifeBoardUITests/testFoundationHabitResilienceThirtyDayEditorAtLargestAccessibilitySize \
  -only-testing:LifeBoardUITests/LifeBoardUITests/testAddToHomeUsesSizePreviewAndProducesUndoReceipt \
  -only-testing:LifeBoardUITests/LifeBoardUITests/testFoundationHomeExposesCompletePhaseIIHierarchy
```

The old failures represented:

- four stale UI/product assumptions;
- one real AX XXXL Track layout defect.

Tests now navigate by section or lens, use stable identifiers, and do not restore
obsolete controls to satisfy stale labels.

### Platform builds

Passed serially:

| Destination | Runtime | Result |
|---|---|---:|
| iPhone 17 Pro | iOS 26.5 simulator | Pass |
| iPad A16 (`LifeBoard Test iPad`) | iOS 26.5 simulator | Pass |
| My Mac | Mac Catalyst | Pass |

Final build commands:

```bash
xcodebuild -project LifeBoard.xcodeproj -scheme LifeBoard \
  -destination 'platform=iOS Simulator,id=A3ABF0F1-98A9-4D82-A075-9F9C560D66D3' \
  build -quiet

xcodebuild -project LifeBoard.xcodeproj -scheme LifeBoard \
  -destination 'platform=iOS Simulator,id=DB626ACE-A9C1-4163-98E2-A4EF68C869F1' \
  build -quiet

xcodebuild -project LifeBoard.xcodeproj -scheme LifeBoard \
  -destination 'platform=macOS,variant=Mac Catalyst,name=My Mac' \
  build -quiet
```

The existing iPad A16 on iOS 18.6 was not a valid destination because the app’s
deployment target is iOS 26. A dedicated iOS 26.5 simulator was created with UDID
`DB626ACE-A9C1-4163-98E2-A4EF68C869F1`.

### Visual evidence

The targeted UI journeys refreshed:

- `docs/evidence/lifeboard-5/root-state-fixtures/iphone/home-compact-chrome-capture.png`.

During implementation, simulator recordings/screenshots were also inspected for:

- focused Home customization;
- compact Home composer/chrome;
- AX XXXL Track resilience editing.

### Manual/device verification still recommended

The implementation and automated acceptance gates are complete. Before production
promotion, run the broader release-quality matrix that requires sustained visual or
device judgment:

- VoiceOver rotor/order and custom actions on every gesture surface;
- right-to-left layout;
- dark appearance across all revised roots;
- Increase Contrast, grayscale, Reduce Transparency, and Reduce Motion;
- iPad sidebar/window resizing and keyboard traversal;
- device haptics and Low Power Mode;
- Instruments animation-hitch, SwiftUI update, offscreen-rendering, and Metal-cost
  profiling;
- lifecycle restoration after real background termination during Focus and Routine.

These are release QA gates, not claims of already captured automated evidence.

---

## 9. Known warnings and non-blocking environment issues

The final builds emit only established warnings:

- `HKWorkoutActivityType.dance` is deprecated; migrate to social/cardio dance in a
  separate HealthKit cleanup.
- Catalyst linker search paths may reference a missing optional Metal toolchain
  cryptex path. The target still links successfully.
- The test target emits existing Swift concurrency warnings around Core Data
  non-Sendable types.
- Xcode may log `DebuggerLLDB.DebuggerVersionStore.StoreError` during UI test
  launches. The tests continue and pass.

Do not add these to a failure baseline. Investigate any new compiler, linker, test,
or shader warm-up warning introduced by touched code.

---

## 10. Maintenance rules

### Async state

- Never set `.success` before the canonical mutation returns.
- Never dismiss a composer before success.
- Never complete related state, such as a Focus companion, when the primary command
  failed.
- Keep retry idempotent and suppress duplicate taps while running.

### Motion

- Use `.lifeBoardMotion` in feature code.
- Keep direct-manipulation springs interruptible and velocity-aware.
- Completion may overshoot once; decorative bounce is not global.
- Do not use a shader as ambient animation.
- Do not distort text, charts, evidence, or sensitive content.

### Accessibility

- Preserve element roles and native traits when restructuring views.
- Prefer exact stable identifiers over localized labels.
- Test accessibility sizes with real scrolling.
- Do not disable UIKit animations globally in UI tests:
  `-DISABLE_ANIMATIONS` breaks `swipeUp()` behavior.

### Build hygiene

- Run `xcodebuild` serially against shared DerivedData.
- Treat `xcodebuild`, not SourceKit editor diagnostics, as ground truth.
- Keep HealthKit out of Catalyst entitlements.
- Add signature functions to the existing Metal file and registry together.
- Keep the failure baseline empty.

---

## 11. Provenance

The sample repository at
`/Users/saransh1337/Developer/Projects/SwiftUI-Animations-master` informed motion
behavior:

- circular progress timing informed the Focus dial;
- cards-swap timing informed Routine step transitions.

The implementation uses LifeBoard’s own tokens, motion policies, data contracts, and
view composition. No source was copied or substantially derived for these two
adaptations, so the existing SwiftUI-Animations attribution remains sufficient.

---

## 12. Historical corrections

Earlier versions of this handoff said the Foundation UI suite was not green and
listed five remaining failures. That was accurate during diagnosis but is no longer
the current state.

The final resolution is:

- compact Home capture drives `lifeThread.composer.toolsToggle`;
- Home hierarchy asserts the canonical default placement set;
- Add to Home uses stable destination identifiers;
- customization uses a deterministic UI-test-only user-space placement;
- Track resilience first selects `track.lens.areas`;
- AX XXXL Track uses adaptive layout and safe-area behavior;
- all five targeted tests pass together.

Earlier documentation also said the Core Data model child count “must print 22.”
Phase 2 added `TaskModelV3_BehaviorFlagship`; the correct count at that point became
23. Continue to inspect the actual project/model state rather than preserving a
historical number as a universal invariant.
