# Calendar + Timeline

Tasker’s calendar layer is read-only schedule context that improves execution without turning Tasker into a full calendar app.

The system observes external calendar reality through EventKit, filters it locally, and uses the resulting context in three places:

- Home, where schedule reality is surfaced as next-meeting, free-until, and busy-block context
- Task detail, where task-fit hints help users decide whether a task belongs in the current window
- The timeline, where calendar context informs task chronology, gaps, and planning affordances

## Canonical Docs

- [Product feature](./product-feature.md)
- [Data model and runtime](./data-model-and-runtime.md)
- [Risk register](./risk-register.md)
- [Roadmap](./roadmap.md)

## Implementation Truth

The current implementation centers on these runtime surfaces:

- `CalendarIntegrationService`
- `TaskerCalendarSnapshot`
- `HomeCalendarSnapshot`
- `TaskerNextMeetingSummary`
- `TaskerTaskFitHintResult`
- `HomeViewModel`

Those types are the source of truth for how calendar data is fetched, filtered, cached, and projected into Home and schedule surfaces.

## Scope

In scope:

- Permission onboarding and recovery for calendar access
- Multi-calendar selection with local persistence
- Calendar event filtering for declined, canceled, all-day, and selected-source rules
- Next meeting, free-until, and busy-block projections
- Task-fit hints derived from calendar context
- Day, week, and month glance surfaces
- Refresh and invalidation behavior when EventKit changes
- Timeline presentation that uses calendar context but remains task-first

Out of scope:

- Creating, editing, or deleting calendar events
- Replacing Apple Calendar or other calendar clients
- Calendar scheduling automation that mutates external calendars

## Terminology

In Tasker, “timeline” means the task chronology and schedule context inside Tasker, not a full calendar grid.

Calendar data informs timeline decisions, but the timeline remains task-first.
