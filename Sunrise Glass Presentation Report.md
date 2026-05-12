---
title: "Sunrise Glass Presentation Layer Report"
subtitle: "LifeBoard UI Migration Status and Next Steps"
date: "May 2026"
author: "LifeBoard"
toc: true
toc-depth: 2
geometry: margin=0.75in
fontsize: 10.5pt
mainfont: DejaVu Sans
monofont: DejaVu Sans Mono
colorlinks: true
linkcolor: blue
urlcolor: blue
---

# Executive Summary

The Sunrise Glass redesign has begun with **Home** as the reference implementation for the new LifeBoard presentation layer. The new work lives under `LifeBoard/LifeBoardDesign/` and keeps existing product logic intact while replacing visible UI surfaces with SwiftUI-based Sunrise Glass components.

The current implementation establishes the foundation for the new system: tokens, scenic time-of-day headers, timeline cards, timeline rail, habit preview, bottom dock styling, and Home state surfaces. The next major step is to migrate the remaining primary tabs, creation flows, and supporting screens using the same component language.

## Current Status At A Glance

| Area | Status |
|---|---|
| Home presentation | Rebuilt as the Sunrise Glass reference surface |
| Design tokens | Implemented for color, typography, spacing, radius, shadow, and elevation |
| Time-of-day header system | Implemented with stable randomized image selection |
| Timeline | Rebuilt with distinct anchors, calendar items, tasks, and assistant prompts |
| Habit preview | Implemented with 7-day labels and expanded preview rows |
| Bottom dock | Restyled while preserving current information architecture |
| Build status | App build passes on iPhone 16 simulator |
| Focused tests | 15 Sunrise tests passing, 0 failures |
| Manual QA | Still needed after the latest polish pass |

# 1. Current Status

The new Sunrise Glass design system has been started under:

```text
LifeBoard/LifeBoardDesign/
```

Home is now the reference implementation for the new presentation layer. The existing domain, persistence, sync, calendar, notification, widget, assistant, and navigation logic remain intact. UIKit is still used as the host or bridge where needed, but the visible Home presentation is SwiftUI.

Verified so far:

- App build passes for `LifeBoard` on iPhone 16 simulator.
- Focused Sunrise tests pass: `15 tests, 0 failures`.
- Manual screenshot QA is still needed after the latest polish pass.

# 2. Design System Built

## 2.1 Tokens

Implemented token files:

- `LBColorTokens`
- `LBTypographyTokens`
- `LBSpacingTokens`
- `LBRadiusTokens`
- `LBShadowTokens`

These define the core Sunrise palette, glass fills, role colors, type scale, timeline spacing, dock spacing, radii, and elevation.

## 2.2 Backgrounds

Implemented background and header assets:

- `LBSunriseHeroArtwork`
- `SunriseHeaderView`
- `TimeOfDayHeaderAsset`

Current capabilities:

- Time-of-day asset buckets: morning, afternoon, evening, and night.
- Stable randomized asset selection by date and period.
- Header image does not swap while actively scrolling.
- Reduce Transparency fallback path exists.
- Header context resolves period, greeting, foreground style, and asset from one source.

## 2.3 Components

Implemented presentation components:

- `LBDateHeroHeader`
- `LBFilterChip`
- `LBTimelineItem`
- `LBTimelineSpine`
- `LBTimelineCard`
- `LBMeetingFlockCard`
- `LBCurrentTimeRail`
- `LBCurrentTimeBubble`
- `LBAssistantPromptCard`
- `LBHabitCell`
- `LBBottomDock`
- `LBFloatingAddButton`
- `LBGlassCard`
- `LBIconBadge`
- `LBSectionHeader`
- `LBPrimaryButton`
- `LBEmptyState`
- `LBLoadingSkeleton`
- `LBPermissionCard`

These are presentation-only components and use `LB*` naming so they can coexist with the old `DesignSystem` and legacy Home views during migration.

# 3. Home Screen Work Completed

## 3.1 Header

Home now uses the Sunrise Glass hero header with:

- Legacy-style month/day identity instead of `LifeBoard` branding.
- Time-aware greeting: morning, afternoon, evening, and night.
- Time-aware artwork selection.
- Anchored compact placement for the date group and navigator row.
- Reduced header height: `242pt` normal and `292pt` accessibility.
- Clear Liquid Glass on iOS 26+ for top chrome and date navigator controls, with a subtle dimming layer for scenic-media legibility.
- Light material fallback for iOS 18.6 using low-opacity backing and soft strokes.
- Shorter, subtler bottom fade so the banner no longer reads as a separate fog strip.
- Filter/content area overlaps upward into the lower hero fade.
- Menu, right-side search action, date selector, and arrows retained.

## 3.2 Filters

The filter chip row now uses Sunrise Glass chips.

Fixed behavior:

- Only one chip can appear selected at a time.
- All/Tasks no longer both render active.
- Chip row sits closer to the header and begins inside the lower hero fade transition.

Current chips:

- All
- Meetings
- Tasks
- Habits

## 3.3 Timeline

The timeline has been rebuilt into the Sunrise presentation style.

Completed behavior:

- `Now` is inserted chronologically into the timeline instead of being pinned above all rows.
- Current-time `Now` bubble is constrained to two text lines total.
- Past/current/future row state exists.
- Past rows are subdued, not hidden.
- Timeline gutter is narrower and cleaner.
- Rail opacity is reduced.
- Assistant prompt is time-aware and hides stale or too-short gaps.
- Assistant prompt sorts at `Now` when the current gap is active.

## 3.4 Timeline Item Types

The Home timeline now distinguishes four presentation types:

| Item Type | Presentation Intent |
|---|---|
| Anchors | Warm routine/day-anchor styling |
| Calendar items | Fixed, read-only calendar identity |
| Tasks | Actionable task styling with visible checkbox affordance |
| Assistant prompts | Suggestions separated from real timeline items |

Task cards now support:

- Incomplete checkbox state.
- Completed visual state.
- Reopen through the existing toggle action.

## 3.5 Habits Preview

The Home habit preview now includes:

- 7-day labels above habit cells.
- Two-line habit names.
- Fuller 7-8 row preview.
- More bottom padding so the dock does not cover the first habit row.

## 3.6 Bottom Dock

The dock still preserves the current information architecture:

- Home
- Schedule
- Eva
- Insights
- Search
- Add

Polish completed:

- Smaller floating Add button.
- Less vertical lift.
- Reduced shadow and material weight.
- Stronger selected Home state.
- Increased scroll bottom clearance.

## 3.7 Home States

Home has Sunrise-styled presentation for:

- Empty day
- Loading skeleton
- Calendar permission missing
- Calendar error/degraded state
- Habit sync warning

# 4. Remaining Screens To Redesign

Home is the only major screen currently rebuilt in Sunrise Glass. The remaining presentation layer should be migrated screen group by screen group.

## 4.1 Priority 1: Primary App Tabs

These should be redesigned next because they are part of the main navigation model.

### Schedule / Calendar

Current entry points:

- `CalendarScheduleView`
- `WeeklyCalendarStripView`
- `WeeklyViewController`

Needed Sunrise work:

- New Sunrise calendar surface.
- Day/week selector.
- Event cards.
- Calendar permission and degraded states.

### Habits

Current entry points:

- `HabitBoardScreen`
- `HabitBoardViews`
- `AddHabitForedropView`

Needed Sunrise work:

- Full Sunrise habit matrix.
- Habit detail sheet.
- Habit creation and editing.
- Streak stats and recovery rows.

### Eva / Chat

Current entry points:

- `ChatView`
- `ConversationView`
- `ChatScaffoldView`
- `ChatHostViewController`

Needed Sunrise work:

- Sunrise assistant shell.
- Message bubbles.
- Composer.
- Prompt chips.
- Task proposal cards.
- Loading and streaming states.

### Insights

Current entry points:

- `InsightsTabView`
- `InsightsTodayView`
- `InsightsWeekView`
- `InsightsSystemsView`

Needed Sunrise work:

- Sunrise analytics cards.
- Charts.
- Trend states.
- Weekly summaries.
- Empty/no-data states.

### Search

Current entry points:

- `LGSearchViewController`
- `LifeBoardSearchChrome`
- Search result views

Needed Sunrise work:

- Sunrise search screen.
- Filter chips.
- Result cards.
- Empty and recent states.

## 4.2 Priority 2: Creation And Editing Surfaces

These are high-frequency workflows and should reuse the Sunrise card, button, and input language.

### Add Task

Current entry points:

- `AddTaskForedropView`
- `AddTaskSheetView`
- `AddItemComposerView`

Needed Sunrise work:

- Sunrise creation sheet.
- Metadata rows.
- Date/time pickers.
- Priority and context controls.

### Task Detail

Current entry points:

- `TaskDetailSheetView`
- `TaskDetailView`
- `TaskScheduleEditor`

Needed Sunrise work:

- Sunrise task detail sheet.
- Completion state.
- Schedule editor.
- Recurrence and checklist UI.

### Add Habit / Habit Detail

Current entry points:

- `AddHabitForedropView`
- `HabitDetailSheetView`
- `HabitLibraryView`

Needed Sunrise work:

- Sunrise habit creation.
- Habit presets.
- Cadence editor.
- Habit history.

### Project Selection

Current entry points:

- `ProjectSelectionSheet`
- `NewProjectViewController`

Needed Sunrise work:

- Sunrise project picker.
- New project flow.
- Color and category controls.

### Filters

Current entry points:

- `HomeAdvancedFilterSheetView`
- `LifeBoardFilterComponents`

Needed Sunrise work:

- Sunrise filter sheet shared across Home, Schedule, and Search.

## 4.3 Priority 3: Planning, Reflection, Focus

These should follow once core tab navigation is stable.

### Weekly Planner

Current entry point:

- `WeeklyPlannerView`

Needed Sunrise work:

- Sunrise weekly lanes.
- Task source sheet.
- Proposal sheet.
- Outcome attachment sheet.

### Weekly Review

Current entry point:

- `WeeklyReviewView`

Needed Sunrise work:

- Sunrise review cards.
- Reflection prompts.
- Progress summaries.

### Daily Reflection

Current entry points:

- `DailyReflectionView`
- `ReflectionNoteComposerView`

Needed Sunrise work:

- Sunrise reflection flow.
- Habit mini grid.
- Note composer.

### Focus Timer

Current entry points:

- `FocusTimerView`
- `FocusSessionSummaryView`

Needed Sunrise work:

- Sunrise focus timer.
- Session summary.
- Completion/XP states.

## 4.4 Priority 4: Settings And Management

These are less urgent visually but should be migrated before shipping the full redesign.

### Settings Root

Current entry points:

- `SettingsRootView`
- `SettingsPageViewController`

Needed Sunrise work:

- Sunrise settings list.
- Profile header.
- Section cards.

### Life Management

Current entry point:

- `LifeManagementView`

Needed Sunrise work:

- Sunrise life areas/projects management.
- Detail surface.
- Composer.
- Delete and move sheets.

### LLM Settings

Current entry points:

- `LLMSettingsView`
- `ModelsSettingsView`
- `ChatsSettingsView`
- `CreditsView`

Needed Sunrise work:

- Sunrise settings cards for assistant model, memory, privacy, and credits.

### Theme Settings

Current entry point:

- `ThemeSelectionViewController`

Needed Sunrise work:

- Retire the legacy theme picker or restyle it with Sunrise tokens.

## 4.5 Priority 5: Onboarding, Launch, Error, Celebration

These should be handled after the main app surfaces so the visual language is consistent.

### App Onboarding

Current entry points:

- `AppOnboarding`
- `AppOnboardingJourneyView`

Needed Sunrise work:

- Sunrise onboarding screens.
- Permission education.
- Initial setup.

### Eva Activation

Current entry points:

- `EvaActivationRootView`
- `EvaAboutYouView`
- `EvaGoalsView`
- `EvaModelChoiceView`
- `EvaWakeEvaInstallView`

Needed Sunrise work:

- Sunrise assistant activation flow.

### Launch / Bootstrap

Current entry points:

- `LifeBoardLaunchSplashView`
- `BootstrapFailureViewController`

Needed Sunrise work:

- Sunrise launch.
- Loading state.
- Fatal error/degraded app states.

### Celebrations

Current entry points:

- `LevelUpCelebrationView`
- `MilestoneCelebrationView`
- `BadgeGalleryView`
- `BadgeDetailSheet`

Needed Sunrise work:

- Sunrise achievement language.
- Badge surfaces.
- XP celebration treatment.

# 5. Recommended Migration Strategy

## Phase A: Stabilize Home As The Reference

Before moving on, complete one visual QA pass on Home:

- Small iPhone screenshot.
- Large iPhone screenshot.
- Morning, afternoon, evening, and night headers.
- Dynamic Type.
- Reduce Transparency.
- Empty day.
- Calendar permission missing.
- Task complete/reopen.
- Habit preview near bottom dock.

## Phase B: Build Shared Sunrise Shell Components

Add reusable pieces before migrating more screens:

- `LBSunriseScreenScaffold`
- `LBSunriseNavigationBar`
- `LBSunriseSheet`
- `LBListRow`
- `LBFormField`
- `LBToggleRow`
- `LBPickerRow`
- `LBMetricCard`
- `LBChartCard`
- `LBSearchBar`
- `LBMessageBubble`
- `LBCreationSheet`
- `LBStatusBanner`

## Phase C: Migrate Main Tabs

Recommended order:

1. Habits
2. Schedule
3. Insights
4. Search
5. Eva / Chat

Reasoning:

- Habits already has a preview implementation on Home.
- Schedule shares timeline and event card language with Home.
- Insights can reuse glass cards and metric tokens.
- Search can reuse filter chips and result cards.
- Eva/Chat has the largest custom surface area and should migrate after shared components are stronger.

## Phase D: Migrate Sheets And Detail Flows

After main tabs, migrate:

1. Add Task
2. Task Detail
3. Add Habit
4. Habit Detail
5. Project Selection
6. Advanced Filters

## Phase E: Migrate Settings, Onboarding, And Edge States

Finish with settings, onboarding, launch/error, and celebration screens.

# 6. Design Rules For Developers

Use these rules for every new Sunrise screen:

- Keep existing domain, data, and navigation logic.
- Replace only presentation surfaces.
- Prefer new `LifeBoardDesign` components over old `DesignSystem` components.
- Keep UIKit controllers only as hosts or bridges where needed.
- Use SwiftUI for visible UI.
- Use pastel role colors, not heavy single-hue palettes.
- Use glass cards sparingly: cards for real items, not every section wrapper.
- Maintain clear role distinction:
  - Task = actionable/checkable.
  - Calendar = fixed/read-only.
  - Habit = streak/matrix.
  - Assistant = suggestion, not timeline truth.
  - Warning/error = calm amber/coral.
- Every screen needs loading, empty, error, and degraded states.
- Preserve accessibility identifiers used by existing tests unless intentionally replacing tests.

# 7. Testing Expectations

For each migrated screen, add or update tests for:

- View model/model adapter mapping.
- Empty/loading/error/degraded states.
- Accessibility identifiers.
- Primary action wiring.
- Role-specific card semantics.
- Dynamic Type layout safety where practical.
- Snapshot/visual checks for major screen states if the project test setup supports it.

Current Home-specific tests live in:

```text
LifeBoardTests/SunriseHeaderAssetTests.swift
```

They now cover:

- Time-of-day buckets.
- Header asset stability.
- Header context.
- Non-duplicating date navigator.
- Single selected filter chip.
- Chronological `Now` row.
- Non-today omission of `Now`.
- Past/current/future temporal state.
- Assistant gap freshness.
- Task/calendar card semantics.

# 8. Open Work / Known Gaps

- Manual screenshot validation still needs to be done after the latest Home polish.
- Other major screens still use legacy presentation.
- Some legacy Home files still exist and should remain until replacement screens are stable.
- The new design system is functional but not yet complete for forms, charts, chat, settings, and creation flows.
- Full app-wide snapshot coverage is not yet in place.

# 9. Immediate Next Actions

1. Complete Home visual QA across device sizes, time periods, Dynamic Type, and Reduce Transparency.
2. Build the shared Sunrise shell components listed in Phase B.
3. Start the next migration with the Habits screen because Home already contains a habit preview.
4. Follow with Schedule because it can reuse the Home timeline and calendar item language.
5. Add snapshot or visual checks for the most important screen states before broad rollout.
