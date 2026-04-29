# Calendar + Timeline Data Model and Runtime

This document describes the implementation-facing contract for calendar sync and the schedule context it produces.

## Runtime Flow

The current flow is:

1. `CalendarIntegrationService` asks the provider for authorization state, calendars, and events
2. Selected calendar IDs are persisted locally through workspace preferences
3. EventKit changes trigger a debounced refresh
4. Raw calendar snapshots are projected into Home and schedule-specific view state
5. Home and task detail consume those projections for next-meeting, free-until, and fit hints

The implementation is read-only from Tasker's point of view.

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
- `TimelinePhoneRenderModel`
- `TimelineFlockModel`
- `TimelineCanvasLayoutPlan`

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

This is the main "what's next" signal for Home.

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

Timeline models exist to support a readable interpretation of the user's day. They should preserve enough time truth for orientation while prioritizing glanceability, action, and cognitive load reduction on a mobile screen.

The timeline should:

- Keep tasks as the primary chronology
- Use schedule context to inform gaps and current pressure
- Preserve read-only separation from external calendar edits
- Avoid inventing write semantics for calendar events
- Distinguish anchored commitments, flexible tasks, routines, busy flocks, and usable free gaps in the presentation layer

If timeline surfaces need to present calendar-derived context, they should consume the same resolved state that Home does rather than inferring a separate interpretation.

### Phone Render Model

The phone timeline uses a display-model layer on top of the lower-level time-block grouping:

- `TimelinePhoneRenderModel.normal(item)` represents one readable task or calendar event card.
- `TimelinePhoneRenderModel.flock(model)` represents an overlapping or chained busy period rendered as stacked rows.
- Lower-level `TimelineTimeBlock` overlap fields, including overlap depth and lane placements, can remain available for deterministic grouping, tests, and non-phone renderers.
- iPhone rendering must not use horizontal overlap lanes.

`TimelineFlockModel` is the phone-facing busy-period summary. It owns:

- chronological row ordering
- compact title formatting
- density mode selection
- active-now row detection
- extreme-density row prioritization
- summary-row behavior when all items cannot remain readable

The render model should protect the product goal of a calm single-glance day surface. Dense inputs should compress into readable summaries before the timeline becomes a noisy stack of equal-weight cards.

### Phone Layout Metrics

The expanded phone timeline should reserve roughly:

- `60pt` time gutter
- `72pt` spine x-position
- `90pt` content start

Time labels should use monospaced digits, one line, and a minimum scale factor so labels such as `12:30 PM` and `10:00 PM` remain readable in the reduced gutter.

### Visual Positioning

Readable phone layout tracks both true time placement and final rendered placement:

- `temporalY` is the actual time-based position.
- `visualY` is the final position after readability collision handling.
- `visualHeight` is the rendered block height.
- `wasVisuallyShifted` records when a block moved away from its exact time position.

The collision pass may push later blocks down to avoid visual overlap, but the shift is bounded. If an exact time-scaled view would become unreadable, the flock should become denser or summarized rather than pushing the entire day indefinitely downward.

### Current Time and Safe Areas

The now marker should orient without damaging readability:

- The dot and label render above content.
- The horizontal rule is subtle, behind content, and should not cut through flock text.
- If the now label collides with an hour label, prefer the now label.
- If now is inside a flock, highlight the active row inside the flock.

Timeline content must include bottom padding for the bottom navigation, floating action button, and additional breathing room so the last block does not sit under Home chrome.
