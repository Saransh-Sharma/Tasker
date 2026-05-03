# Calendar + Timeline Data Model and Runtime

This document describes the implementation-facing contract for calendar sync and the schedule context it produces.

## Runtime Flow

The current flow is:

1. `CalendarIntegrationService` asks the provider for authorization state, calendars, and events
2. Selected calendar IDs are persisted locally through workspace preferences
3. EventKit changes trigger a debounced refresh
4. Raw calendar snapshots are filtered into selected, readable, locally relevant schedule context
5. Schedule context is projected into Home, schedule-specific view state, task-fit hints, and timeline render models
6. Eva consumes the same bounded projections through LLM context receipts when a chat or planning turn needs schedule awareness

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

### Schedule Views

Day, week, and month schedule surfaces should be built from the filtered calendar snapshot and derived busy-block model, not raw EventKit records.

Day schedule projection should include:

- Current block
- Next meeting
- In-progress meeting
- Busy blocks
- Open gaps
- All-day event summaries
- Degraded or empty states

Week schedule projection should include:

- Per-day load summaries
- Overloaded periods
- Usable planning windows
- Deadline or commitment clusters where available from Tasker task metadata and selected calendar context

Month schedule projection should include:

- Density summaries
- Planning anchors
- Sparse stretches
- Degraded or no-data states

These projections are for orientation. They should not expose write commands for external calendar events.

### Eva Context Receipts

Eva should receive schedule context through bounded, explicit context receipts. The receipt should make it possible for chat and planner code to know what context was available, what was filtered out by policy or preference, and where the projection is partial.

A timeline-aware Eva context receipt should capture, when available:

- Selected day and current time basis
- Authorization status
- Selected-calendar state
- Next meeting and in-progress meeting summaries
- Busy blocks and free gaps
- Overloaded timeline flocks
- Task-fit classifications for relevant candidate tasks
- Empty, stale, timeout, or partial-projection status

The receipt should not include more raw event detail than the assistant turn needs. Title, time range, source, availability, and participation status are generally enough for day-management guidance; notes, attendees, URLs, and other sensitive event metadata should stay out unless a future explicitly scoped feature needs them.

Assistant outputs should use the receipt to distinguish:

- observed facts, such as "meeting from 2:00 PM to 2:30 PM"
- inferred advice, such as "this task looks tight before that meeting"
- missing-context caveats, such as "I cannot see your calendar right now"

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

Timeline render state should also be suitable for assistant grounding. The LLM layer should not separately recalculate the visible day from raw data because that can make Eva contradict the timeline. If Eva needs to reference overloaded windows, free gaps, or task-fit opportunities, it should use the same projection vocabulary that the timeline and Home modules use.

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
