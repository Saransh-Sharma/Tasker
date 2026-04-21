# Habits iOS UX Audit (Core Surfaces)
Date: 2026-04-17
Scope: Home Habits surfaces, Habit Board, Habit Library, Habit Detail, Life Management habit flows
Lenses: `audit` + `axiom-ux-flow-audit` (primary), `axiom-hig`, `axiom-ios-ui`, `axiom-ios-accessibility`

## Anti-Patterns Verdict
Verdict: **Pass with UX reliability defects**.

This does **not** read as generic AI-generated iOS UI. The Habits module uses domain-specific interaction modeling (last-cell cycle semantics), semantic theming tokens, and non-trivial state mapping. The primary quality risks are not visual sameness; they are **state feedback gaps** (loading/error visibility) and **forward-path gaps** on empty states.

## Executive Summary
- Total findings: **10**
- Severity split: **0 Critical / 5 High / 4 Medium / 1 Low**
- Most critical risks:
  1. Habit Board backend/load failures are masked as "No habits yet" (misleading state).
  2. Home habit mutation failures are written to `errorMessage` but not surfaced in Habits UI feedback path.
  3. Manage Habits and Habit Board empty states have no direct "create habit" forward action.
  4. Habit Board has partial Dynamic Type readiness (layout adjusts, typography stays fixed-size).
- Overall quality score: **7.4/10** (strong interaction architecture, weak state-feedback resilience)

## Detailed Findings by Severity

### Critical Issues
None found in scoped core surfaces.

### High-Severity Issues

#### H1. Habit Board failure path is masked as empty state
- Location: `To Do List/View/HabitBoardViews.swift:413`, `To Do List/Presentation/ViewModels/HabitBoardViewModel.swift:52`, `To Do List/Presentation/ViewModels/HabitBoardViewModel.swift:106`
- Severity: High
- Category: UX Flow / Missing Error State
- Description: Board UI renders `ContentUnavailableView("No habits yet")` when rows are empty and loading is false, but does not branch on `viewModel.errorMessage`. VM failure states set `errorMessage`, yet users see an inaccurate empty-state message.
- Impact: Users cannot distinguish "no data" from "data failed to load," causing wrong mental model and poor recovery behavior.
- WCAG/Standard: HIG Feedback; Axiom UX principle #6 (Feedback Loop)
- Recommendation: Add explicit error-state rendering with retry action in Habit Board root surface.
- Suggested command: `/harden`

#### H2. Habit Board lacks explicit loading feedback for initial load
- Location: `To Do List/View/HabitBoardViews.swift:413-421`, `To Do List/Presentation/ViewModels/HabitBoardViewModel.swift:44`
- Severity: High
- Category: UX Flow / Missing Loading State
- Description: Initial loading sets `isLoading = true`, but board root has no dedicated loading UI for empty board case. The `boardMatrix` path can render with no rows and no progress indicator.
- Impact: Perceived jank/blank-state risk on slow I/O; users can misinterpret loading as broken/empty state.
- WCAG/Standard: HIG Feedback; Axiom UX principle #6 (Feedback Loop)
- Recommendation: Add loading placeholder/progress state before first successful board hydration.
- Suggested command: `/harden`

#### H3. Home habit mutation failures are not surfaced via Habits snapshot/UI channel
- Location: `To Do List/Presentation/ViewModels/HomeViewModel.swift:4002-4024`, `To Do List/ViewControllers/HomeViewController.swift:264-271`, `To Do List/View/HomeForedropView.swift:2035`, `To Do List/View/HomeForedropView.swift:2225`
- Severity: High
- Category: UX Flow / Missing Error State
- Description: Habit mutation failures set `HomeViewModel.errorMessage`, but `HomeHabitsSnapshot` carries only habit section data (no error), and the SwiftUI Habits surface snackbar is local-state driven, not bound to `viewModel.errorMessage`.
- Impact: Failed complete/skip/lapse actions can become silent from user perspective, reducing trust in habit state consistency.
- WCAG/Standard: HIG Feedback; Axiom UX principle #6 (Feedback Loop)
- Recommendation: Wire habit mutation failures into surfaced, user-visible feedback (snackbar/banner/alert) on Home Habits surface.
- Suggested command: `/harden`

#### H4. Manage Habits empty state has no forward CTA to create a habit
- Location: `To Do List/View/AddHabitForedropView.swift:833-839`, `To Do List/View/AddHabitForedropView.swift:2416-2441`
- Severity: High
- Category: UX Flow / Dead-End View
- Description: In `HabitLibraryView`, empty states are informative only; `HabitEmptyStateCard` has no action slot, and the toolbar has refresh-only control.
- Impact: Users entering from "Manage Habits" can hit a dead end with no immediate path to create their first habit.
- WCAG/Standard: Axiom UX principle #4 (Dead End Prevention), #3 (Primary Action Visibility)
- Recommendation: Add primary "Add Habit" CTA in empty states and/or toolbar.
- Suggested command: `/onboard`

#### H5. Habit Board empty state has no primary forward action
- Location: `To Do List/View/HabitBoardViews.swift:413-418`
- Severity: High
- Category: UX Flow / Dead-End View
- Description: "No habits yet" state in Habit Board provides description only; no create/navigate action.
- Impact: Habit Board entry can become informational dead end, requiring users to infer where creation lives.
- WCAG/Standard: Axiom UX principle #4 (Dead End Prevention), #3 (Primary Action Visibility)
- Recommendation: Add "Create Habit"/"Open Life Management" action in board empty state.
- Suggested command: `/onboard`

### Medium-Severity Issues

#### M1. Habit Board typography remains fixed-size despite accessibility layout branching
- Location: `To Do List/View/HabitBoardViews.swift:48-50`, `To Do List/View/HabitBoardViews.swift:88-90`, `To Do List/View/HabitBoardViews.swift:446`, `To Do List/View/HabitBoardViews.swift:494`, `To Do List/View/HabitBoardViews.swift:760`, `To Do List/View/HabitBoardViews.swift:767`
- Severity: Medium
- Category: Accessibility / Dynamic Type
- Description: Board adjusts dimensions for accessibility sizes, but many text styles use fixed `.font(.system(size: ...))` values.
- Impact: At larger text settings, readability/hierarchy can degrade and may not meet user text-size expectations.
- WCAG/Standard: iOS Dynamic Type guidance; Apple accessibility/HIG typography guidance
- Recommendation: Shift board labels/headers toward scalable text styles or tokenized dynamic typography.
- Suggested command: `/normalize`

#### M2. Habit Library modal lacks explicit close affordance
- Location: `To Do List/View/AddHabitForedropView.swift:790-797`
- Severity: Medium
- Category: UX Flow / Escape Hatch Discoverability
- Description: Habit Library toolbar exposes refresh only; there is no explicit Close/Done control in its own chrome.
- Impact: Dismiss relies on system gesture behavior, reducing discoverability for some users/contexts.
- WCAG/Standard: Axiom UX principle #2 (Escape Hatch)
- Recommendation: Add explicit Close button in Habit Library navigation bar.
- Suggested command: `/adapt`

#### M3. Add Habit composer has no explicit dependency-loading state
- Location: `To Do List/View/AddHabitForedropView.swift:228-229`, `To Do List/Presentation/ViewModels/AddHabitViewModel.swift:214-253`
- Severity: Medium
- Category: UX Flow / Loading State
- Description: Composer triggers `loadIfNeeded()` and blocks submission while loading, but form presents without clear loading explanation for life areas/projects.
- Impact: Users can encounter temporarily blank pickers and disabled progression without context.
- WCAG/Standard: HIG Feedback; Axiom UX principle #6 (Feedback Loop)
- Recommendation: Show inline dependency loading indicator/skeleton where area/project selectors appear.
- Suggested command: `/harden`

#### M4. External reachability for Habits-specific destinations is limited
- Location: `To Do List/SceneDelegate.swift:241-301`
- Severity: Medium
- Category: UX Flow / Deep Link Reachability
- Description: Deep-link host handling includes `chat`, `focus`, `home`, `insights`, `quickadd`, `tasks`, `task`; no Habits-specific routes.
- Impact: Lower re-entry/discoverability for Habit Board, Habit Library, and Habit Detail from external surfaces.
- WCAG/Standard: Axiom UX principle #4 and #5 (flow continuity/disclosure)
- Recommendation: Add guarded, validatable Habits deep-link routes (board/detail/library) with fallback behavior.
- Suggested command: `/adapt`

### Low-Severity Issues

#### L1. Loading card uses static symbol rather than active progress component
- Location: `To Do List/View/AddHabitForedropView.swift:827-831`
- Severity: Low
- Category: UX Polish / Loading Semantics
- Description: Initial library loading card uses `systemImage: "progress.indicator"` instead of animated `ProgressView`.
- Impact: Minor mismatch between message and motion affordance; can read as decorative icon instead of active operation.
- WCAG/Standard: HIG clarity/feedback guidance
- Recommendation: Replace symbol with `ProgressView` or animated activity affordance.
- Suggested command: `/polish`

## Enhanced Rating Table (High Findings)

| Finding | Urgency | Blast Radius | Fix Effort | ROI |
|---|---|---|---|---|
| H1 Board errors masked as empty | Ship-blocker | Users opening Habit Board during transient/store failures | 20-40 min | Critical |
| H2 Board missing loading state | Next release | Habit Board users on slow loads | 20-30 min | High |
| H3 Home habit mutation failures not surfaced | Ship-blocker | All Home habit quick-action users | 30-60 min | Critical |
| H4 Manage Habits empty dead-end | Next release | New/returning users entering Manage Habits empty | 15-30 min | High |
| H5 Habit Board empty dead-end | Next release | Users opening board with zero habits | 15-30 min | High |

## Patterns & Systemic Issues
- **State-feedback asymmetry**: ViewModels set error/loading state, but view routing inconsistently exposes it (especially in Home Habits and Board root).
- **Empty-state informational bias**: Empty states describe status but often omit immediate forward action.
- **Accessibility split implementation**: Touch targets and labels are strong, but large-text typography scaling is inconsistent in board-heavy surfaces.

## Positive Findings
- Home Habit rows provide multiple action paths (`swipeActions`, `contextMenu`, dedicated last-cell interaction), reducing gesture-only risk. (`To Do List/View/HomeHabitRowView.swift:174-196`)
- Strong accessibility labeling/hints for row-level and cell-level interactions in Home, Board, and Detail. (`To Do List/View/HomeHabitRowView.swift:67-95`, `To Do List/View/HabitBoardViews.swift:612-634`, `To Do List/View/AddHabitForedropView.swift:1972-1974`)
- Explicit minimum day-cell touch target of 44 in Habit Detail calendar layout metrics. (`To Do List/View/AddHabitForedropView.swift:1673`)
- Habit Board has explicit close escape hatch in toolbar. (`To Do List/View/HabitBoardViews.swift:389`)
- Life Management consistently exposes Add Habit paths in top-level and empty-state contexts. (`To Do List/Views/Settings/LifeManagementView.swift:143-144`, `To Do List/Views/Settings/LifeManagementView.swift:631-633`)

## Recommendations by Priority
1. Immediate
- Surface Habit Board error state with retry.
- Surface Home habit mutation errors in visible feedback channel.

2. Short-term
- Add forward CTAs in Habit Board and Habit Library empty states.
- Add Habit Board initial loading placeholder.

3. Medium-term
- Bring Habit Board typography onto scalable Dynamic Type-aware styles.
- Add explicit close action to Habit Library modal chrome.
- Add inline dependency loading feedback in Add Habit composer selectors.

4. Long-term
- Add Habits-specific deep-link routes with validation/fallback.
- Expand UI test reliability for seeded Home habit visibility on launch.

## Suggested Commands for Fixes
- Use `/harden` to implement missing error/loading UX feedback (H1, H2, H3, M3).
- Use `/onboard` to add forward-path CTAs in empty states (H4, H5).
- Use `/normalize` to standardize scalable typography/tokens (M1).
- Use `/adapt` for modal escape affordances and deep-link entry parity (M2, M4).
- Use `/polish` for low-severity loading affordance refinement (L1).

## Navigation Reachability

- Total screens found: **8** (core Habits surfaces and habit-centric management/detail entry screens)
- Deep-linkable screens: **1** (`tasker://home` reaches Home surface that contains Habits entry)
- Widget-reachable screens: **1** (`tasker://home` widget URL route in TodayXPWidget)
- Notification-reachable screens: **1** (`home_today` notification route fallback)
- Coverage: **12.5%** of scoped screens are externally reachable

## Test Evidence (Sanity Pass)
- Unit sanity pass executed successfully:
  - `HabitBoardViewModelTests` (8 tests passed)
  - `HomeHabitLastCellInteractionTests` (6 tests passed)
- Targeted UI sanity pass status:
  - `HabitBoardUITests/testHomeHabitLastCellCyclesThroughThreeStates` **failed** at `To Do ListUITests/Tests/Secondary/HabitBoardUITests.swift:193` (could not find home habit row after scrolling in this simulator run).
- Interpretation: core interaction logic is stable at unit level; UI flow test reliability/data-seeding assumptions need follow-up.
