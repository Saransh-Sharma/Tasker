# fn-3.2 Cut over UIKit + FluentUI screens to semantic tokens

## Description
TBD

## Acceptance
- [ ] TBD

## Done summary
Migrated core UIKit + FluentUI surfaces to semantic token usage and removed legacy theme notification wiring.

Completed:
- Replaced legacy theme access in `SceneDelegate`, `HomeViewController`, `SettingsPageViewController`, `ThemeSelectionViewController`, and `Settings/ThemeSelectionCell`.
- Replaced `NotificationCenter` `.themeChanged` observers in Home/Settings/theme picker cell with `TaskerThemeManager.publisher` Combine subscriptions.
- Updated Add Task and FluentUI table components to use token colors.
- Updated project/new project UIKit controllers to remove legacy ToDoColors/ToDoFont dependencies and Helvetica font usage.
## Evidence
- Commits:
- Tests:
- PRs: