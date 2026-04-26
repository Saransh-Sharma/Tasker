# Calendar + Timeline Data Model and Runtime

This document describes the implementation-facing contract for calendar sync and the schedule context it produces.

## Runtime Flow

The current flow is:

1. `CalendarIntegrationService` asks the provider for authorization state, calendars, and events
2. Selected calendar IDs are persisted locally through workspace preferences
3. EventKit changes trigger a debounced refresh
4. Raw calendar snapshots are projected into Home and schedule-specific view state
5. Home and task detail consume those projections for next-meeting, free-until, and fit hints

The implementation is read-only from Tasker’s point of view.

## Core Types

The repo currently uses these primary types:

- `TaskerCalendarAuthorizationStatus`
- `TaskerCalendarEventAvailability`
- `TaskerCalendarEventParticipationStatus`
- `TaskerCalendarEventStatus`
- `TaskerCalendarSourceSnapshot`
- `TaskerCalendarEventSnapshot`
- `TaskerCalendarEventSlice`
- `TaskerCalendarBusyBlock`
- `TaskerNextMeetingSummary`
- `TaskerTaskFitHintResult`
- `TaskerCalendarDayAgenda`
- `TaskerCalendarSnapshot`
- `HomeCalendarModuleState`
- `HomeCalendarSnapshot`

These types are the canonical projection layer for the feature.

## Authorization Contract

Tasker must distinguish these states clearly:

- `notDetermined`
- `denied`
- `restricted`
- `writeOnly`
- `authorized`

Behavior:

- `notDetermined` should lead to a pre-permission explanation and a user-triggered request
- `denied` and `writeOnly` should route the user toward system settings for recovery
- `restricted` should be explained as system policy, not app failure
- `authorized` should unlock read-only schedule context

## Calendar Selection Contract

The selected calendar set is local and user-controlled.

Rules:

- Calendar IDs are normalized before persistence
- Empty selections are valid and should produce a clear empty state
- Hidden or missing calendars should be reconciled out of selection
- Read-only calendars can contribute to context if the user selects them

## Refresh and Invalidation

Calendar data must refresh when:

- The app first loads Home
- The selected day changes
- User preferences change
- EventKit posts a store-changed notification
- The user explicitly requests refresh

Refresh behavior should:

- Debounce store change notifications
- Avoid main-thread work for the provider fetch path
- Preserve a usable snapshot while refreshing
- Invalidate derived caches when the underlying calendar context changes

## Filtering Rules

The runtime already supports local filtering for:

- Selected calendar IDs
- Declined events
- Canceled events
- All-day events in agenda and busy-strip contexts

Derived projections should respect these rules consistently across Home, task-fit hints, and schedule screens.

## Derived Projections

### Next Meeting

`TaskerNextMeetingSummary` should capture:

- The event
- Whether it is already in progress
- Minutes until start for the next upcoming event

This is the main “what’s next” signal for Home.

### Busy Blocks

`TaskerCalendarBusyBlock` is the coarse schedule pressure model used for:

- Busy-strips
- Free-until hints
- Task-fit calculations

Busy blocks should be derived from the filtered event set, not from raw provider output.

### Task Fit Hints

`TaskerTaskFitHintResult` is advisory output for a task and current time.

It should classify a task into one of:

- fit
- tight
- conflict
- unknown

Unknown is the fallback when the app does not have enough context to evaluate fit safely.

## Timeline Contract

The timeline is not a calendar clone.

The timeline should:

- Keep tasks as the primary chronology
- Use schedule context to inform gaps and current pressure
- Preserve read-only separation from external calendar edits
- Avoid inventing write semantics for calendar events

If timeline surfaces need to present calendar-derived context, they should consume the same resolved state that Home does rather than inferring a separate interpretation.
