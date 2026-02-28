# Task List Widgets Implementation TODO

Baseline: iOS 18.6 (app, widgets, and tests)

## Contract and Data
- [x] Keep gamification snapshot contracts unchanged (additive-only task-list rollout).
- [x] Expand `TaskListWidgetSnapshot` to schema v2 with backward-compatible decode defaults.
- [x] Add backup snapshot path and fallback load order: primary -> backup -> empty default.
- [x] Add task widget action command payload in App Group storage.

## Routing and Safety
- [x] Deep-link contract limited to:
  - `tasker://tasks/today`
  - `tasker://tasks/upcoming`
  - `tasker://tasks/overdue`
  - `tasker://tasks/project/{id}`
  - `tasker://task/{id}`
  - `tasker://quickadd`
- [x] Remove URL query mutation routing (`?action=`) from SceneDelegate/Home deep-link handling.
- [x] Add explicit overdue quick-view semantics for `tasker://tasks/overdue`.
- [x] Process widget mutation commands through coordinator-backed app runtime handlers with write-closed + idempotence guards.

## Feature Flags and Kill Switch
- [x] Add task-list widget flags in `V2FeatureFlags`:
  - `taskListWidgetsEnabled`
  - `interactiveTaskWidgetsEnabled`
- [x] Wire remote config keys:
  - `feature_task_list_widgets_enabled`
  - `feature_task_list_widgets_interactive_enabled`
- [x] Mirror task widget flags into App Group defaults for widget-extension gate parity.

## Widget Catalog Coverage
- [x] Home small catalog implemented (12/12).
- [x] Home medium catalog implemented (12/12).
- [x] Home large catalog implemented (10/10).
- [x] Lock/accessory catalog implemented (8/8).
- [x] StandBy catalog implemented (6/6).
- [x] Register all catalog kinds in widget bundle entrypoint with non-empty display metadata.
- [x] Add deterministic accessory tap targets via `.widgetURL`/`Link`.

## Verification
- [x] Add source-contract tests for catalog coverage and routing/mutation constraints.
- [x] Add snapshot schema compatibility tests (v1 decode defaults + v2 round-trip).
- [x] Add overdue quick-view filtering test.
- [ ] Run full test and build matrix (app + widgets + tests).
