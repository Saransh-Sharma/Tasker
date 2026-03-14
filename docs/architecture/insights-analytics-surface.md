# Insights Analytics Surface

**Last validated against code on 2026-03-11**

This document is the canonical implementation reference for the Insights analytics screen.
It describes the screen contract, tab intent split, widget inventory, projection inputs, and refresh behavior for the current Today / Week / Systems surface.

## Purpose and Boundaries

Insights owns:
- A three-tab analytics surface for action, reflection, and long-term system health.
- Projection of task, XP, focus, reminder, and achievement data into widget-ready state.
- Empty states, motion behavior, and accessibility contracts for Insights content.

Insights does not own:
- Core task truth or scheduling rules.
- XP ledger write semantics.
- Reminder scheduling policy or notification copy/catalog.
- DGCharts-based legacy surfaces outside Insights.

## Tab Intent Split

| Tab | Primary intent | User outcome |
| --- | --- | --- |
| `Today` | Operational momentum | Decide what matters now without shame or guesswork |
| `Week` | Reflective pattern analysis | See consistency, drag, and what kinds of work actually landed |
| `Systems` | Long-term system health | Understand whether progression, reminders, focus, and recovery loops are supporting follow-through |

## Primary Source Anchors

- `To Do List/Presentation/ViewModels/InsightsViewModel.swift`
- `To Do List/View/Insights/InsightsTabView.swift`
- `To Do List/View/Insights/InsightsTodayView.swift`
- `To Do List/View/Insights/InsightsWeekView.swift`
- `To Do List/View/Insights/InsightsSystemsView.swift`
- `To Do List/Presentation/ViewModels/HomeViewModel.swift`
- `To Do List/UseCases/Coordinator/UseCaseCoordinator.swift`

## Widget Inventory

### Today

- Hero card with title, summary, coaching prompt, and daily XP gauge.
- Momentum board:
  - completed vs scheduled
  - daily XP
  - streak-safe state
  - top XP source
- Goal + pace:
  - progress to daily cap
  - morning vs evening clears
  - high-priority clears
- Due pressure:
  - due today open
  - overdue open
  - stale overdue
  - blocked tasks
  - long tasks
- Focus pulse:
  - total focus minutes
  - average session length
  - target-hit rate
- Completion mix:
  - priority distribution
  - task-type distribution
  - energy distribution
  - context distribution
- Recovery loop:
  - recover/reschedule signal
  - decomposition signal
  - reflection signal

### Week

- Hero summary with weekly title, summary, and summary metrics.
- Weekly momentum bars:
  - XP bars by weekday
  - completion counts by weekday
  - scale mode (`goal` vs `personalMax`)
- Weekday pattern strip:
  - normalized intensity by day
  - delta summary versus previous week
- Project leaderboard:
  - weekly completion score totals
  - completion count subtitle
- Work mix:
  - priority mix
  - task-type mix
- Summary metrics:
  - goal-hit days
  - average XP per elapsed day
  - best day
  - carry-over pressure

### Systems

- Progression card:
  - level
  - total XP
  - next milestone
  - level progress ring and bar
- Streak resilience metrics:
  - current streak
  - best streak
  - return streak
  - reminder support rate
- Achievement velocity metrics:
  - total unlocked
  - last 7 days
  - last 30 days
- Reminder response:
  - acknowledged deliveries
  - snoozed deliveries
  - pending deliveries
  - response-rate framing
- Focus ritual health:
  - session count
  - completion rate
  - total minutes
  - average length
- Recovery loop health:
  - recovery count
  - decomposition count
  - reflection count
  - support-actions-to-completions ratio
- Achievement board:
  - category filter chips
  - badge gallery
  - badge detail sheet

## Projection Inputs By Tab

Insights uses the existing data model only. It does not require schema changes.

| Tab | Inputs |
| --- | --- |
| `Today` | `GamificationEngine.fetchTodayXP`, `fetchCurrentProfile`, `GamificationRepositoryProtocol.fetchXPEvents(from:to:)`, `fetchFocusSessions(from:to:)`, `TaskReadModelRepositoryProtocol.fetchTasks`, optional `CalculateAnalyticsUseCase.calculateDailyAnalytics(for:)` |
| `Week` | `GamificationRepositoryProtocol.fetchDailyAggregates(from:to:)`, `fetchXPEvents(from:to:)` for current and previous week windows, `TaskReadModelRepositoryProtocol.fetchTasks`, `fetchProjectCompletionScoreTotals(from:to:)` |
| `Systems` | `GamificationEngine.fetchCurrentProfile`, `GamificationRepositoryProtocol.fetchAchievementUnlocks`, `fetchXPEvents()`, `fetchFocusSessions(from:to:)`, `ReminderRepositoryProtocol.fetchReminders`, `fetchDeliveries(reminderID:)` |

## State Model Contract

`InsightsViewModel.init(...)` now accepts:
- `engine`
- `repository`
- `taskReadModelRepository`
- `reminderRepository`
- `analyticsUseCase`

`HomeViewModel.makeInsightsViewModel()` passes those dependencies from `UseCaseCoordinator`.

Rich widget state is carried through:
- `InsightsTodayState`
- `InsightsWeekState`
- `InsightsSystemsState`

Supporting projection payloads:
- `InsightsMetricTile`
- `InsightsDistributionItem`
- `InsightsDistributionSection`
- `InsightsLeaderboardRow`
- `InsightsReminderResponseState`
- `WeeklyBarData`

These types allow the views to remain declarative and widget-oriented instead of rebuilding logic in SwiftUI.

## Refresh and Mutation Behavior

`InsightsViewModel` keeps per-tab refresh state with:
- `isLoaded`
- `inFlight`
- requested and loaded versions
- replay/dirty markers

Behavior contract:
- Selected tab loads lazily on first appearance or first selection.
- Clean tab switching does not force already-loaded tabs to refetch.
- Loaded tabs apply incremental deltas for known ledger mutations.
- Non-selected tabs are marked dirty and refreshed when visited.
- In-flight refreshes replay once when newer data arrives during the fetch.
- Day-boundary and cloud-reconciled paths trigger targeted recompute rather than whole-screen invalidation.

## UI Contract Notes

- Existing accessibility IDs remain stable:
  - `home.insights.tab.today`
  - `home.insights.tab.week`
  - `home.insights.tab.systems`
  - `home.insights.content.today`
  - `home.insights.content.week`
  - `home.insights.content.systems`
- The redesigned Insights widgets use custom SwiftUI cards and chart-like compositions.
- New Insights modules do not use DGCharts.
- Copy is action-first and shame-free.
- Empty states are explicit, not silent.
- Motion includes staged reveal and tab transitions, with strict reduced-motion fallback.

## Maintenance Notes

Update this doc when:
- tab intent changes
- widget inventory changes
- projection inputs or state payloads change
- refresh strategy changes
- accessibility identifiers for Insights change
