# Calendar + Timeline

Tasker's calendar layer is read-only schedule context that improves execution without turning Tasker into a full calendar app.

The Home timeline is the product's single-glanceable day command center: a calm visual day narrative where tasks, fixed calendar commitments, routines, busy periods, open gaps, and EVA guidance come together as one readable planning surface. It should help users understand what matters in the day right now without forcing them to switch between a calendar, task list, and planner.

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

## Mobile Timeline Contract

The iPhone timeline is a readable mobile day planner, not a miniature calendar grid.

Its job is to interpret the shape of the day, not reproduce every schedule detail with equal weight. Fixed commitments should feel anchored, tasks should feel flexible and actionable, busy overlapping windows should collapse into readable flocks, and open gaps should be labeled as usable opportunity.

Phone rendering follows these rules:

- Single tasks and calendar events render as compact, title-first timeline cards.
- Overlapping items render as stacked flocks, which are readable busy-period summaries anchored to the correct time window.
- iPhone never renders horizontal overlap lanes, even when lower-level layout data still tracks overlap depth or lane placements for tests, layout math, or future larger-screen renderers.
- Dense flocks prioritize recognizable titles, current/next relevance, and tap accessibility over exact internal calendar geometry.

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

In Tasker, "timeline" means the task chronology and schedule context inside Tasker, not a full calendar grid.

Calendar data informs timeline decisions, but the timeline remains task-first.
