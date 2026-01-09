# Tasker iOS - Product Requirements Document (PRD)

**Version:** 2.0
**Last Updated:** January 10, 2026
**Platform:** iOS 16.0+
**Architecture:** Clean Architecture (60% migrated)
**Primary Language:** Swift 5+
**Status:** Production (App Store Published)

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Product Vision & Goals](#product-vision--goals)
3. [User Personas](#user-personas)
4. [Feature Specifications](#feature-specifications)
5. [Technical Architecture](#technical-architecture)
6. [Use Cases Documentation](#use-cases-documentation)
7. [Data Models & Domain Layer](#data-models--domain-layer)
8. [User Experience & Interface](#user-experience--interface)
9. [Cloud Services & Synchronization](#cloud-services--synchronization)
10. [Analytics & Gamification](#analytics--gamification)
11. [Technical Debt & Future Roadmap](#technical-debt--future-roadmap)
12. [Success Metrics](#success-metrics)

---

## Executive Summary

**Tasker** is a sophisticated iOS productivity application that transforms traditional task management into an engaging, gamified experience. By combining advanced task organization, intelligent priority management, comprehensive analytics, and motivational gamification elements, Tasker helps users build sustainable productivity habits while making task completion rewarding and fun.

### Core Value Proposition

- **Intelligent Task Management**: Smart prioritization, context-aware recommendations, and automatic scheduling
- **Gamified Productivity**: Points, levels, achievements, streaks, and challenges make completing tasks engaging
- **Deep Analytics**: Visual dashboards, productivity scoring, and trend analysis provide actionable insights
- **Seamless Sync**: UUID-based CloudKit synchronization ensures reliable cross-device data consistency
- **Clean Architecture**: Modern iOS patterns with 60% migration to Clean Architecture, enabling maintainability and testability

### Key Statistics

- **189 Swift files** organized in Clean Architecture layers
- **28 Use Cases** covering task, project, and analytics workflows
- **4 Priority Levels** with dynamic scoring (P0: 7pts, P1: 4pts, P2: 3pts, P3: 2pts)
- **50+ Levels** in gamification system with rarity-based achievements
- **UUID-Based Architecture** with fixed Inbox project (`00000000-0000-0000-0000-000000000001`)
- **CloudKit + CoreData** for reliable offline-first synchronization

---

## Product Vision & Goals

### Vision Statement

*"Empower users to achieve their goals through intelligent task management that adapts to their context, learns from their behavior, and rewards consistent productivity with engaging gamification elements."*

### Primary Goals

1. **Simplify Task Management**: Reduce cognitive load through smart defaults, context-aware suggestions, and automatic categorization
2. **Build Productive Habits**: Use gamification (streaks, levels, achievements) to encourage consistent task completion
3. **Provide Actionable Insights**: Surface productivity patterns, identify bottlenecks, and recommend optimizations
4. **Ensure Data Reliability**: Guarantee data integrity through UUID-based architecture and robust synchronization
5. **Maintain Code Quality**: Continue migration to Clean Architecture for long-term maintainability and testability

### Target Metrics

- **Daily Active Users (DAU)**: Increase by 25% YoY through gamification engagement
- **Task Completion Rate**: Maintain 70%+ average completion rate for active users
- **Streak Retention**: 40%+ of users maintain 7+ day streaks
- **Cross-Device Usage**: 60%+ of users sync across 2+ devices
- **App Store Rating**: Maintain 4.5+ star rating

---

## User Personas

### 1. The Busy Professional (Primary)

**Demographics**: 25-45 years old, knowledge worker, uses multiple devices

**Goals**:
- Manage work tasks across projects
- Balance work and personal responsibilities
- Track productivity trends
- Minimize time spent on task management itself

**Pain Points**:
- Overwhelmed by too many tasks
- Difficulty prioritizing
- Loses track of deadlines
- Needs cross-device sync

**Tasker Solutions**:
- Smart priority optimization
- Project-based organization with analytics
- Overdue task detection and bulk rescheduling
- CloudKit synchronization across iPhone, iPad, Mac

### 2. The Goal-Oriented Student (Secondary)

**Demographics**: 18-25 years old, high school/college student

**Goals**:
- Track assignments and deadlines
- Build study habits
- Stay motivated through gamification
- See progress visually

**Pain Points**:
- Procrastination
- Lack of motivation
- Forgets tasks
- Needs visual feedback

**Tasker Solutions**:
- Habit builder with streak tracking
- Gamification (points, levels, achievements)
- Visual analytics and charts
- Reminder system with notifications

### 3. The Habit Builder (Tertiary)

**Demographics**: 20-50 years old, focused on self-improvement

**Goals**:
- Build sustainable habits
- Track consistency
- Get personalized recommendations
- See long-term progress

**Pain Points**:
- Difficulty maintaining habits
- No tracking system
- Lacks accountability
- Needs encouragement

**Tasker Solutions**:
- Habit builder use case with templates
- Streak tracking with milestones
- Habit suggestions based on patterns
- Momentum indicators and completion rates

---

## Feature Specifications

### 1. Core Task Management

#### 1.1 Task Creation & Editing

**Description**: Create and edit tasks with rich metadata including title, description, priority, due date, project assignment, and advanced properties.

**User Stories**:
- As a user, I want to quickly create tasks with minimal input, so I can capture ideas without friction
- As a user, I want to assign tasks to projects, so I can organize work by category
- As a user, I want to set priorities, so I know which tasks to focus on first
- As a user, I want to add due dates, so I don't miss deadlines

**Acceptance Criteria**:
- Task name is required (1-200 characters)
- Description is optional (max 1000 characters)
- Priority levels: P0 (Highest), P1 (High), P2 (Medium), P3 (Low)
- Due date defaults to today if past date selected
- Tasks default to Inbox project if none specified
- Validation prevents empty names and excessive lengths
- Task type auto-determined based on due date/time (morning/evening/upcoming)

**Use Cases**:
- `CreateTaskUseCase` - Creates task with validation and business rules
- `UpdateTaskUseCase` - Updates task properties with validation

**Domain Models**:
- `Task` (Domain/Models/Task.swift:12)
- `CreateTaskRequest` (Domain/Models/CreateTaskRequest.swift)
- `TaskPriority`, `TaskType`, `TaskCategory`, `TaskEnergy`, `TaskContext`

**Technical Details**:
- UUID generated for new tasks
- Project validation ensures valid project exists
- Notifications scheduled if reminder set
- Domain events published (`TaskCreated`, `TaskUpdated`)

---

#### 1.2 Task Completion & Scoring

**Description**: Mark tasks complete/incomplete with automatic score calculation, streak tracking, and gamification rewards.

**User Stories**:
- As a user, I want to mark tasks complete with a single tap, so I can quickly update my progress
- As a user, I want to see my earned points immediately, so I feel rewarded for completing tasks
- As a user, I want to track completion streaks, so I stay motivated to be consistent

**Acceptance Criteria**:
- Completed tasks earn points based on priority:
  - P0 (Max): 7 points
  - P1 (High): 4 points
  - P2 (Medium): 3 points
  - P3 (Low): 2 points
- Completion time tracked (`dateCompleted`)
- Streaks calculated based on consecutive days with completions
- Uncompleting a task deducts the earned points
- Visual strike-through applied to completed tasks (BEMCheckBox integration)

**Use Cases**:
- `CompleteTaskUseCase` - Toggles completion status and calculates scores
- `CalculateAnalyticsUseCase` - Computes streaks and daily scores

**Technical Details**:
- Score computed via `task.score` property (priority-based)
- Streak logic: consecutive days with at least 1 completion (up to 30-day history)
- Domain events: `TaskCompleted`, `TaskUncompleted`
- Analytics cache invalidated on completion

---

#### 1.3 Task Rescheduling

**Description**: Intelligently reschedule tasks with smart date suggestions and bulk operations for overdue tasks.

**User Stories**:
- As a user, I want to easily reschedule tasks, so I can adapt to changing priorities
- As a user, I want smart date suggestions, so I don't have to manually calculate dates
- As a user, I want to bulk reschedule overdue tasks, so I can quickly get back on track

**Acceptance Criteria**:
- Prevents rescheduling completed tasks
- Smart suggestions include:
  - Tomorrow
  - Next working day (Monday if weekend)
  - Next week (same day)
  - End of week (Friday/Sunday)
  - Custom date picker
- Bulk reschedule updates all selected tasks to target date
- Reminders automatically adjusted for new due date

**Use Cases**:
- `RescheduleTaskUseCase` - Reschedules single/multiple tasks with validation
- `UseCaseCoordinator.rescheduleAllOverdueTasks` - Bulk reschedule workflow

**Technical Details**:
- Validation prevents past dates (auto-adjusts to today)
- Task type recalculated based on new date
- Notification rescheduling handled by `NotificationServiceProtocol`
- Cache invalidation for affected dates

---

#### 1.4 Task Deletion

**Description**: Delete tasks individually or in bulk with automatic cleanup of reminders and cache.

**User Stories**:
- As a user, I want to delete completed tasks in bulk, so I can keep my list clean
- As a user, I want to delete tasks older than a certain date, so I can archive history
- As a user, I want swipe-to-delete, so I can quickly remove individual tasks

**Acceptance Criteria**:
- Single task deletion with confirmation
- Batch deletion (max 100 tasks)
- Delete all completed tasks
- Delete tasks older than specified date
- Scheduled reminders canceled on deletion
- Domain events published for tracking

**Use Cases**:
- `DeleteTaskUseCase` - Single/batch deletion with cleanup

**Technical Details**:
- Cancels scheduled notifications via `NotificationServiceProtocol`
- Domain event: `TaskDeleted`
- Cache invalidation for affected dates/projects

---

### 2. Project Management

#### 2.1 Project Organization

**Description**: Organize tasks into projects with unique UUIDs, ensuring every task belongs to a valid project.

**User Stories**:
- As a user, I want to organize tasks by project, so I can focus on specific areas of work
- As a user, I want all tasks to have a default project (Inbox), so nothing is lost
- As a user, I want to track project-level analytics, so I can see which projects are progressing

**Acceptance Criteria**:
- Every task MUST have a project assignment
- Default project is "Inbox" with fixed UUID: `00000000-0000-0000-0000-000000000001`
- Projects have unique UUIDs for stable cross-device sync
- Project deletion requires strategy: `moveToInbox` or `deleteAllTasks`
- Inbox project cannot be deleted (system-protected)

**Use Cases**:
- `ManageProjectsUseCase` - CRUD operations for projects
- `EnsureInboxProjectUseCase` - Guarantees Inbox exists on launch
- `AssignOrphanedTasksToInboxUseCase` - Fixes tasks without valid projects

**Domain Models**:
- `Project` (Domain/Models/Project.swift)
- `ProjectConstants` (Domain/Constants/ProjectConstants.swift:12)

**Technical Details**:
- UUID-based architecture ensures stable references
- Fixed Inbox UUID never changes
- `DataMigrationService` runs on launch to ensure data integrity
- `ProjectMapper` handles Entity↔Domain conversion

---

#### 2.2 Project Filtering & Statistics

**Description**: Filter tasks by project and view project-level analytics including completion rates and task breakdowns.

**User Stories**:
- As a user, I want to view tasks for a specific project, so I can focus on that work
- As a user, I want to see project completion statistics, so I know how projects are progressing
- As a user, I want to see which projects have the most/least tasks, so I can balance my workload

**Acceptance Criteria**:
- Filter tasks by single or multiple projects
- Project statistics show:
  - Total task count
  - Completed vs incomplete tasks
  - Completion percentage
  - Total score earned
  - Priority breakdown
- "All Projects" view shows all tasks
- "Custom Projects" excludes Inbox

**Use Cases**:
- `FilterProjectsUseCase` - Filter projects by status/priority
- `GetProjectStatisticsUseCase` - Project-level analytics

**Technical Details**:
- UUID-based queries for reliable filtering
- Cache-aware statistics calculation
- Project health scoring: excellent (90%+), good (70-90%), warning (40-70%), critical (<40%)

---

### 3. Advanced Search & Filtering

#### 3.1 Task Search

**Description**: Comprehensive search across task titles, descriptions, and metadata with multiple match modes.

**User Stories**:
- As a user, I want to search tasks by keywords, so I can quickly find specific tasks
- As a user, I want to search by tags, so I can find related tasks
- As a user, I want to search by priority/category, so I can narrow down results

**Acceptance Criteria**:
- Simple search: matches task name or details (case-insensitive)
- Advanced search criteria:
  - Text (name/details)
  - Tags (any/all modes)
  - Priority (single or multiple)
  - Category, context, energy level
  - Due date range
  - Project
- Match modes: `exact`, `contains`, `startsWith`, `endsWith`
- Search suggestions based on recent searches and common patterns
- Results sorted by relevance (priority, due date, name)

**Use Cases**:
- `SearchTasksUseCase` - Simple and advanced search with suggestions

**Technical Details**:
- Cache-aware search for performance
- Search suggestions stored in `InMemoryCacheService`
- Multi-criteria combination uses AND logic
- Tag matching supports any/all modes

---

#### 3.2 Task Filtering

**Description**: Filter tasks by project, priority, category, context, energy level, tags, date ranges, and dependencies.

**User Stories**:
- As a user, I want to filter tasks by priority, so I can focus on high-priority work
- As a user, I want to filter by context (work/home/etc.), so I can see contextually relevant tasks
- As a user, I want to filter by energy level, so I can match tasks to my current state

**Acceptance Criteria**:
- Filter criteria:
  - Project (UUID-based)
  - Priority (P0/P1/P2/P3)
  - Category (work, personal, health, learning, etc.)
  - Context (work, home, anywhere, commute, etc.)
  - Energy level (low, medium, high)
  - Tags (any/all modes)
  - Date range (start/end)
  - Has estimated duration
  - Has dependencies
- Multiple filters combine with AND logic
- Filter state cached for session
- Active filters displayed in UI

**Use Cases**:
- `FilterTasksUseCase` - Multi-criteria filtering with cache

**Technical Details**:
- Cache key: `"filtered_tasks_{criteria_hash}"`
- TTL: 15 minutes
- Cache invalidated on task updates

---

#### 3.3 Task Sorting

**Description**: Sort tasks by multiple criteria with smart context-aware sorting modes.

**User Stories**:
- As a user, I want to sort by priority, so I see most important tasks first
- As a user, I want to sort by due date, so I know what's urgent
- As a user, I want context-aware sorting (morning/evening/urgent), so I get intelligent task ordering

**Acceptance Criteria**:
- Sort criteria:
  - Priority (descending by default)
  - Due date (ascending/descending)
  - Name (alphabetical)
  - Creation date
  - Completion date
  - Project name
  - Category
  - Energy level
  - Estimated duration
- Smart sorting modes:
  - Morning: incomplete morning tasks → high priority → due soon
  - Evening: incomplete evening tasks → medium/low priority → later due dates
  - Urgent: overdue → due today → high priority
  - Planning: upcoming → no due date → low priority
- Multi-level sorting: primary → secondary → tertiary criteria
- Grouping: group by project/category/priority/context/energy/due date/completion

**Use Cases**:
- `SortTasksUseCase` - Multi-criteria and context-aware sorting

**Technical Details**:
- Custom comparators for each criterion
- Group-then-sort for hierarchical views
- Cache-aware sorting (sorts cached results when possible)

---

### 4. Analytics & Reporting

#### 4.1 Daily Analytics Dashboard

**Description**: Real-time analytics dashboard showing today's tasks, score, completion rate, and streak information.

**User Stories**:
- As a user, I want to see my daily score, so I know how productive I've been today
- As a user, I want to see my completion rate, so I can track consistency
- As a user, I want to see my current streak, so I stay motivated

**Acceptance Criteria**:
- Daily dashboard shows:
  - Total tasks (morning/evening/completed/overdue/remaining)
  - Daily score (sum of completed task points)
  - Completion percentage
  - Priority breakdown (P0/P1/P2/P3 counts)
  - Task type breakdown (morning/evening/upcoming)
  - Current streak (consecutive days with completions)
  - Streak milestone progress (7/14/30/60/100/365 days)
- Real-time updates on task completion
- Visual charts (DGCharts integration)
- Cache TTL: 5 minutes

**Use Cases**:
- `CalculateAnalyticsUseCase.calculateTodayAnalytics` - Daily metrics
- `CalculateAnalyticsUseCase.calculateStreak` - Streak information
- `UseCaseCoordinator.getDailyDashboard` - Aggregated dashboard data

**Domain Models**:
- `DailyAnalytics`
- `StreakInfo`
- `ProductivityScore`

**Technical Details**:
- Dashboard aggregates: tasks, analytics, streak, productivity score
- Charts display last 7 days of data
- Streak calculation: consecutive days with ≥1 completion
- Cache key: `"daily_analytics_{date}"`

---

#### 4.2 Productivity Reports

**Description**: Generate detailed productivity reports for daily, weekly, and monthly periods with insights and recommendations.

**User Stories**:
- As a user, I want to see weekly summaries, so I can reflect on my productivity
- As a user, I want to see monthly trends, so I can identify patterns
- As a user, I want to see most/least productive days, so I can optimize my schedule

**Acceptance Criteria**:
- Daily report:
  - Task completion summary
  - Score earned
  - Priority/type breakdown
  - Overdue count
- Weekly report:
  - Daily breakdown (7 days)
  - Most/least productive day
  - Total score
  - Average completion rate
  - Weekly trends
- Monthly report:
  - Weekly breakdown (4-5 weeks)
  - Project breakdown
  - Priority distribution
  - Total completions and score
  - Month-over-month comparison
- Custom period reports (date range selection)
- Export options (PDF/CSV planned)

**Use Cases**:
- `GenerateProductivityReportUseCase` - Report generation
- `CalculateAnalyticsUseCase` - Weekly/monthly analytics

**Technical Details**:
- Reports generated on-demand (not cached)
- Historical data fetched from CoreData
- Visual charts for trend visualization
- Insights generated based on patterns

---

#### 4.3 Productivity Scoring

**Description**: Overall productivity score with level/rank based on total points, completion rate, streak, and consistency.

**User Stories**:
- As a user, I want to see my overall productivity score, so I can gauge my performance
- As a user, I want to see my rank/level, so I can compare to benchmarks
- As a user, I want insights on how to improve, so I can level up

**Acceptance Criteria**:
- Productivity score (0-100):
  - 40%: Completion rate (% of tasks completed on time)
  - 30%: Streak strength (current streak / 30-day window)
  - 20%: Task velocity (tasks/day vs. 30-day average)
  - 10%: Priority balance (mix of high/low priority completions)
- Rank tiers:
  - Beginner: 0-20
  - Apprentice: 21-40
  - Skilled: 41-60
  - Expert: 61-80
  - Master: 81-100
- Insights identify weaknesses (e.g., "Complete more high-priority tasks")
- Score history tracked over time

**Use Cases**:
- `CalculateAnalyticsUseCase.calculateProductivityScore`

**Technical Details**:
- Score computed from last 30 days of data
- Weighted formula for balanced scoring
- Cache TTL: 1 hour

---

### 5. Gamification System

#### 5.1 Points & Levels

**Description**: Earn points for completing tasks with quality multipliers, level up through 50+ levels with titles.

**User Stories**:
- As a user, I want to earn points for completing tasks, so I feel rewarded
- As a user, I want to level up, so I have a long-term progression goal
- As a user, I want quality bonuses, so I'm rewarded for excellence

**Acceptance Criteria**:
- Base points by priority:
  - P0: 7 points
  - P1: 4 points
  - P2: 3 points
  - P3: 2 points
- Quality multipliers:
  - Poor: 0.5x
  - Standard: 1.0x
  - Good: 1.2x
  - Excellent: 1.5x
- Bonus points:
  - Category bonus: Health +2, Learning +3, Work +1
  - Energy bonus: High +2, Medium +1
  - Timely completion: +20% if early, +10% if on time
  - Streak bonus: +10% per 7-day milestone
- Level progression:
  - Level formula: `level = sqrt(totalPoints / 100) + 1` (max 50)
  - Level titles: Beginner (1-5) → Apprentice (6-10) → Skilled (11-15) → Expert (16-20) → Master (21-30) → Grandmaster (31-40) → Legend (41-50) → Ultimate (50+)
- Progress bar shows % to next level

**Use Cases**:
- `TaskGameificationUseCase.processTaskCompletion` - Points calculation
- `TaskGameificationUseCase.calculateUserProgress` - Level computation

**Domain Models**:
- `UserProgress`
- `UserLevel`
- `GameificationReward`
- `MultiplierBreakdown`

**Technical Details**:
- Points stored per task completion
- Total points summed from all completed tasks
- Level progression quadratic for balance
- Domain event: `PointsEarned`

---

#### 5.2 Achievements & Badges

**Description**: Unlock achievements with rarity levels and earn badges for milestones.

**User Stories**:
- As a user, I want to unlock achievements, so I have clear goals to work toward
- As a user, I want rare achievements to feel special, so I'm proud of major accomplishments
- As a user, I want to see my achievement collection, so I can track my progress

**Acceptance Criteria**:
- Achievement rarity levels:
  - Common: Easy to unlock (e.g., "First Task Completed")
  - Uncommon: Moderate difficulty (e.g., "Week Warrior" - 7-day streak)
  - Rare: Challenging (e.g., "Month Master" - 30-day streak)
  - Epic: Very challenging (e.g., "Century Club" - 100 tasks completed)
  - Legendary: Extremely rare (e.g., "Legend" - 365-day streak)
- Achievement types:
  - Milestones: First task, 10/50/100/500 tasks completed
  - Streaks: 7/14/30/60/100/365 days
  - Categories: Complete 10/25/50 tasks in specific category
  - Speed: Complete task within 1 hour of creation
  - Perfect Day: Complete all scheduled tasks in a day
- Achievement progress tracking (% toward next unlock)
- Notification on unlock with animation

**Use Cases**:
- `TaskGameificationUseCase.getAchievementProgress` - Progress tracking
- `TaskGameificationUseCase.checkForNewAchievements` - Unlock detection

**Domain Models**:
- `Achievement`
- `AchievementProgress`
- `AchievementRarity`

**Technical Details**:
- Achievement unlock logic evaluated on task completion
- Domain event: `AchievementUnlocked`
- Achievement state persisted in CoreData
- Icons: emoji-based for simplicity

---

#### 5.3 Streaks & Challenges

**Description**: Track consecutive completion days and participate in time-limited challenges.

**User Stories**:
- As a user, I want to maintain streaks, so I stay consistent
- As a user, I want to see streak milestones, so I have mini-goals
- As a user, I want daily/weekly challenges, so I have variety

**Acceptance Criteria**:
- Streak tracking:
  - Current streak: consecutive days with ≥1 completion
  - Longest streak: all-time best
  - Streak type: day/week/month based on length
  - Next milestone: 7/14/30/60/100/365 days
  - Streak start date
- Streak bonuses:
  - 7-day: +5% points
  - 14-day: +10% points
  - 30-day: +15% points
  - 60-day: +20% points
  - 100-day: +25% points
- Challenges:
  - Daily challenges: "Complete 3 tasks today" → 15 bonus points
  - Weekly challenges: "Complete 20 tasks this week" → 100 bonus points
  - Monthly challenges: "Maintain 7-day streak" → 200 bonus points
  - Special events: Holiday-themed challenges
- Challenge progress displayed with deadline countdown

**Use Cases**:
- `TaskGameificationUseCase.calculateStreakInfo` - Streak computation
- `TaskGameificationUseCase.getActiveChallenges` - Challenge generation

**Domain Models**:
- `GameStreakInfo`
- `GameChallenge`
- `StreakType`

**Technical Details**:
- Streak calculation: sort completed tasks by date, check consecutive days
- Challenge progress tracked in real-time
- Challenges generated dynamically based on user patterns
- Domain events: `StreakMilestoneReached`, `ChallengeCompleted`

---

### 6. Habit Building

#### 6.1 Habit Creation & Templates

**Description**: Create recurring habit-based tasks with templates for common habits (exercise, reading, meditation, etc.).

**User Stories**:
- As a user, I want to create habits, so I can build sustainable routines
- As a user, I want habit templates, so I don't have to configure everything manually
- As a user, I want to customize habits, so they fit my schedule

**Acceptance Criteria**:
- Habit definition includes:
  - Title and description
  - Category (health, learning, personal, etc.)
  - Frequency: daily, weekdays, weekly, monthly, custom (X days)
  - Time of day: morning, afternoon, evening, anytime
  - Estimated duration
  - Start date and optional end date
  - Reminder settings
  - Tags
- Habit templates provided:
  - Health: Morning Walk (15 min, daily), Water Intake (8 glasses, daily)
  - Learning: Daily Reading (20 min, daily), Language Practice (30 min, weekdays)
  - Wellness: Meditation (10 min, daily), Journaling (15 min, evening)
  - Fitness: Exercise (30 min, weekdays), Stretching (10 min, daily)
- Template customization: adjust frequency, time, duration, tags
- Habit tasks auto-generated on schedule

**Use Cases**:
- `TaskHabitBuilderUseCase.createHabitTask` - Create habit
- `TaskHabitBuilderUseCase.getHabitTemplates` - Template library
- `TaskHabitBuilderUseCase.createHabitFromTemplate` - Quick habit setup

**Domain Models**:
- `HabitDefinition`
- `HabitTask`
- `HabitTemplate`
- `HabitFrequency`
- `HabitTimeOfDay`

**Technical Details**:
- Habit tasks generated automatically based on frequency
- Next occurrence calculated on completion
- Template library expandable via JSON config

---

#### 6.2 Habit Tracking & Analytics

**Description**: Track habit completion rates, streaks, momentum, and milestones with visual progress indicators.

**User Stories**:
- As a user, I want to see my habit streaks, so I know how consistent I've been
- As a user, I want to see completion rates, so I can identify struggling habits
- As a user, I want momentum indicators, so I know if I'm improving or declining

**Acceptance Criteria**:
- Habit progress includes:
  - Current streak (consecutive completions)
  - Longest streak (all-time best)
  - Total completions
  - Completion rate (% of scheduled occurrences completed)
  - Momentum: building (↗️), stable (➡️), declining (↘️), stalled (⏸️)
  - Next scheduled date
  - Milestones reached (7/14/30/60/100 day streaks, 10/25/50/100 completions)
- Momentum calculation:
  - Building: completion rate improving over last 7 days
  - Stable: consistent completion rate
  - Declining: completion rate dropping
  - Stalled: 3+ missed completions in a row
- Visual indicators: emoji-based momentum, progress bars, milestone badges
- Historical trend chart (last 30 days)

**Use Cases**:
- `TaskHabitBuilderUseCase.getHabitProgress` - Progress tracking
- `TaskHabitBuilderUseCase.completeHabitOccurrence` - Completion processing

**Domain Models**:
- `HabitProgress`
- `HabitMomentum`
- `HabitMilestone`
- `HabitCompletionResult`

**Technical Details**:
- Momentum recalculated on each completion
- Milestones stored and tracked
- Chart data aggregated from completion history

---

#### 6.3 Habit Suggestions & Optimization

**Description**: AI-driven habit suggestions based on completion patterns with recommendations for adjustments.

**User Stories**:
- As a user, I want suggestions to improve struggling habits, so I can adjust my approach
- As a user, I want to know the best time for habits, so I optimize success rates
- As a user, I want to adjust frequency if too difficult, so I don't give up

**Acceptance Criteria**:
- Suggestion types:
  - Adjust frequency: "Reduce from daily to weekdays" if completion rate <70%
  - Adjust time: "Try mornings instead of evenings" if morning habits succeed more
  - Add reminder: "Set reminder 15 min before" if frequently missed
  - Change category: Suggest better-fitting category
  - Reduce scope: "Reduce duration from 30 to 15 min" if never completed
  - Add reward: "Reward yourself after 7-day streak" for motivation
- Impact/effort scoring:
  - High impact, low effort: prioritized suggestions
  - Medium impact, low effort: secondary suggestions
  - High impact, high effort: long-term suggestions
- Suggestions generated weekly based on habit history

**Use Cases**:
- `TaskHabitBuilderUseCase.getHabitSuggestions` - Suggestion generation

**Domain Models**:
- `HabitSuggestion`
- `HabitSuggestionType`
- `SuggestionImpact`
- `SuggestionEffort`

**Technical Details**:
- ML-style pattern analysis (frequency, time, category correlations)
- Suggestion confidence scoring (0-100%)
- Suggestions refreshed on habit updates

---

### 7. Task Intelligence

#### 7.1 Task Recommendations

**Description**: Personalized task recommendations based on context, energy level, time of day, and historical patterns.

**User Stories**:
- As a user, I want task recommendations based on my current energy, so I work on appropriate tasks
- As a user, I want "next best task" suggestions, so I don't have decision fatigue
- As a user, I want similar task suggestions, so I batch related work

**Acceptance Criteria**:
- Recommendation types:
  - Context-based: recommend tasks matching current context (work/home/etc.)
  - Energy-based: recommend low-energy tasks when tired, high-energy when fresh
  - Time-based: morning/afternoon/evening task suggestions
  - Habit recommendations: recurring tasks user frequently completes
  - Similar task patterns: tasks similar to recently completed ones
  - Quick wins: low-effort, high-value tasks
  - Task breakdown: suggest splitting complex tasks into subtasks
- Recommendation scoring (0-100):
  - Context match: +30 points
  - Energy match: +25 points
  - Time match: +20 points
  - Priority: +15 points
  - Due soon: +10 points
- Confidence levels: high (80-100), medium (60-79), low (40-59)

**Use Cases**:
- `TaskRecommendationUseCase.getPersonalizedRecommendations` - Context-aware suggestions
- `TaskRecommendationUseCase.getNextBestTask` - Single best recommendation
- `TaskRecommendationUseCase.getTaskBreakdownSuggestions` - Subtask generation

**Domain Models**:
- `TaskRecommendation`
- `RecommendationType`
- `RecommendationContext`

**Technical Details**:
- Scoring algorithm weights multiple factors
- Historical patterns analyzed (completed task times, contexts, energy levels)
- Recommendations cached for 30 minutes
- Domain events tracked for learning

---

#### 7.2 Priority Optimization

**Description**: Automatically optimize task priorities based on deadlines, context, dependencies, and importance.

**User Stories**:
- As a user, I want automatic priority suggestions, so I don't have to manually adjust priorities
- As a user, I want deadlines to auto-boost priority, so urgent tasks surface
- As a user, I want to learn from my adjustments, so suggestions improve over time

**Acceptance Criteria**:
- Priority optimization factors:
  - Deadline proximity: boost priority if due within 2 days
  - Overdue: auto-upgrade to P0 (Highest)
  - Dependencies: boost priority if blocking other tasks
  - User pattern learning: learn from manual priority adjustments
  - Category importance: work tasks prioritized during work hours
  - Estimated duration: long tasks suggested earlier in day
- Priority suggestions:
  - High confidence (80%+): automatically applied (with undo)
  - Medium confidence (60-79%): suggested with explanation
  - Low confidence (40-59%): available in recommendations panel
- Bulk optimization: apply to all tasks or filtered subset
- Optimization insights: "12 tasks were auto-prioritized based on deadlines"

**Use Cases**:
- `TaskPriorityOptimizerUseCase.optimizeAllPriorities` - Batch optimization
- `TaskPriorityOptimizerUseCase.suggestPriorityAdjustment` - Single task suggestion
- `TaskPriorityOptimizerUseCase.generatePriorityInsights` - Optimization report

**Domain Models**:
- `PriorityOptimization`
- `OptimizationInsight`
- `OptimizationStrategy`

**Technical Details**:
- ML-inspired scoring (not full ML, but pattern-based)
- User adjustment tracking for learning
- Optimization run nightly via background task
- Domain event: `PriorityOptimized`

---

#### 7.3 Task Time Tracking

**Description**: Track actual vs estimated time for tasks to improve future estimates and identify efficiency patterns.

**User Stories**:
- As a user, I want to see how long tasks actually take, so I can improve my estimates
- As a user, I want efficiency metrics, so I know which task types I'm fastest at
- As a user, I want time tracking suggestions, so I can optimize my schedule

**Acceptance Criteria**:
- Time tracking:
  - Estimated duration (user-provided or suggested)
  - Actual duration (calculated from start to completion)
  - Efficiency score: estimated / actual (1.0 = perfect, >1.0 = faster than expected, <1.0 = slower)
- Time tracking modes:
  - Manual: user sets estimated duration
  - Automatic: system suggests based on similar tasks
  - Timer: active timer during task work
- Efficiency analytics:
  - Category efficiency (which categories are consistently fast/slow)
  - Time-of-day efficiency (productivity peaks/troughs)
  - Task complexity vs time correlation
- Estimate improvement suggestions: "Your reading tasks typically take 1.5x longer than estimated"

**Use Cases**:
- `TaskTimeTrackingUseCase.startTracking` - Begin tracking (planned)
- `TaskTimeTrackingUseCase.stopTracking` - End tracking and calculate actual (planned)
- `TaskTimeTrackingUseCase.getEfficiencyMetrics` - Analytics (planned)

**Domain Models**:
- `Task.estimatedDuration`, `Task.actualDuration` (already in model)
- `Task.calculateEfficiencyScore()` (already implemented)

**Technical Status**: ⚠️ **PARTIALLY IMPLEMENTED**
- Task model supports estimated/actual duration
- Efficiency calculation implemented
- Full use case and UI pending

---

### 8. Collaboration Features (Planned)

#### 8.1 Task Sharing

**Description**: Share tasks with team members or family with configurable permissions.

**User Stories**:
- As a user, I want to share tasks with others, so we can collaborate
- As a user, I want to control permissions (view/edit/full access), so I can limit changes
- As a user, I want to see who I've shared tasks with, so I can manage access

**Acceptance Criteria**:
- Share single tasks or task collections (multiple tasks)
- Permission levels:
  - View: read-only access
  - Edit: modify task properties
  - Full Access: edit, delete, reshare
- Share via:
  - Email invitation
  - User ID (within app)
  - Link (planned)
- Shared task indicators in UI
- Revoke access at any time
- Notification on task share/update

**Use Cases**:
- `TaskCollaborationUseCase.shareTask` - Share with users
- `TaskCollaborationUseCase.shareTaskCollection` - Share multiple tasks
- `TaskCollaborationUseCase.updateCollaborationPermissions` - Change access
- `TaskCollaborationUseCase.revokeTaskSharing` - Remove access

**Technical Status**: ⚠️ **NOT IMPLEMENTED (Planned)**
- Use case skeleton exists
- Repository protocols defined
- CloudKit record sharing strategy needed
- UI screens not designed

---

#### 8.2 Task Assignment & Teams

**Description**: Assign tasks to team members with deadlines and track team task completion.

**User Stories**:
- As a user, I want to assign tasks to team members, so work is distributed
- As a user, I want to see team assignments, so I know who's working on what
- As a user, I want to create team task templates, so common workflows are repeatable

**Acceptance Criteria**:
- Assign tasks to specific users with:
  - Assignee selection
  - Deadline (optional)
  - Assignment message/notes
- Team view shows:
  - All team members
  - Tasks assigned to each
  - Completion status
  - Overdue assignments
- Team task templates:
  - Predefined task lists for projects (e.g., "Product Launch Checklist")
  - Assignment rules (auto-assign based on priority, workload, skills)
- Notification on task assignment

**Use Cases**:
- `TaskCollaborationUseCase.assignTask` - Assign to user
- `TaskCollaborationUseCase.getTeamAssignments` - Team overview
- `TaskCollaborationUseCase.createTeamTaskTemplate` - Template creation

**Technical Status**: ⚠️ **NOT IMPLEMENTED (Planned)**
- Use case code exists but incomplete
- Requires user management system
- Team data model not designed

---

#### 8.3 Comments & Activity

**Description**: Add comments to shared tasks and track collaboration activity.

**User Stories**:
- As a user, I want to comment on tasks, so I can discuss details with collaborators
- As a user, I want to mention users in comments, so they're notified
- As a user, I want to see task activity history, so I know what changed

**Acceptance Criteria**:
- Comments:
  - Add, edit, delete comments
  - Mention users with @username
  - Markdown formatting support (planned)
  - Timestamp and author displayed
- Activity tracking:
  - Task viewed, edited, completed, assigned, shared
  - User who performed action
  - Timestamp
  - Change details (what changed)
- Activity feed shows recent changes
- Notifications on mentions and activity

**Use Cases**:
- `TaskCollaborationUseCase.addComment` - Post comment
- `TaskCollaborationUseCase.getComments` - Fetch comments
- `TaskCollaborationUseCase.updateComment` - Edit comment
- `TaskCollaborationUseCase.getCollaborationActivity` - Activity log

**Technical Status**: ⚠️ **NOT IMPLEMENTED (Planned)**
- Use case framework exists
- Comment data model defined
- UI not designed
- Real-time sync via TaskCollaborationSyncService (skeleton only)

---

### 9. Cloud Synchronization

#### 9.1 CloudKit Integration

**Description**: Seamless cross-device synchronization via CloudKit with UUID-based record management.

**User Stories**:
- As a user, I want my tasks synced across devices, so I can work anywhere
- As a user, I want offline support, so I can work without internet
- As a user, I want automatic sync, so I don't have to think about it

**Acceptance Criteria**:
- CloudKit record types: `Task`, `Project`
- UUID-based record IDs for stable references
- Automatic sync on:
  - App launch
  - App becomes active
  - Task/project created/updated/deleted
  - Background fetch (periodically)
- Offline-first architecture: local changes queued and synced when online
- Conflict resolution: last-write-wins with timestamp comparison
- Sync indicators in UI (syncing/synced/offline)

**Technical Implementation**:
- `OfflineFirstSyncCoordinator` (State/Sync/OfflineFirstSyncCoordinator.swift)
- CloudKit container: `iCloud.com.yourcompany.tasker`
- Public database for user data (private database for sensitive data if needed)
- Subscription-based sync for real-time updates

**Technical Details**:
- Local changes saved to CoreData immediately
- Sync queue processes changes in batches
- CloudKit subscriptions for push notifications on changes
- Background fetch for periodic sync

---

#### 9.2 Data Migration & Integrity

**Description**: Ensure data integrity through automatic migration on app launch with UUID assignment and orphan cleanup.

**User Stories**:
- As a user, I want my data to be safe during app updates, so I don't lose tasks
- As a user, I want orphaned tasks automatically fixed, so I don't have missing data
- As a user, I want seamless upgrades, so I don't have to do manual migration

**Acceptance Criteria**:
- On every app launch:
  - Ensure Inbox project exists (fixed UUID: `00000000-0000-0000-0000-000000000001`)
  - Assign UUIDs to any tasks/projects missing IDs (deterministic generation from objectID)
  - Assign orphaned tasks (no valid project) to Inbox
  - Validate data integrity (all tasks have valid projects)
- Migration logging for debugging
- Migration runs in background (non-blocking)

**Use Cases**:
- `EnsureInboxProjectUseCase` - Guarantees Inbox exists
- `AssignOrphanedTasksToInboxUseCase` - Fixes orphaned tasks

**Technical Implementation**:
- `DataMigrationService` runs on AppDelegate launch
- `InboxProjectInitializer` ensures default project
- UUID generation: `UUIDGenerator.generateUUID(from: objectID)` for backward compatibility

**Technical Details**:
- Migration uses background CoreData context
- Errors logged but don't block app launch
- Migration status stored in UserDefaults

---

### 10. User Interface & Experience

#### 10.1 FluentUI Design System

**Description**: Modern, accessible UI based on Microsoft FluentUI components with Material Design accents.

**User Stories**:
- As a user, I want a beautiful interface, so the app is pleasant to use
- As a user, I want consistent design, so interactions are predictable
- As a user, I want accessibility support, so everyone can use the app

**Acceptance Criteria**:
- FluentUI components:
  - Table cell views with priority indicators
  - Segmented controls for task type selection
  - Buttons and FABs (floating action buttons)
  - Bottom sheets for task details
  - Tab bars and navigation
- Material Design elements:
  - MDC text fields with floating labels
  - Ripple effects on buttons
  - Snackbars for feedback
- Accessibility:
  - VoiceOver support
  - Dynamic type support
  - High contrast mode support
  - Accessibility identifiers for UI testing

**Technical Dependencies**:
- `MicrosoftFluentUI` pod
- `MaterialComponents` pod
- Custom theme configuration

**Technical Details**:
- Theme colors defined in Assets.xcassets
- FluentUI tokens for spacing, typography, colors
- Accessibility identifiers: `TaskCell_{taskID}`, `AddTaskButton`, etc.

---

#### 10.2 Navigation & Flow

**Description**: Intuitive navigation with tab-based home, modal task creation, and sheet-based task details.

**User Stories**:
- As a user, I want quick access to key views, so I can navigate efficiently
- As a user, I want to create tasks from anywhere, so I can capture ideas instantly
- As a user, I want smooth transitions, so the app feels polished

**Acceptance Criteria**:
- Tab bar navigation:
  - Today (home view)
  - Projects
  - Analytics
  - Settings
- Floating action button (FAB) for quick task creation (accessible from all tabs)
- Modal presentation for:
  - Add task (full screen or sheet)
  - Edit task
  - Project management
- Sheet presentation for:
  - Task details (FluentUI bottom sheet)
  - Filters
  - Quick actions
- Navigation bar titles with context (e.g., "Today - Wednesday, Jan 10")

**Technical Implementation**:
- `UITabBarController` for main navigation
- `UINavigationController` for each tab
- Custom modal presentation with blur backdrop
- FluentUI `BottomSheetController` for task details

**Key View Controllers**:
- `HomeViewController` - Main task list
- `AddTaskViewController` - Task creation/editing
- `FluentUIToDoTableViewController` - Task detail view
- `ProjectManagementViewController` - Project CRUD
- `SettingsPageViewController` - App settings

---

#### 10.3 Visual Feedback & Animations

**Description**: Engaging animations and visual feedback for task actions using ViewAnimator and custom animations.

**User Stories**:
- As a user, I want visual feedback on actions, so I know they succeeded
- As a user, I want smooth animations, so the app feels responsive
- As a user, I want celebratory animations on achievements, so I feel rewarded

**Acceptance Criteria**:
- Task animations:
  - Fade in new tasks
  - Slide out deleted tasks
  - Strike-through animation on completion (BEMCheckBox)
  - Bounce effect on quick actions
- Achievement animations:
  - Confetti on level up (planned)
  - Badge reveal on unlock
  - Toast notification on achievement
- Loading animations:
  - Skeleton screens for data loading
  - Pull-to-refresh
  - Sync indicator
- Haptic feedback:
  - Light haptic on task completion
  - Success haptic on level up
  - Error haptic on validation failure

**Technical Dependencies**:
- `ViewAnimator` pod for list animations
- `BEMCheckBox` for checkbox animations
- `CircleMenu` for FAB menu
- Custom UIView animations

**Technical Details**:
- Animations triggered via `UIView.animate`
- ViewAnimator presets: fade, slide, zoom
- Haptics via `UINotificationFeedbackGenerator`, `UIImpactFeedbackGenerator`

---

### 11. Notifications & Reminders

#### 11.1 Local Notifications

**Description**: Schedule local notifications for task reminders with customizable lead time.

**User Stories**:
- As a user, I want reminders for tasks, so I don't forget important deadlines
- As a user, I want to customize reminder times, so they fit my schedule
- As a user, I want multiple reminders per task, so I have backup alerts

**Acceptance Criteria**:
- Notification types:
  - Task due soon (15 min, 1 hour, 1 day before)
  - Task overdue (daily reminder)
  - Morning routine (7 AM daily)
  - Evening routine (7 PM daily)
- Notification content:
  - Task name
  - Priority level
  - Due date/time
  - Quick actions: Complete, Reschedule, Snooze
- Notification settings:
  - Enable/disable notifications globally
  - Customize lead times
  - Quiet hours (no notifications during sleep)
- Badge count shows pending tasks

**Technical Implementation**:
- `NotificationServiceProtocol` interface
- `UNUserNotificationCenter` for scheduling
- Notification categories for quick actions
- Notification delegate for handling actions

**Technical Details**:
- Notifications scheduled on task creation/update
- Canceled on task deletion/completion
- Re-scheduled on reschedule

---

### 12. Settings & Preferences

#### 12.1 App Settings

**Description**: Customize app behavior, appearance, and sync preferences.

**User Stories**:
- As a user, I want to customize the app, so it fits my workflow
- As a user, I want to control sync behavior, so I manage data usage
- As a user, I want to choose themes, so the app matches my style

**Acceptance Criteria**:
- General settings:
  - Default project for new tasks
  - Default task type (morning/evening)
  - Default priority
  - Week start day (Sunday/Monday)
- Appearance:
  - Theme selection (light/dark/auto)
  - Accent color
  - Font size
- Notifications:
  - Enable/disable
  - Default reminder time
  - Quiet hours
- Sync:
  - Enable/disable CloudKit sync
  - Sync frequency (real-time, manual, hourly, daily)
  - Cellular data sync (on/off)
- Data management:
  - Export data (JSON/CSV)
  - Import data
  - Clear cache
  - Reset app (delete all data)

**Technical Implementation**:
- `SettingsPageViewController` for UI
- `UserDefaults` for preference storage
- `NotificationCenter` for settings change broadcasts

**Technical Details**:
- Settings keys: `"default_project_id"`, `"theme_preference"`, `"sync_enabled"`, etc.
- Settings migration on app update

---

---

## Technical Architecture

### Architecture Overview

Tasker follows **Clean Architecture** principles with clear separation of concerns across layers:

```
┌─────────────────────────────────────────────────────┐
│                  Presentation Layer                  │
│  (UIKit ViewControllers, SwiftUI Views, ViewModels)  │
└──────────────────┬──────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────┐
│                Use Cases Layer                       │
│     (Business Logic, Workflows, Coordinators)        │
└──────────────────┬──────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────┐
│                  Domain Layer                        │
│  (Models, Protocols, Validation, Events, Mappers)   │
└──────────────────┬──────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────┐
│                   State Layer                        │
│    (Repositories, CoreData, Cache, Sync, DI)         │
└─────────────────────────────────────────────────────┘
```

### Layer Responsibilities

#### Presentation Layer
- **Responsibility**: UI rendering, user interaction, state management
- **Components**: ViewControllers, ViewModels, Views
- **Rules**:
  - NEVER import CoreData
  - NEVER call repositories directly
  - Use UseCaseCoordinator for all business logic
  - Update UI on main thread: `DispatchQueue.main.async`
  - Subscribe to domain events via `DomainEventPublisher`

**Key Files**:
- `HomeViewController.swift` - Main task list (legacy UIKit)
- `AddTaskViewController.swift` - Task creation/editing
- `HomeViewModel.swift` - Home view state management
- `ProjectManagementViewModel.swift` - Project management state

#### Use Cases Layer
- **Responsibility**: Business workflows, orchestration, validation
- **Components**: Use cases, coordinators
- **Rules**:
  - NEVER import CoreData or UIKit
  - Depend on repository *protocols*, not concrete implementations
  - Publish domain events for cross-cutting concerns
  - Return domain models, not entities

**Key Files**:
- `UseCaseCoordinator.swift` - Orchestrates complex workflows
- `GetTasksUseCase.swift` - Task retrieval with filtering
- `CreateTaskUseCase.swift` - Task creation with validation
- `CompleteTaskUseCase.swift` - Task completion and scoring

#### Domain Layer
- **Responsibility**: Pure business logic, validation, domain models
- **Components**: Models, protocols, events, mappers
- **Rules**:
  - ONLY import Foundation
  - NO framework dependencies (CoreData, UIKit, etc.)
  - NO side effects (pure functions)
  - Validation in model methods

**Key Files**:
- `Task.swift` - Task domain model with business logic
- `Project.swift` - Project domain model
- `TaskRepositoryProtocol.swift` - Repository interface
- `TaskMapper.swift` - Entity↔Domain conversion
- `DomainEventPublisher.swift` - Event bus for cross-cutting concerns

#### State Layer
- **Responsibility**: Data persistence, caching, synchronization
- **Components**: Repositories, CoreData entities, cache, sync
- **Rules**:
  - Implement repository protocols from Domain
  - Use mappers for Entity↔Domain conversion
  - Handle CoreData context management
  - Cache-aware operations (check cache → fetch → cache)
  - Invalidate cache on writes

**Key Files**:
- `CoreDataTaskRepository.swift` - CoreData task persistence
- `CoreDataProjectRepository.swift` - CoreData project persistence
- `InMemoryCacheService.swift` - TTL-based cache
- `OfflineFirstSyncCoordinator.swift` - CloudKit sync
- `EnhancedDependencyContainer.swift` - Manual dependency injection

---

### Critical Patterns

#### 1. UUID Architecture
**All entities use UUIDs for stable, cross-device references.**

```swift
// Fixed Inbox UUID (ProjectConstants.swift:12)
public static let inboxProjectID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

// Task and Project have UUID properties
public struct Task {
    public let id: UUID
    public var projectID: UUID
}

public struct Project {
    public let id: UUID
}
```

**Why UUIDs?**
- CloudKit record IDs (stable across devices)
- Deterministic generation for legacy data (from CoreData objectID)
- No auto-increment conflicts in offline-first sync

#### 2. Mapper Pattern
**ALWAYS use mappers for Entity↔Domain conversion. NEVER manual mapping.**

```swift
// ✅ CORRECT
let tasks = TaskMapper.toDomainArray(from: entities)

// ❌ WRONG: Manual mapping (error-prone, no defaults)
let tasks = entities.map { Task(id: $0.taskID ?? UUID(), name: $0.name ?? "", ...) }
```

**Mapper Responsibilities**:
- Handle nil values with sensible defaults
- Backward compatibility for legacy data
- UUID generation if missing
- Enum conversions

**Key Methods**:
- `toDomain(from: Entity) -> Model`
- `toEntity(from: Model, in: Context) -> Entity`
- `updateEntity(_ entity: Entity, from: Model)`
- `toDomainArray(from: [Entity]) -> [Model]`

#### 3. Repository Adapter (Bridge Pattern)
**Bridges legacy CoreData with Clean Architecture protocols.**

```swift
final class TaskRepositoryAdapter: TaskRepositoryProtocol {
    private let legacyRepository: CoreDataTaskRepository
    private let cacheService: CacheServiceProtocol?

    func fetchAllTasks(completion: @escaping (Result<[Task], Error>) -> Void) {
        // Check cache
        if let cached = cacheService?.getCachedTasks(forDate: Date()) {
            completion(.success(cached))
            return
        }

        // Fetch from CoreData
        let entities = try context.fetch(NTask.fetchRequest())
        let tasks = TaskMapper.toDomainArray(from: entities)

        // Cache result
        cacheService?.cacheTasks(tasks, forDate: Date(), ttl: .minutes(15))
        completion(.success(tasks))
    }
}
```

#### 4. Domain Events (Combine)
**Publish events for cross-cutting concerns (analytics, notifications, UI refresh).**

```swift
// In Use Case - Publish
let event = TaskCompletedEvent(aggregateId: task.id, scoreEarned: task.score)
DomainEventPublisher.shared.publish(event)

// In ViewModel - Subscribe
DomainEventPublisher.shared.taskEvents
    .filter { $0.eventType == "TaskCompleted" }
    .sink { [weak self] _ in self?.loadAnalytics() }
    .store(in: &cancellables)
```

**Event Types**:
- `TaskCreated`, `TaskUpdated`, `TaskDeleted`, `TaskCompleted`
- `ProjectCreated`, `ProjectUpdated`, `ProjectDeleted`
- `PointsEarned`, `AchievementUnlocked`, `StreakMilestoneReached`

#### 5. Caching with TTL
**Repository-level caching for performance. Cache check → DB fetch → cache result.**

```swift
// InMemoryCacheService.swift:11
func cacheTasks(_ tasks: [Task], forDate date: Date) {
    set(tasks, forKey: "tasks_\(date.cacheKey)", expiration: .minutes(15))
}

// Invalidate on write
func createTask(_ task: Task, completion: ...) {
    // ... save to DB ...
    cacheService?.invalidateCache(for: task.dueDate)
}
```

**Cache Keys**:
- `"tasks_{date}"` - tasks for specific date
- `"projects_all"` - all projects
- `"daily_analytics_{date}"` - daily analytics
- `"filtered_tasks_{criteria_hash}"` - filtered task results

**TTLs**:
- Tasks: 15 minutes
- Projects: 30 minutes
- Analytics: 5 minutes
- Search results: 30 minutes

---

### Dependency Injection

Tasker uses **manual dependency injection** via `EnhancedDependencyContainer`.

```swift
// EnhancedDependencyContainer.swift:13
public final class EnhancedDependencyContainer {
    public static let shared = EnhancedDependencyContainer()

    // Repositories
    private(set) var taskRepository: TaskRepositoryProtocol!
    private(set) var projectRepository: ProjectRepositoryProtocol!

    // Services
    private(set) var cacheService: CacheServiceProtocol?
    private(set) var notificationService: NotificationServiceProtocol?
    private(set) var syncService: SyncServiceProtocol?

    // Use Case Coordinator
    private(set) var useCaseCoordinator: UseCaseCoordinator!

    func configure(with persistentContainer: NSPersistentContainer) {
        // Initialize repositories
        self.taskRepository = CoreDataTaskRepository(container: persistentContainer)
        self.projectRepository = CoreDataProjectRepository(container: persistentContainer)

        // Initialize services
        self.cacheService = InMemoryCacheService()
        self.notificationService = NotificationService()
        self.syncService = OfflineFirstSyncCoordinator(...)

        // Initialize use case coordinator
        self.useCaseCoordinator = UseCaseCoordinator(
            taskRepository: taskRepository,
            projectRepository: projectRepository,
            cacheService: cacheService,
            notificationService: notificationService
        )
    }
}
```

**Usage in ViewControllers**:
```swift
let coordinator = EnhancedDependencyContainer.shared.useCaseCoordinator

coordinator.getTasks.getTodayTasks { result in
    DispatchQueue.main.async {
        // Update UI
    }
}
```

---

### Data Flow Example: Creating a Task

```
User taps "Add Task" button
        ↓
AddTaskViewController validates input
        ↓
Calls UseCaseCoordinator.createTask.execute(request: CreateTaskRequest(...))
        ↓
CreateTaskUseCase applies business rules:
  - Validates name length (1-200 chars)
  - Defaults projectID to Inbox if missing
  - Adjusts past due dates to today
  - Determines task type (morning/evening/upcoming)
        ↓
CreateTaskUseCase calls taskRepository.createTask(Task(...))
        ↓
CoreDataTaskRepository:
  - Uses TaskMapper.toEntity(from: task, in: context)
  - Saves to CoreData
  - Invalidates cache
  - Schedules notification
  - Publishes TaskCreated event
        ↓
UseCase calls completion(.success(task))
        ↓
ViewController updates UI on main thread
        ↓
DomainEventPublisher notifies subscribers (analytics, other ViewModels)
        ↓
OfflineFirstSyncCoordinator syncs to CloudKit in background
```

---

## Use Cases Documentation

### Task Use Cases (18 Total)

#### Core Task Management

| Use Case | Responsibility | Key Methods | Dependencies |
|----------|----------------|-------------|--------------|
| **GetTasksUseCase** | Fetch tasks with filtering | `getTodayTasks`, `getOverdueTasks`, `getTasksForProject`, `searchTasks` | TaskRepositoryProtocol, CacheServiceProtocol |
| **CreateTaskUseCase** | Create task with validation | `execute(request: CreateTaskRequest)` | TaskRepositoryProtocol, ProjectRepositoryProtocol, NotificationServiceProtocol |
| **UpdateTaskUseCase** | Update task properties | `execute(task: Task)`, `bulkUpdate(tasks: [Task])` | TaskRepositoryProtocol, NotificationServiceProtocol |
| **CompleteTaskUseCase** | Toggle completion status | `completeTask(taskId: UUID)`, `uncompleteTask(taskId: UUID)` | TaskRepositoryProtocol, TaskScoringServiceProtocol, AnalyticsServiceProtocol |
| **DeleteTaskUseCase** | Delete tasks | `execute(taskId: UUID)`, `batchDelete(taskIds: [UUID])`, `deleteCompleted()` | TaskRepositoryProtocol, NotificationServiceProtocol |
| **RescheduleTaskUseCase** | Reschedule tasks | `execute(taskId: UUID, newDate: Date)`, `suggestRescheduleDates(task: Task)` | TaskRepositoryProtocol, NotificationServiceProtocol |

#### Task Filtering & Organization

| Use Case | Responsibility | Key Methods | Dependencies |
|----------|----------------|-------------|--------------|
| **FilterTasksUseCase** | Advanced filtering | `execute(criteria: FilterCriteria)` | TaskRepositoryProtocol, CacheServiceProtocol |
| **SearchTasksUseCase** | Search with multiple modes | `simpleSearch(query: String)`, `advancedSearch(criteria: SearchCriteria)`, `getSearchSuggestions()` | TaskRepositoryProtocol, CacheServiceProtocol |
| **SortTasksUseCase** | Multi-criteria sorting | `sort(tasks: [Task], by: SortCriterion)`, `smartSort(tasks: [Task], context: SortContext)`, `groupAndSort(tasks: [Task], groupBy: GroupCriterion)` | CacheServiceProtocol |
| **GetTaskStatisticsUseCase** | Task statistics | `getDailyStatistics(date: Date)`, `getProjectStatistics(projectId: UUID)` | TaskRepositoryProtocol, CacheServiceProtocol |

#### Advanced Task Features

| Use Case | Responsibility | Key Methods | Dependencies |
|----------|----------------|-------------|--------------|
| **BulkUpdateTasksUseCase** | Batch operations | `bulkComplete(taskIds: [UUID])`, `bulkDelete(taskIds: [UUID])`, `bulkUpdatePriority(taskIds: [UUID], priority: TaskPriority)` | TaskRepositoryProtocol, DomainEventPublisher |
| **ArchiveCompletedTasksUseCase** | Task lifecycle management | `archiveOlderThan(days: Int)`, `archiveByProject(projectId: UUID)`, `smartArchive()`, `restoreArchived(taskIds: [UUID])` | TaskRepositoryProtocol |
| **TaskRecommendationUseCase** | Intelligent suggestions | `getPersonalizedRecommendations(context: RecommendationContext)`, `getNextBestTask(context: RecommendationContext)`, `getTaskBreakdownSuggestions(task: Task)` | TaskRepositoryProtocol |
| **TaskGameificationUseCase** | Gamification system | `calculateUserProgress()`, `processTaskCompletion(task: Task, quality: CompletionQuality)`, `getAchievementProgress()`, `getActiveChallenges()`, `calculateStreakInfo()` | TaskRepositoryProtocol, DomainEventPublisher |
| **TaskPriorityOptimizerUseCase** | Priority optimization | `optimizeAllPriorities()`, `suggestPriorityAdjustment(task: Task)`, `generatePriorityInsights()` | TaskRepositoryProtocol |
| **TaskHabitBuilderUseCase** | Habit management | `createHabitTask(habitDefinition: HabitDefinition)`, `completeHabitOccurrence(habitTaskId: UUID, taskId: UUID)`, `getHabitProgress(habitTaskId: UUID)`, `getHabitTemplates(category: TaskCategory?)` | TaskRepositoryProtocol, DomainEventPublisher |
| **TaskCollaborationUseCase** | Collaboration (planned) | `shareTask(taskId: UUID, with: [UUID])`, `assignTask(taskId: UUID, to: UUID)`, `addComment(to: UUID, content: String)` | TaskRepositoryProtocol, UserRepositoryProtocol, CollaborationRepositoryProtocol, NotificationServiceProtocol |
| **AssignOrphanedTasksToInboxUseCase** | Data integrity | `execute()` | TaskRepositoryProtocol, ProjectRepositoryProtocol |

---

### Project Use Cases (4 Total)

| Use Case | Responsibility | Key Methods | Dependencies |
|----------|----------------|-------------|--------------|
| **ManageProjectsUseCase** | Project CRUD | `createProject(request: CreateProjectRequest)`, `updateProject(project: Project)`, `deleteProject(projectId: UUID, strategy: DeletionStrategy)`, `getAllProjects()`, `moveTasksToProject(taskIds: [UUID], projectId: UUID)` | ProjectRepositoryProtocol, TaskRepositoryProtocol |
| **FilterProjectsUseCase** | Project filtering | `execute(criteria: ProjectFilterCriteria)` | ProjectRepositoryProtocol |
| **GetProjectStatisticsUseCase** | Project analytics | `getProjectOverview()`, `getProjectStatistics(projectId: UUID)` | ProjectRepositoryProtocol, TaskRepositoryProtocol |
| **EnsureInboxProjectUseCase** | System initialization | `execute()` | ProjectRepositoryProtocol |

---

### Analytics Use Cases (2 Total)

| Use Case | Responsibility | Key Methods | Dependencies |
|----------|----------------|-------------|--------------|
| **CalculateAnalyticsUseCase** | Analytics computation | `calculateTodayAnalytics()`, `calculateWeeklyAnalytics(startDate: Date)`, `calculateMonthlyAnalytics(month: Int, year: Int)`, `calculateProductivityScore()`, `calculateStreak()` | TaskRepositoryProtocol, TaskScoringServiceProtocol, CacheServiceProtocol |
| **GenerateProductivityReportUseCase** | Report generation | `generateDailyReport(date: Date)`, `generateReport(period: ReportPeriod)` | TaskRepositoryProtocol |

---

### Workflow Orchestration (UseCaseCoordinator)

| Workflow | Description | Use Cases Involved |
|----------|-------------|-------------------|
| **completeMorningRoutine** | Complete all morning tasks | GetTasksUseCase, CompleteTaskUseCase |
| **rescheduleAllOverdueTasks** | Bulk reschedule to today | GetTasksUseCase, RescheduleTaskUseCase |
| **createProjectWithTasks** | Create project + seed tasks | ManageProjectsUseCase, CreateTaskUseCase |
| **getDailyDashboard** | Aggregate daily data | GetTasksUseCase, CalculateAnalyticsUseCase |
| **performEndOfDayCleanup** | Reschedule high-priority incomplete tasks, clear cache | GetTasksUseCase, RescheduleTaskUseCase, CacheServiceProtocol |

---

## Data Models & Domain Layer

### Core Domain Models

#### Task Model

```swift
// Domain/Models/Task.swift:12
public struct Task {
    // Core Properties
    public let id: UUID
    public var projectID: UUID
    public var name: String
    public var details: String?
    public var type: TaskType
    public var priority: TaskPriority
    public var dueDate: Date?
    public var project: String? // Deprecated: use projectID
    public var isComplete: Bool
    public var dateAdded: Date
    public var dateCompleted: Date?
    public var isEveningTask: Bool
    public var alertReminderTime: Date?

    // Enhanced Properties
    public var estimatedDuration: TimeInterval?
    public var actualDuration: TimeInterval?
    public var tags: [String]
    public var dependencies: [UUID] // Task dependencies
    public var subtasks: [UUID] // Subtask IDs
    public var category: TaskCategory
    public var energy: TaskEnergy
    public var context: TaskContext
    public var repeatPattern: TaskRepeatPattern?

    // Business Logic
    public var score: Int { priority.scorePoints }
    public var isOverdue: Bool { ... }
    public var isDueToday: Bool { ... }
    public var isMorningTask: Bool { type == .morning }
    public var isUpcomingTask: Bool { type == .upcoming }

    // Enhanced Logic
    public func canBeCompletedToday() -> Bool { ... }
    public func calculateEfficiencyScore() -> Double { estimated / actual }
    public func isBlocked() -> Bool { !dependencies.isEmpty }
    public var complexityScore: Int { ... }

    // Validation
    public func validate() throws { ... }
}
```

#### Project Model

```swift
// Domain/Models/Project.swift
public struct Project {
    // Core Properties
    public let id: UUID
    public var name: String
    public var projectDescription: String?
    public var createdDate: Date
    public var modifiedDate: Date
    public var isDefault: Bool

    // Enhanced Properties
    public var color: ProjectColor
    public var icon: ProjectIcon
    public var status: ProjectStatus
    public var priority: ProjectPriority
    public var parentProjectId: UUID?
    public var subprojectIds: [UUID]
    public var tags: [String]
    public var dueDate: Date?
    public var estimatedTaskCount: Int?
    public var isArchived: Bool
    public var templateId: UUID?
    public var settings: ProjectSettings

    // Factory Methods
    public static func createInbox() -> Project { ... }

    // Business Logic
    public var isInbox: Bool { id == ProjectConstants.inboxProjectID }
    public var isOverdue: Bool { ... }
    public var isActive: Bool { ... }
    public var hasSubprojects: Bool { !subprojectIds.isEmpty }
    public func calculateHealthScore(completedTasks: Int, totalTasks: Int) -> ProjectHealth { ... }

    // Validation
    public func validate() throws { ... }
}
```

---

### Enums & Value Types

#### TaskPriority

```swift
public enum TaskPriority: Int16, Codable, CaseIterable {
    case max = 0    // P0 - Highest priority (7 points)
    case high = 1   // P1 - High priority (4 points)
    case medium = 2 // P2 - Medium priority (3 points)
    case low = 3    // P3 - Low priority (2 points)

    public var scorePoints: Int {
        switch self {
        case .max: return 7
        case .high: return 4
        case .medium: return 3
        case .low: return 2
        }
    }

    public var displayName: String { ... }
    public var shortName: String { ... } // P0, P1, P2, P3
}
```

#### TaskType

```swift
public enum TaskType: Int16, Codable, CaseIterable {
    case morning = 0   // Morning tasks (before noon)
    case evening = 1   // Evening tasks (after 5 PM)
    case upcoming = 2  // Future tasks or no specific time

    public var displayName: String { ... }
}
```

#### TaskCategory

```swift
public enum TaskCategory: String, Codable, CaseIterable {
    case general, work, personal, health, learning,
         shopping, finance, social, creative, maintenance

    public var displayName: String { ... }
    public var icon: String { ... } // Emoji icons
}
```

#### TaskEnergy

```swift
public enum TaskEnergy: String, Codable, CaseIterable {
    case low, medium, high

    public var displayName: String { ... }
    public var icon: String { ... }
}
```

#### TaskContext

```swift
public enum TaskContext: String, Codable, CaseIterable {
    case work, home, anywhere, commute, errands, online

    public var displayName: String { ... }
    public var icon: String { ... }
}
```

---

### Repository Protocols

#### TaskRepositoryProtocol

```swift
// Domain/Interfaces/TaskRepositoryProtocol.swift:12
public protocol TaskRepositoryProtocol {
    // Core CRUD
    func createTask(_ task: Task, completion: @escaping (Result<Task, Error>) -> Void)
    func fetchTask(withId id: UUID, completion: @escaping (Result<Task?, Error>) -> Void)
    func updateTask(_ task: Task, completion: @escaping (Result<Task, Error>) -> Void)
    func deleteTask(withId id: UUID, completion: @escaping (Result<Void, Error>) -> Void)

    // Fetching
    func fetchAllTasks(completion: @escaping (Result<[Task], Error>) -> Void)
    func fetchTasksForDate(_ date: Date, completion: @escaping (Result<[Task], Error>) -> Void)
    func fetchTasksForProject(withId projectId: UUID, completion: @escaping (Result<[Task], Error>) -> Void)
    func fetchOverdueTasks(completion: @escaping (Result<[Task], Error>) -> Void)
    func fetchCompletedTasks(completion: @escaping (Result<[Task], Error>) -> Void)

    // Actions
    func completeTask(withId id: UUID, completion: @escaping (Result<Task, Error>) -> Void)
    func rescheduleTask(withId id: UUID, newDate: Date, completion: @escaping (Result<Task, Error>) -> Void)
}
```

#### ProjectRepositoryProtocol

```swift
// Domain/Interfaces/ProjectRepositoryProtocol.swift
public protocol ProjectRepositoryProtocol {
    // Core CRUD
    func createProject(_ project: Project, completion: @escaping (Result<Project, Error>) -> Void)
    func fetchProject(withId id: UUID, completion: @escaping (Result<Project?, Error>) -> Void)
    func updateProject(_ project: Project, completion: @escaping (Result<Project, Error>) -> Void)
    func deleteProject(withId id: UUID, completion: @escaping (Result<Void, Error>) -> Void)

    // Fetching
    func fetchAllProjects(completion: @escaping (Result<[Project], Error>) -> Void)
    func fetchCustomProjects(completion: @escaping (Result<[Project], Error>) -> Void)
    func fetchInboxProject(completion: @escaping (Result<Project?, Error>) -> Void)
}
```

---

### Mappers

#### TaskMapper

```swift
// Domain/Mappers/TaskMapper.swift:12
public class TaskMapper {
    // Entity → Domain
    public static func toDomain(from entity: NTask) -> Task {
        let id = entity.taskID ?? generateUUID(from: entity.objectID)
        return Task(
            id: id,
            projectID: entity.projectID ?? ProjectConstants.inboxProjectID,
            name: entity.name ?? "",
            details: entity.details,
            type: TaskType(rawValue: entity.type) ?? .morning,
            priority: TaskPriority(rawValue: entity.priority) ?? .low,
            dueDate: entity.dueDate,
            project: entity.project,
            isComplete: entity.isComplete,
            dateAdded: entity.dateAdded ?? Date(),
            dateCompleted: entity.dateCompleted,
            isEveningTask: entity.isEveningTask,
            alertReminderTime: entity.alertReminderTime,
            estimatedDuration: entity.estimatedDuration > 0 ? entity.estimatedDuration : nil,
            actualDuration: entity.actualDuration > 0 ? entity.actualDuration : nil,
            tags: (entity.tags as? [String]) ?? [],
            dependencies: (entity.dependencies as? [UUID]) ?? [],
            subtasks: (entity.subtasks as? [UUID]) ?? [],
            category: TaskCategory(rawValue: entity.category ?? "general") ?? .general,
            energy: TaskEnergy(rawValue: entity.energy ?? "medium") ?? .medium,
            context: TaskContext(rawValue: entity.context ?? "anywhere") ?? .anywhere,
            repeatPattern: nil // TODO: Implement repeat pattern deserialization
        )
    }

    // Domain → Entity
    public static func toEntity(from task: Task, in context: NSManagedObjectContext) -> NTask {
        let entity = NTask(context: context)
        updateEntity(entity, from: task)
        return entity
    }

    // Update Entity from Domain
    public static func updateEntity(_ entity: NTask, from task: Task) {
        entity.taskID = task.id
        entity.projectID = task.projectID
        entity.name = task.name
        entity.details = task.details
        entity.type = task.type.rawValue
        entity.priority = task.priority.rawValue
        entity.dueDate = task.dueDate
        entity.project = task.project
        entity.isComplete = task.isComplete
        entity.dateAdded = task.dateAdded
        entity.dateCompleted = task.dateCompleted
        entity.isEveningTask = task.isEveningTask
        entity.alertReminderTime = task.alertReminderTime
        entity.estimatedDuration = task.estimatedDuration ?? 0
        entity.actualDuration = task.actualDuration ?? 0
        entity.tags = task.tags as NSArray
        entity.dependencies = task.dependencies as NSArray
        entity.subtasks = task.subtasks as NSArray
        entity.category = task.category.rawValue
        entity.energy = task.energy.rawValue
        entity.context = task.context.rawValue
    }

    // Array Conversion
    public static func toDomainArray(from entities: [NTask]) -> [Task] {
        return entities.map { toDomain(from: $0) }
    }

    // UUID Generation (for backward compatibility)
    private static func generateUUID(from objectID: NSManagedObjectID) -> UUID {
        return UUIDGenerator.generateUUID(from: objectID)
    }
}
```

---

### Domain Events

```swift
// Domain/Events/DomainEvent.swift
public protocol DomainEvent {
    var eventId: UUID { get }
    var occurredAt: Date { get }
    var eventType: String { get }
    var aggregateId: UUID { get }
    var metadata: [String: Any]? { get }
}

// Domain/Events/TaskEvents.swift
public struct TaskCreated: DomainEvent {
    public let eventId = UUID()
    public let occurredAt = Date()
    public let eventType = "TaskCreated"
    public let aggregateId: UUID
    public let metadata: [String: Any]?
    public let task: Task

    public init(task: Task) {
        self.task = task
        self.aggregateId = task.id
        self.metadata = ["taskId": task.id.uuidString, "taskName": task.name]
    }
}

// Domain/Events/DomainEventPublisher.swift:21
public final class DomainEventPublisher {
    public static let shared = DomainEventPublisher()

    public let taskEvents = PassthroughSubject<DomainEvent, Never>()
    public let projectEvents = PassthroughSubject<DomainEvent, Never>()

    public func publish(_ event: DomainEvent) {
        if event.eventType.contains("Task") {
            taskEvents.send(event)
        } else if event.eventType.contains("Project") {
            projectEvents.send(event)
        }
    }
}
```

---

## Cloud Services & Synchronization

### CloudKit Integration

**CloudKit Container**: `iCloud.com.yourcompany.tasker`

**Record Types**:
- `Task`: Maps to `Task` domain model
- `Project`: Maps to `Project` domain model

**Record Structure**:
```swift
// Task CloudKit Record
CKRecord(recordType: "Task") {
    "taskID": UUID (string)
    "projectID": UUID (string)
    "name": String
    "details": String?
    "type": Int16
    "priority": Int16
    "dueDate": Date?
    "isComplete": Bool
    "dateAdded": Date
    "dateCompleted": Date?
    "isEveningTask": Bool
    "tags": [String]
    "category": String
    "energy": String
    "context": String
    "modifiedDate": Date
}
```

**Sync Strategy**: Offline-First

1. **Local Write**: All changes written to CoreData immediately
2. **Sync Queue**: Changes queued for CloudKit sync
3. **Background Sync**: `OfflineFirstSyncCoordinator` processes queue
4. **Conflict Resolution**: Last-write-wins based on `modifiedDate`
5. **Subscriptions**: CloudKit subscriptions for push notifications on remote changes

**Sync Triggers**:
- App launch
- App becomes active
- Background fetch (every 15 minutes)
- Manual sync (pull-to-refresh)
- On CRUD operation (debounced 3 seconds)

---

## Analytics & Gamification

### Scoring System

**Base Points by Priority**:
- P0 (Max): 7 points
- P1 (High): 4 points
- P2 (Medium): 3 points
- P3 (Low): 2 points

**Quality Multipliers**:
- Poor: 0.5x
- Standard: 1.0x
- Good: 1.2x
- Excellent: 1.5x

**Bonus Points**:
- Category bonus: Health +2, Learning +3, Work +1
- Energy bonus: High +2, Medium +1
- Timely completion: +20% if early, +10% if on time
- Streak bonus: +10% per 7-day milestone

**Total Score Formula**:
```
totalScore = (basePoints + categoryBonus + energyBonus) × qualityMultiplier × timelyMultiplier × streakMultiplier
```

---

### Level Progression

**Formula**: `level = sqrt(totalPoints / 100) + 1` (max 50)

**Level Titles**:
- 1-5: Beginner
- 6-10: Apprentice
- 11-15: Skilled
- 16-20: Expert
- 21-30: Master
- 31-40: Grandmaster
- 41-50: Legend
- 50+: Ultimate

**Points for Levels**:
- Level 1: 0 points
- Level 10: 8,100 points
- Level 20: 36,100 points
- Level 30: 84,100 points
- Level 50: 240,100 points

---

### Achievements

**Achievement Categories**:

1. **Milestones** (Common to Uncommon):
   - First Task Completed (10 pts)
   - 10 Tasks Completed (20 pts)
   - 50 Tasks Completed (50 pts)
   - 100 Tasks Completed (100 pts, Uncommon)
   - 500 Tasks Completed (250 pts, Rare)

2. **Streaks** (Uncommon to Legendary):
   - Week Warrior (7 days, 50 pts, Uncommon)
   - Fortnight Fighter (14 days, 100 pts, Rare)
   - Month Master (30 days, 200 pts, Rare)
   - Quarter Champion (60 days, 400 pts, Epic)
   - Century Club (100 days, 750 pts, Epic)
   - Legend (365 days, 2000 pts, Legendary)

3. **Category Mastery** (Rare):
   - Complete 25 tasks in a category (100 pts)
   - Complete 50 tasks in a category (200 pts)

4. **Speed** (Uncommon):
   - Lightning Fast: Complete task within 1 hour of creation (25 pts)

5. **Perfection** (Epic):
   - Perfect Day: Complete all scheduled tasks in a day (150 pts)
   - Perfect Week: 7 consecutive perfect days (500 pts)

---

## Technical Debt & Future Roadmap

### Current Technical Debt

#### High Priority

1. **Legacy UIKit ViewControllers** (40% of codebase)
   - `HomeViewController` still uses CoreData directly (bypassing use cases)
   - Direct context access in multiple view controllers
   - **Effort**: 4-6 weeks
   - **Impact**: Breaks Clean Architecture principles, makes testing difficult

2. **Incomplete Collaboration Features**
   - Use case skeletons exist but not implemented
   - No CloudKit record sharing
   - No user management system
   - **Effort**: 8-12 weeks
   - **Impact**: Major feature missing for team use

3. **Missing Unit Tests**
   - Use case layer: 0% coverage
   - Domain layer: 10% coverage
   - Repository layer: 5% coverage
   - **Effort**: 6-8 weeks for 70% coverage
   - **Impact**: Regressions, refactoring risk

4. **No UI/E2E Tests**
   - UI testing infrastructure exists but minimal tests
   - Accessibility identifiers implemented but not fully utilized
   - **Effort**: 4-6 weeks
   - **Impact**: Manual testing burden, regression risk

#### Medium Priority

5. **Habit Builder UI Missing**
   - Use case fully implemented
   - No UI screens for habit management
   - **Effort**: 3-4 weeks
   - **Impact**: Feature not accessible to users

6. **Task Time Tracking Incomplete**
   - Domain model supports duration tracking
   - No timer UI
   - No efficiency analytics UI
   - **Effort**: 2-3 weeks
   - **Impact**: Feature incomplete

7. **Priority Optimizer Not Automated**
   - Use case implemented
   - Not triggered automatically
   - No background processing
   - **Effort**: 1-2 weeks
   - **Impact**: Feature requires manual trigger

8. **No Export/Import**
   - No data export (JSON/CSV)
   - No data import
   - No backup mechanism (beyond iCloud)
   - **Effort**: 2-3 weeks
   - **Impact**: User data portability

#### Low Priority

9. **No Widget Support**
   - iOS widgets for today's tasks
   - **Effort**: 2-3 weeks
   - **Impact**: Convenience feature

10. **No Watch App**
    - Quick task capture on Apple Watch
    - Task completion on Watch
    - **Effort**: 4-6 weeks
    - **Impact**: Extended platform support

11. **No Siri Shortcuts**
    - Voice commands for task creation/completion
    - **Effort**: 1-2 weeks
    - **Impact**: Accessibility and convenience

---

### Roadmap (Next 12 Months)

#### Q1 2026 (Jan-Mar)

**Theme**: Architecture Migration & Stability

- **Complete Clean Architecture Migration** (6 weeks)
  - Migrate remaining legacy ViewControllers to use UseCaseCoordinator
  - Remove direct CoreData access from presentation layer
  - Implement ViewModels for all major screens

- **Testing Foundation** (6 weeks)
  - Unit tests for all use cases (70% coverage goal)
  - Unit tests for domain models (80% coverage goal)
  - Repository tests with in-memory CoreData

- **Habit Builder UI** (4 weeks)
  - Habit creation screens
  - Habit progress dashboard
  - Habit templates library

#### Q2 2026 (Apr-Jun)

**Theme**: Collaboration & Team Features

- **User Management System** (4 weeks)
  - User profiles
  - User authentication (Firebase Auth or CloudKit)
  - User search and discovery

- **Task Sharing MVP** (6 weeks)
  - Share tasks with users
  - CloudKit record sharing
  - Permissions management (view/edit/full access)

- **Comments & Activity** (3 weeks)
  - Task comments with mentions
  - Activity feed
  - Real-time sync via TaskCollaborationSyncService

#### Q3 2026 (Jul-Sep)

**Theme**: Intelligence & Optimization

- **Task Time Tracking** (3 weeks)
  - Timer UI for active tasks
  - Efficiency analytics dashboard
  - Estimate improvement suggestions

- **Automated Priority Optimization** (2 weeks)
  - Background job for nightly optimization
  - Auto-adjust priorities with user approval
  - Optimization insights in analytics

- **Enhanced Recommendations** (4 weeks)
  - ML-based pattern learning
  - Contextual recommendations (location, time, energy)
  - Task breakdown AI suggestions

- **UI/E2E Testing** (4 weeks)
  - Critical user flow tests (create, complete, reschedule tasks)
  - Regression test suite
  - CI/CD integration

#### Q4 2026 (Oct-Dec)

**Theme**: Platform Expansion & Polish

- **iOS Widgets** (3 weeks)
  - Today's tasks widget
  - Streak widget
  - Quick add task widget

- **Apple Watch App** (6 weeks)
  - Task list view
  - Quick task capture
  - Task completion

- **Siri Shortcuts** (2 weeks)
  - "Add task" shortcut
  - "Complete task" shortcut
  - "Show today's tasks" shortcut

- **Export/Import & Backup** (3 weeks)
  - JSON/CSV export
  - Data import
  - Manual iCloud backup trigger

---

### Migration Strategy: Legacy to Clean Architecture

**Current State**: 40% of ViewControllers still use CoreData directly

**Goal**: 100% Clean Architecture compliance by Q1 2026 end

**Approach**: Incremental migration, starting with high-traffic screens

**Priority Order**:
1. `HomeViewController` (highest traffic, most complex)
2. `AddTaskViewController` (task creation, frequently used)
3. `FluentUIToDoTableViewController` (task detail view)
4. `ProjectManagementViewController` (project CRUD)
5. `SettingsPageViewController` (settings)

**Migration Steps per ViewController**:

1. **Create ViewModel**:
   ```swift
   public final class HomeViewModel: ObservableObject {
       @Published var todayTasks: [Task] = []
       @Published var isLoading: Bool = false
       @Published var error: Error?

       private let useCaseCoordinator: UseCaseCoordinator
       private var cancellables = Set<AnyCancellable>()

       public init(useCaseCoordinator: UseCaseCoordinator) {
           self.useCaseCoordinator = useCaseCoordinator
           subscribeToEvents()
       }

       public func loadTodayTasks() {
           isLoading = true
           useCaseCoordinator.getTasks.getTodayTasks { [weak self] result in
               DispatchQueue.main.async {
                   self?.isLoading = false
                   switch result {
                   case .success(let tasksResult):
                       self?.todayTasks = tasksResult.allTasks
                   case .failure(let error):
                       self?.error = error
                   }
               }
           }
       }

       private func subscribeToEvents() {
           DomainEventPublisher.shared.taskEvents
               .filter { $0.eventType == "TaskCreated" || $0.eventType == "TaskUpdated" || $0.eventType == "TaskDeleted" }
               .sink { [weak self] _ in self?.loadTodayTasks() }
               .store(in: &cancellables)
       }
   }
   ```

2. **Inject ViewModel into ViewController**:
   ```swift
   class HomeViewController: UIViewController {
       private var viewModel: HomeViewModel!
       private var cancellables = Set<AnyCancellable>()

       override func viewDidLoad() {
           super.viewDidLoad()
           viewModel = HomeViewModel(useCaseCoordinator: EnhancedDependencyContainer.shared.useCaseCoordinator)
           bindViewModel()
           viewModel.loadTodayTasks()
       }

       private func bindViewModel() {
           viewModel.$todayTasks
               .receive(on: DispatchQueue.main)
               .sink { [weak self] tasks in
                   self?.updateUI(with: tasks)
               }
               .store(in: &cancellables)

           viewModel.$error
               .compactMap { $0 }
               .receive(on: DispatchQueue.main)
               .sink { [weak self] error in
                   self?.showError(error)
               }
               .store(in: &cancellables)
       }

       private func updateUI(with tasks: [Task]) {
           // Update table view, charts, etc.
       }
   }
   ```

3. **Remove CoreData References**:
   - Delete `import CoreData`
   - Remove `NSFetchedResultsController`
   - Remove direct context access
   - Remove manual mapping

4. **Test**:
   - Manual testing (all user flows)
   - Unit test ViewModel (mocked use case coordinator)

**Estimated Effort per Screen**:
- Simple screen (Settings): 2-3 days
- Medium screen (Add Task): 4-5 days
- Complex screen (Home): 7-10 days

**Total Estimated Time**: 6-8 weeks for all screens

---

## Success Metrics

### User Engagement

- **Daily Active Users (DAU)**: Target 25% YoY growth
- **Monthly Active Users (MAU)**: Target 20% YoY growth
- **DAU/MAU Ratio**: Target 40%+ (indicates high retention)
- **Session Length**: Target 5-7 minutes/day
- **Sessions per Day**: Target 3-5 sessions

### Task Management Metrics

- **Tasks Created per User per Day**: Target 5-10 tasks
- **Task Completion Rate**: Target 70%+ for active users
- **Overdue Task Rate**: Target <15%
- **Time to Complete Task**: Average 2-3 days from creation
- **Tasks per Project**: Average 10-20 active tasks per custom project

### Gamification Engagement

- **Streak Participation**: Target 60% of users maintain 3+ day streaks
- **7-Day Streak Retention**: Target 40% of users
- **Achievement Unlock Rate**: Target 3-5 achievements per user per month
- **Level Progression**: Average level 8-12 for active users (3+ months)
- **Points per Day**: Average 15-25 points/day

### Analytics Usage

- **Analytics Screen Views**: Target 30% of sessions include analytics view
- **Report Generation**: Target 10% of users generate reports weekly
- **Productivity Score Awareness**: Target 50% of users check score weekly

### Sync & Reliability

- **CloudKit Sync Success Rate**: Target 99%+ of sync operations succeed
- **Sync Conflict Rate**: Target <1% of syncs have conflicts
- **Offline Usage**: Target 20%+ of sessions occur offline (cached data)
- **Data Loss Rate**: Target 0% (zero data loss)

### App Store Performance

- **App Store Rating**: Target 4.5+ stars
- **Crash-Free Sessions**: Target 99.5%+
- **App Launch Time**: Target <2 seconds (cold start)
- **Conversion Rate** (free → paid, if freemium): Target 5-10%

### Technical Performance

- **Unit Test Coverage**: Target 70%+ by Q1 2026 end
- **UI Test Coverage**: Target 40%+ by Q3 2026 end
- **Build Success Rate**: Target 95%+ (CI/CD)
- **Code Quality** (SonarQube or similar): Target A rating

---

## Appendices

### A. Technology Stack

**Core Technologies**:
- **Language**: Swift 5+
- **Minimum iOS**: 16.0
- **UI Framework**: UIKit (primary), SwiftUI (planned migration)
- **Data Persistence**: CoreData
- **Cloud Sync**: CloudKit
- **Reactive**: Combine
- **Architecture**: Clean Architecture (60% migrated)

**Third-Party Dependencies** (CocoaPods):

| Pod | Version | Purpose |
|-----|---------|---------|
| MicrosoftFluentUI | ~> 0.12 | Modern UI components |
| MaterialComponents | ~> 124 | Material Design elements |
| DGCharts | ~> 5.0 | Analytics charts |
| FSCalendar | ~> 2.8 | Calendar views |
| BEMCheckBox | ~> 1.4 | Animated checkboxes |
| CircleMenu | ~> 5.0 | FAB circular menu |
| Firebase/Analytics | ~> 10.0 | Analytics tracking |
| Firebase/Crashlytics | ~> 10.0 | Crash reporting |
| Firebase/Performance | ~> 10.0 | Performance monitoring |
| ViewAnimator | ~> 3.1 | List animations |
| Timepiece | ~> 5.0 | Date utilities |
| TinyConstraints | ~> 4.0 | Auto Layout DSL |

---

### B. File Structure

```
Tasker/
├── To Do List/
│   ├── Domain/
│   │   ├── Models/
│   │   │   ├── Task.swift
│   │   │   ├── Project.swift
│   │   │   ├── TaskPriority.swift
│   │   │   ├── TaskType.swift
│   │   │   ├── TaskCategory.swift
│   │   │   └── ...
│   │   ├── Interfaces/
│   │   │   ├── TaskRepositoryProtocol.swift
│   │   │   ├── ProjectRepositoryProtocol.swift
│   │   │   ├── CacheServiceProtocol.swift
│   │   │   └── ...
│   │   ├── Mappers/
│   │   │   ├── TaskMapper.swift
│   │   │   └── ProjectMapper.swift
│   │   ├── Events/
│   │   │   ├── DomainEvent.swift
│   │   │   ├── DomainEventPublisher.swift
│   │   │   ├── TaskEvents.swift
│   │   │   └── ProjectEvents.swift
│   │   ├── Constants/
│   │   │   └── ProjectConstants.swift
│   │   └── Services/
│   │       └── UUIDGenerator.swift
│   ├── UseCases/
│   │   ├── Coordinator/
│   │   │   └── UseCaseCoordinator.swift
│   │   ├── Task/
│   │   │   ├── GetTasksUseCase.swift
│   │   │   ├── CreateTaskUseCase.swift
│   │   │   ├── UpdateTaskUseCase.swift
│   │   │   ├── CompleteTaskUseCase.swift
│   │   │   ├── DeleteTaskUseCase.swift
│   │   │   ├── RescheduleTaskUseCase.swift
│   │   │   ├── FilterTasksUseCase.swift
│   │   │   ├── SearchTasksUseCase.swift
│   │   │   ├── SortTasksUseCase.swift
│   │   │   ├── BulkUpdateTasksUseCase.swift
│   │   │   ├── ArchiveCompletedTasksUseCase.swift
│   │   │   ├── TaskRecommendationUseCase.swift
│   │   │   ├── TaskGameificationUseCase.swift
│   │   │   ├── TaskPriorityOptimizerUseCase.swift
│   │   │   ├── TaskHabitBuilderUseCase.swift
│   │   │   └── TaskCollaborationUseCase.swift
│   │   ├── Project/
│   │   │   ├── ManageProjectsUseCase.swift
│   │   │   ├── FilterProjectsUseCase.swift
│   │   │   ├── GetProjectStatisticsUseCase.swift
│   │   │   └── EnsureInboxProjectUseCase.swift
│   │   └── Analytics/
│   │       ├── CalculateAnalyticsUseCase.swift
│   │       └── GenerateProductivityReportUseCase.swift
│   ├── State/
│   │   ├── Repositories/
│   │   │   ├── CoreDataTaskRepository.swift
│   │   │   ├── CoreDataProjectRepository.swift
│   │   │   └── TaskRepositoryAdapter.swift
│   │   ├── Cache/
│   │   │   └── InMemoryCacheService.swift
│   │   ├── Sync/
│   │   │   └── OfflineFirstSyncCoordinator.swift
│   │   └── DI/
│   │       └── EnhancedDependencyContainer.swift
│   ├── Presentation/
│   │   └── ViewModels/
│   │       ├── HomeViewModel.swift
│   │       ├── AddTaskViewModel.swift
│   │       └── ProjectManagementViewModel.swift
│   ├── ViewControllers/
│   │   ├── HomeViewController.swift
│   │   ├── AddTaskViewController.swift
│   │   ├── FluentUIToDoTableViewController.swift
│   │   ├── ProjectManagementViewController.swift
│   │   └── SettingsPageViewController.swift
│   ├── View/
│   │   ├── AddTaskForedropView.swift
│   │   ├── AddTaskBackdropView.swift
│   │   └── ...
│   ├── Services/
│   │   ├── ChartDataService.swift
│   │   ├── LoggingService.swift
│   │   └── ...
│   ├── Utils/
│   │   └── ToDoTimeUtils.swift
│   ├── AppDelegate.swift
│   ├── SceneDelegate.swift
│   └── TaskModel.xcdatamodeld/
│       └── TaskModel.xcdatamodel/
│           └── contents (CoreData schema)
├── To Do ListTests/
├── To Do ListUITests/
├── Podfile
├── README.md
├── claude.md (architecture guide)
└── PRODUCT_REQUIREMENTS_DOCUMENT.md (this file)
```

---

### C. Glossary

**Clean Architecture**: Software design pattern separating concerns into layers (presentation, use cases, domain, state) with dependency rules flowing inward.

**CoreData**: Apple's object graph and persistence framework for iOS/macOS.

**CloudKit**: Apple's cloud database and storage service for iOS/macOS apps.

**Domain Event**: An event representing something that happened in the domain (e.g., TaskCompleted).

**Domain Model**: Pure business logic models with no framework dependencies (e.g., Task, Project structs).

**Entity**: CoreData managed object (e.g., NTask, NProject).

**Mapper**: Class responsible for converting between CoreData entities and domain models.

**Repository**: Data access layer implementing CRUD operations for a specific entity.

**Use Case**: Single business workflow or operation (e.g., CreateTaskUseCase).

**UUID**: Universally Unique Identifier, used for stable cross-device references.

**Gamification**: Applying game-design elements (points, levels, achievements) to non-game contexts.

**Streak**: Consecutive days with task completions.

**Habit**: Recurring task with automatic scheduling (e.g., daily exercise).

**Inbox**: Default project with fixed UUID `00000000-0000-0000-0000-000000000001` for unassigned tasks.

---

### D. References

**Internal Documentation**:
- `README.md` - Project overview and setup
- `claude.md` - Clean Architecture guide for developers
- `UUID_IMPLEMENTATION_SUMMARY.md` - UUID migration technical details
- `E2E_TESTING_QUICK_START.md` - UI testing guide
- `ACCESSIBILITY_IDENTIFIERS_GUIDE.md` - Accessibility setup

**External Resources**:
- [Clean Architecture (Uncle Bob)](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)
- [Apple CoreData Documentation](https://developer.apple.com/documentation/coredata)
- [Apple CloudKit Documentation](https://developer.apple.com/documentation/cloudkit)
- [Microsoft FluentUI iOS](https://github.com/microsoft/fluentui-apple)
- [Material Components iOS](https://github.com/material-components/material-components-ios)

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | Jan 10, 2026 | Claude (AI Assistant) | Initial comprehensive PRD based on codebase analysis |
| 2.0 | Jan 10, 2026 | Claude (AI Assistant) | Added technical architecture, use cases, roadmap, and technical debt sections |

---

**End of Product Requirements Document**
