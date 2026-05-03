# Calendar + Timeline Product Feature

Tasker uses calendar data as execution context, not as a competing calendar product.

The Home timeline is the user's calm command center for the day. It turns tasks, meetings, routines, busy blocks, open gaps, and EVA guidance into one visual day narrative so the user can understand the day without mentally stitching together a calendar, task list, and planner.

The purpose of the feature is to answer the user's most important day questions quickly:

1. What is happening now?
2. What is coming next?
3. Which parts of the day are busy?
4. Where is there usable free time?
5. What needs attention?
6. What can safely be ignored or deferred?
7. What should I ask Eva to help repair or sequence?

## Core Promise

Tasker observes calendar reality and reflects it back in a compact, read-only form that supports orientation, prioritization, and action.

That means:

- Users can connect calendars and choose which ones matter
- Tasker can show schedule context without editing external events
- The Home screen can surface the next meeting and free time
- Task detail can surface fit hints derived from the live calendar picture
- The timeline can remain task-first while still respecting schedule pressure
- Sparse days become planning opportunities instead of blank screens
- EVA can eventually use the timeline as the foundation for conflict detection, overload repair, focus-time protection, task deferral, and free-gap planning assistance
- Chat can use the same day picture as the visible timeline, so Eva's Chief of Staff guidance is grounded in what the user can see

## Primary Surfaces

### Home

Home is the main calendar entry point and the primary single-glanceable day surface.

The Home schedule module should communicate:

- Next meeting
- Busy blocks ahead
- Free-until state when the user is currently unoccupied
- Calendar connection status and recovery when access is missing or limited

The module should stay compact and glanceable. It is a context rail, not a dense calendar view.

Home should also provide a clear handoff into the broader day-management loop:

- Tap a schedule summary to inspect the relevant schedule detail.
- Tap a task-fit hint to understand why a task fits, feels tight, or conflicts.
- Tap an overloaded-window prompt to ask Eva for repair options.
- Tap an open-gap prompt to create a task, choose a fitting task, or ask Eva to help use or protect the gap.

### Task Detail

Task detail uses calendar context to answer whether the current task is a good fit for the day.

The task-fit hint should reflect:

- The current window of availability
- Nearby busy blocks
- Whether the task is a fit, tight fit, or conflict

The feature is advisory. It does not reschedule anything on its own.

Task detail should never shame the user for conflict. If a task does not fit, the useful next moves are to defer, shrink, break down, move a reminder, choose a smaller task, or ask Eva for options.

### Calendar Schedule

Calendar schedule surfaces expose read-only commitment context outside the compressed Home module.

Day schedule should show:

- Current block
- Next meeting
- Busy blocks
- Open gaps
- All-day context when relevant
- Task-fit opportunities when Tasker can infer a useful match

Week schedule should show:

- Which days are overloaded
- Which days have usable planning windows
- Deadline or commitment clusters
- Recurring rhythm that affects task planning

Month schedule should show:

- High-level commitment density
- Important upcoming anchors
- Sparse stretches that may support planning

These views should stay schedule-aware rather than calendar-complete. They can help the user understand commitment shape, but they should not become an event-management surface.

### Timeline

The timeline is Tasker's task chronology, visual day narrative, and intelligent planning surface.

It should remain task-first while still using calendar context to:

- Explain current time pressure
- Distinguish open windows from blocked windows
- Inform timeline-adjacent planning surfaces
- Keep the user oriented around next action, not around a giant calendar grid

Every element in the timeline has a role:

- Fixed meetings render as anchored blocks because they are hard commitments.
- Tasks render as lighter markers or cards because they are flexible, actionable work.
- Routines such as morning and evening rituals give the day gentle structure.
- Busy overlapping periods render as flocks so complexity is visible but not chaotic.
- Large empty gaps are compressed and labeled so open time becomes understandable and usable.
- Sparse or empty days offer planning, task creation, or EVA-assisted scheduling affordances.

The timeline should also expose day-management affordances where they naturally belong:

- Overloaded windows can offer `Ask Eva`, `Defer flexible task`, or `Break down task` actions.
- Open gaps can offer `Start fitting task`, `Create task`, `Plan this gap`, or `Leave open` actions.
- Interrupted or slipped tasks can offer `Resume`, `Move`, `Shrink`, or `Ask Eva to repair`.
- End-of-day areas can offer review, carry-over, and cleanup actions.

Eva guidance should be contextual rather than ambient. A suggestion belongs in the timeline only when it is tied to a visible constraint or opportunity and gives the user a concrete next action.

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
- As a user, I can inspect a day, week, or month schedule glance without worrying that Tasker will edit my calendar.
- As a user, I can use the timeline without feeling like Tasker has turned into another calendar grid app.
- As a user, I can open Tasker, look at the timeline for two seconds, and feel grounded about what matters now.
- As a user, I can see whether the day is packed, flexible, or sparse without decoding a crowded interface.
- As a user, I can use large open gaps as planning opportunities instead of seeing them as empty space.
- As a user, I can ask Eva what to do next and get an answer that reflects my visible timeline.
- As a user, I can ask Eva to repair an overloaded block and review any proposed Tasker task changes before they are applied.
- As a user, I can see when Eva is working from partial schedule context, such as missing calendar permission or no selected calendars.

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
- EVA guidance should appear only when it helps the user act, repair, defer, or protect focus

The timeline chapter in this package exists to keep that distinction explicit.

## Eva Relationship

Eva is the conversational layer on top of the same day context.

Eva can help with:

- Explaining the day in plain language
- Choosing the next task
- Finding a task that fits a free gap
- Repairing overloaded windows
- Suggesting deferrals for flexible work
- Protecting a focus window
- Recovering after missed tasks or broken routines
- Preparing an end-of-day carry-over plan

Eva cannot, in this package:

- Edit external calendar events
- RSVP to meetings
- Silently reschedule Tasker tasks
- Auto-log habit outcomes
- Hide uncertainty caused by missing schedule context

If Eva proposes Tasker-owned changes, the proposal must remain reviewable and explicitly confirmed through the assistant action pipeline.
