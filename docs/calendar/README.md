# Calendar + Timeline

LifeBoard's calendar layer is read-only schedule context that improves execution without turning LifeBoard into a full calendar app.

The Home timeline is the product's single-glanceable day command center: a calm visual day narrative where tasks, fixed calendar commitments, routines, busy periods, open gaps, and EVA guidance come together as one readable planning surface. It should help users understand what matters in the day right now without forcing them to switch between a calendar, task list, and planner.

The system observes external calendar reality through EventKit, filters it locally, and uses the resulting context in four places:

- Home, where schedule reality is surfaced as next-meeting, free-until, and busy-block context
- Task detail, where task-fit hints help users decide whether a task belongs in the current window
- Calendar schedule views, where day, week, and month glances help the user understand fixed commitments without editing them
- The timeline, where calendar context informs task chronology, gaps, and planning affordances

Eva may read the same projected day context as a Chief of Staff layer. That lets chat and timeline guidance explain what is next, what is overloaded, what can fit, and what could be deferred. Eva still cannot mutate external calendar events in this feature package; assistant changes remain limited to LifeBoard-owned tasks, habits, reminders, or planning metadata through explicit user action and the assistant action pipeline.

## Canonical Docs

- [Product feature](./product-feature.md)
- [Data model and runtime](./data-model-and-runtime.md)
- [Risk register](./risk-register.md)
- [Roadmap](./roadmap.md)

## Implementation Truth

The current implementation centers on these runtime surfaces:

- `CalendarIntegrationService`
- `LifeBoardCalendarSnapshot`
- `HomeCalendarSnapshot`
- `LifeBoardNextMeetingSummary`
- `LifeBoardTaskFitHintResult`
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

## Calendar Schedule Contract

The schedule feature provides orientation at three levels:

- Day schedule: fixed commitments, busy windows, open gaps, current block, next meeting, and task-fit context.
- Week schedule: day-level load, overloaded periods, open planning windows, deadline clusters, and recurring rhythm.
- Month schedule: high-level density, significant commitment clusters, and planning anchors.

All schedule surfaces are read-only in this package. They may deep-link to event detail, expose source/calendar metadata, or explain why a block is hidden or unavailable, but they must not create, edit, delete, or RSVP to external events.

Schedule surfaces should answer execution questions instead of competing with Apple Calendar:

- What is fixed today?
- When am I free?
- Where is the day overloaded?
- Which task fits the current window?
- What should be deferred, broken down, or left alone?
- What context should Eva use if I ask for help planning?

## Eva Context Contract

Timeline-aware Eva behavior depends on the calendar projection, not raw EventKit output.

When available, Eva can consume:

- Authorization and selected-calendar state
- Next meeting and in-progress meeting summaries
- Busy blocks and free-until windows
- Timeline flocks and overloaded periods
- Task-fit classifications
- Day, week, and month schedule summaries
- Degraded-context receipts for missing permissions, no selected calendars, empty ranges, timeouts, or partial projections

Eva can use that context to explain, sequence, repair, defer, and protect focus. It must keep guidance optional, sparse, and reviewable. When context is incomplete, Eva should say so or ask a clarifying question rather than guessing.

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
- Timeline-aware Eva guidance that consumes projected schedule context

Out of scope:

- Creating, editing, or deleting calendar events
- Replacing Apple Calendar or other calendar clients
- Calendar scheduling automation that mutates external calendars
- Assistant claims that imply external calendar authority

## Terminology

In LifeBoard, "timeline" means the task chronology and schedule context inside LifeBoard, not a full calendar grid.

Calendar data informs timeline decisions, but the timeline remains task-first.
