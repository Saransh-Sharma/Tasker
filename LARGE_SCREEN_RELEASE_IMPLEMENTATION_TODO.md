# Large-Screen Release Implementation TODO

## Current Pass
- [x] Create a repo-visible execution tracker for the large-screen release work.
- [x] Wire active-path settings/projects/models navigation so the shipped settings route matches the large-screen release contract.
- [x] Replace timing-based add-task completion handling on the active sheet and inspector paths with completion-driven state.
- [x] Centralize active iPad shell commands and add a first-class Models destination instead of routing through chat.
- [x] Replace active chat/settings idiom-based presentation decisions with layout-class-driven behavior.
- [x] Add debug-visible iPad primary-surface host remount logging for the Tasks/Search/Analytics host.
- [x] Replace remaining large-screen `NavigationView` surfaces on active flows with `NavigationStack`.
- [x] Add a shared readable-width layout primitive and adopt it in key large-screen SwiftUI surfaces.
- [x] Improve iPad/Mac quick-filter, date-picker, add-task, and task-detail presentation behavior.
- [x] Move reachable project creation away from the legacy fixed-bounds UIKit flow.
- [x] Remove or quarantine the most problematic fixed-screen onboarding and legacy settings/project surfaces.
- [ ] Run targeted build/test validation for the active iPhone, iPad, and `Designed for iPad` on Mac paths after the second active-path remediation pass.

## This Pass Scope
- [x] Home shell and keyboard command polish
- [x] Home quick-filter adaptive overlay
- [x] Insights adaptive tab/header/content width
- [x] Add item and task detail readable-width treatment
- [x] Settings, life management, and project management large-screen polish
- [x] Chat list title/large-screen cleanup
- [x] Onboarding prompt-sheet width fix
- [x] Legacy navigation cleanup on active sheets

## Remaining Follow-Up
- [ ] Finish true persistent iPad primary-surface hosting across every home destination without remount-sensitive setup.
- [ ] Remove the remaining time-based routing in `HomeViewController` widget/deep-link recovery and any lingering animation replay paths outside the active surfaces touched here.
- [ ] Add a formal multi-destination test plan and broader UI automation coverage for shell remount, command shortcuts, and large-screen regression gates.
- [ ] Run live Instruments traces and wider UI regression coverage for p90 release budgets and layout assertions.
