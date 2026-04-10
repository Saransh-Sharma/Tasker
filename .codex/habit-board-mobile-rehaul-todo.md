# Habit Board Matrix Rebuild

- [x] Audit current board implementation against target matrix layout
- [x] Replace strip-and-summary architecture with pinned rail plus synchronized day grid
- [x] Decouple viewport column count from fetched history span in `HabitBoardViewModel`
- [x] Retune board visuals to flat matrix cells with cooler neutral states
- [x] Add stable accessibility identifiers for day headers, rows, and cells
- [x] Rewrite unit coverage for layout-driven viewport sizing and paging
- [x] Rewrite UI coverage for 7-column compact matrix behavior
- [ ] Run focused build verification
- [ ] Run Habit Board unit verification
- [ ] Run Habit Board UI verification on simulator
- [ ] Fix any remaining simulator-only UI test issues

## Target-ramp alignment follow-up

- [x] Move pinned habit labels back under the `HABITS` header rail
- [x] Add board-only visible-run depth remapping for the Everyday-style streak ramp
- [x] Remove noisy board cell strokes and keep bridge tint tied to adjacent visible depth
- [x] Add pinned-rail UI test coverage

Build/test blocker:
- `xcodebuild` currently fails before Habit Board verification because simulator builds cannot resolve existing workspace dependencies such as `FirebaseCore`, `MaterialComponents`, `ViewAnimator`, and `DGCharts`.
