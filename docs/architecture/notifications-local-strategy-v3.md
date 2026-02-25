# Local Notification Strategy (V3 Runtime)

**Last validated against code on 2026-02-24**

This document defines Tasker's local notification product strategy and technical implementation contracts for V3 runtime.

Primary source anchors:
- `To Do List/Services/LocalNotificationService.swift`
- `To Do List/Domain/Interfaces/NotificationServiceProtocol.swift`
- `To Do List/AppDelegate.swift`
- `To Do List/SceneDelegate.swift`
- `To Do List/ViewControllers/SettingsPageViewController.swift`
- `To Do List/ViewControllers/HomeViewController.swift`
- `To Do List/UseCases/Task/CompleteTaskDefinitionUseCase.swift`

## Product Goals

1. Improve follow-through for planned work with low-noise reminders.
2. Preserve user agency with actionable notifications (`Open`, `Snooze`, `Complete` where task-targeted).
3. Reinforce daily planning and reflection loops with two bounded summaries.
4. Prefer helpful relevance over volume; avoid duplicate or stale notifications.

## Notification Catalog (Shipped)

| Type | Trigger | Title | Body template | Actions | Tap destination |
| --- | --- | --- | --- | --- | --- |
| Task Reminder | Task has future `alertReminderTime` | `Task Reminder` | `"{taskTitle}" is due {relativeDueText}.` fallback `"{taskTitle}" is waiting for you.` | `Open`, `Complete`, `Snooze 15m` | Task detail when task ID exists |
| Due Soon Nudge | Open task due in next 120m, and no explicit reminder in that window | `Due Soon` | `"{taskTitle}" is due in {minutes}m.` with optional ` + {additionalCount} more due soon` | `Open`, `Complete`, `Snooze 15m` | Home Today |
| Overdue Nudge | Overdue tasks exist; schedule slots at 10:00 and 16:00 local | `Overdue Task` | `"{taskTitle}" is overdue by {days} day(s).` with optional ` + {additionalCount} more overdue` | `Open`, `Complete`, `Snooze 15m` | Home Today |
| Morning Plan | Daily local schedule | `Morning Plan` | If tasks: `{openCount} tasks today ({highCount} high priority, {overdueCount} overdue). Start with "{topTaskTitle}".` else fallback copy | `Open Today`, `Snooze 30m` | Daily Summary Modal (Morning Plan) |
| Nightly Retrospective | Daily local schedule | `Day Retrospective` | If completions: `Completed {completedCount}/{totalCount} tasks, earned {xp} XP. Biggest win: "{topCompletedTaskTitle}".` else fallback copy | `Open Done`, `Snooze 60m` | Daily Summary Modal (Nightly Retrospective) |

## Product Defaults and Decisions

- Local timezone is source of truth for schedule times.
- Morning default time: `08:00` local.
- Nightly default time: `21:00` local.
- Quiet hours are intentionally disabled in this release.
- `Complete` action is limited to task-targeted notifications.
- `homeToday(taskID:)` route changes quick view only; only `taskDetail(taskID:)` opens detail modal.
- Daily morning/nightly default tap uses `dailySummary(kind:dateStamp:)` and presents a summary modal with CTA actions.

## Preferences and Settings Contract

`TaskerNotificationPreferences` (UserDefaults-backed via `TaskerNotificationPreferencesStore`) controls:
- Task reminders enabled
- Due soon nudges enabled
- Overdue nudges enabled
- Morning agenda enabled + time
- Nightly retrospective enabled + time
- Quiet hours enabled flag (stored, not currently applied)

Settings UX contract:
- Show permission status: `Authorized`, `Denied`, `Not Determined`, `Provisional`, `Ephemeral`.
- If denied, surface "Open iOS Settings" path.
- Any settings change triggers schedule reconciliation.

## Runtime Wiring and Lifecycle

Runtime boot sequence (`AppDelegate`):
1. Register local notification categories.
2. Set `UNUserNotificationCenter` delegate.
3. Fetch permission status.
4. Request permission if `.notDetermined`.
5. Reconcile notification schedules when authorized/provisional/ephemeral.

Reconciliation triggers:
- App lifecycle (`didBecomeActive`, foreground/background transitions, scene transitions).
- Task mutation notifications (`TaskCreated`, `TaskUpdated`, `TaskDeleted`, `TaskCompletionChanged`, `HomeTaskMutationEvent`).
- Notification settings updates.

## IDs and Routing

ID scheme:
- `task.reminder.{taskID}`
- `task.dueSoon.{taskID}.{yyyyMMdd}`
- `task.overdue.{taskID}.{yyyyMMdd}.am|pm`
- `daily.morning.{yyyyMMdd}`
- `daily.nightly.{yyyyMMdd}`
- `task.snooze.{sourceRequestID}.{unixTimestamp}`

Route payloads:
- `home_today` / `home_today:{taskID}`
- `home_done`
- `task_detail:{taskID}`
- `daily_summary:{morning|nightly}` / `daily_summary:{morning|nightly}:{yyyyMMdd}`

## Scheduling and Reconciliation Algorithm

`TaskNotificationOrchestrator` computes desired requests and reconciles against pending requests:
1. Build desired request set from tasks + preferences.
2. Read pending local requests.
3. Split pending into:
- `stale`: managed ID no longer desired
- `changed`: same ID but fingerprint changed
- `unchanged`: same ID and fingerprint match
4. Cancel `stale + changed`.
5. Schedule `added + changed`.
6. Keep unchanged requests untouched.

Fingerprint fields:
- kind
- fire date (second precision)
- title
- body
- category identifier
- route payload
- task ID

Managed prefixes:
- `task.reminder.`
- `task.dueSoon.`
- `task.overdue.`
- `task.snooze.`
- `daily.morning.`
- `daily.nightly.`

## Action Handling Contract

`TaskerNotificationActionHandler` routes actions and guarantees completion callback safety:
- Completion callback is invoked once per action path.
- Defensive timeout ensures callback is never orphaned.
- `Complete` action updates task completion through `UseCaseCoordinator.completeTaskDefinition`.
- Task-bound cancellation removes pending reminder/due/overdue/snooze entries for that task.
- Snooze actions create one-shot local notifications at +15m/+30m/+60m depending on category/action.

## Horizon Strategy

- Due soon: one primary nudge per reconcile window (+ additional count in body).
- Overdue: remaining slots for today plus tomorrow slots.
- Daily summaries: rolling future horizon of 3 days (`today + next 2 days`), filtered to future fire dates.

## Observability

Structured log events:
- `notification_lifecycle` (scheduled)
- `notification_reconciled`
- `notification_opened`
- `notification_completed_task`
- `notification_snoozed`
- `notification_delivered`

These logs support acknowledgment/conversion quality tracking.

## Known Constraints

- Local notification delivery/presentation remains OS-governed.
- Permission-denied state suppresses effective delivery even if schedules exist.
- Daily content is a snapshot at reconcile time and refreshes on mutation/lifecycle triggers.
