# fn-3.3 Cut over SwiftUI + chart + Liquid Glass surfaces

## Description
TBD

## Acceptance
- [ ] TBD

## Done summary
Migrated SwiftUI/chart/Liquid Glass surfaces to DesignSystem tokens.

Completed:
- Replaced `ToDoColors` usage in SwiftUI card modifiers and task card variants.
- Updated `ChartDataService` APIs to consume `TaskerColorTokens`.
- Updated `ChartCard` and `RadarChartCard` chart theming to use `TaskerThemeManager` token colors.
- Updated `LGSearchBar`, `LGTaskCard`, and `LGBaseView` to use token-based color/elevation/corner behavior.
## Evidence
- Commits:
- Tests:
- PRs: