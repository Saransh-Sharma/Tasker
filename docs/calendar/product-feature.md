# Calendar + Timeline Product Feature

Tasker uses calendar data as execution context, not as a competing calendar product.

The purpose of the feature is to answer three questions quickly:

1. What is happening next?
2. How much time is actually free?
3. Can this task fit in the window that remains?

## Core Promise

Tasker observes calendar reality and reflects it back in a compact, read-only form.

That means:

- Users can connect calendars and choose which ones matter
- Tasker can show schedule context without editing external events
- The Home screen can surface the next meeting and free time
- Task detail can surface fit hints derived from the live calendar picture
- The timeline can remain task-first while still respecting schedule pressure

## Primary Surfaces

### Home

Home is the main calendar entry point.

The Home schedule module should communicate:

- Next meeting
- Busy blocks ahead
- Free-until state when the user is currently unoccupied
- Calendar connection status and recovery when access is missing or limited

The module should stay compact and glanceable. It is a context rail, not a dense calendar view.

### Task Detail

Task detail uses calendar context to answer whether the current task is a good fit for the day.

The task-fit hint should reflect:

- The current window of availability
- Nearby busy blocks
- Whether the task is a fit, tight fit, or conflict

The feature is advisory. It does not reschedule anything on its own.

### Timeline

The timeline is Tasker’s task chronology and schedule-aware planning view.

It should remain task-first while still using calendar context to:

- Explain current time pressure
- Distinguish open windows from blocked windows
- Inform timeline-adjacent planning surfaces
- Keep the user oriented around next action, not around a giant calendar grid

On iPhone, the timeline should optimize for glanceability rather than calendar fidelity:

- The time spine sits far enough left to give titles meaningful horizontal room.
- Single tasks and calendar events use one title-first card style with a small glyph, readable title, and always-visible compact time.
- Calendar source labels, all-caps category labels, large icon bubbles, and external completion rails stay out of compact phone cards.
- Overlapping regions render as flocks: stacked, chronological rows inside one busy-period container.
- Flocks do not use multiple horizontal lanes on iPhone.
- Small and medium flocks show all visible rows; dense flocks stay compact; extreme flocks show relevance-prioritized rows plus a summary action when all items cannot remain readable.
- If current time falls inside a flock, the active row gets a subtle now treatment rather than a red rule cutting through the content.
- Accessibility text sizes switch to agenda-style fallback instead of forcing dense timeline geometry to absorb large text.

## User Stories

- As a user, I can allow read-only calendar access so Tasker can understand my day.
- As a user, I can select which calendars matter to my execution context.
- As a user, I can see what meeting is coming next without opening a calendar app.
- As a user, I can see when I am free until, so I can choose a task that fits.
- As a user, I can open task detail and understand whether a task is likely to fit the current day.
- As a user, I can use the timeline without feeling like Tasker has turned into another calendar grid app.

## Calendar States

The feature should explicitly handle:

- Not determined
- Permission granted
- Permission denied
- Permission restricted
- Write-only access, where reading schedule context is unavailable
- No calendars selected
- Empty event range
- All-day only days

## Event Handling Rules

- Declined events can be hidden or included according to user preference
- Canceled events can be hidden or included according to user preference
- All-day events should not overwhelm the busy-block view
- Selected calendars define the execution context
- Read-only subscribed calendars should remain visible when they are selected

## Timeline Relationship

Calendar context should improve the timeline in a few specific ways:

- Completed work stays visible in chronology
- Gaps can become intentional planning windows
- Current time pressure can be expressed without a giant now marker
- Calendar events can inform fit and context, but they do not replace task chronology
- Overlapping items should communicate "this period is busy" before exposing exact calendar geometry

The timeline chapter in this package exists to keep that distinction explicit.
