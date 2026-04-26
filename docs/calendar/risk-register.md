# Calendar + Timeline Risk Register

## Permission Risk

Risk:
The user denies, restricts, or revokes access after initial setup.

Impact:
Home loses schedule context and task-fit hints become unavailable.

Mitigation:
- Keep denied, restricted, and write-only states explicit
- Route to settings when recovery is possible
- Preserve a useful non-calendar experience

## Freshness Risk

Risk:
EventKit changes after Tasker has already cached a snapshot.

Impact:
The user sees stale next-meeting or busy-block context.

Mitigation:
- Refresh on store change notifications
- Refresh on selected-day changes
- Invalidate derived caches when source events change

## Timezone and Day-Boundary Risk

Risk:
Calendar events cross midnight, daylight saving changes, or device timezone changes.

Impact:
Busy windows and next-meeting calculations can drift.

Mitigation:
- Derive day windows from `Calendar.current`
- Normalize range boundaries before projection
- Keep day-specific rendering and current-time logic explicit

## Empty-State Risk

Risk:
The user selects no calendars or selected calendars contain no relevant events.

Impact:
The feature looks broken when it is actually empty by choice.

Mitigation:
- Distinguish permission problems from empty data
- Distinguish empty selection from empty time range
- Use clear copy for no calendars selected, no events, and all-day-only days

## Over-Calendarization Risk

Risk:
The timeline starts behaving like a calendar app grid.

Impact:
Tasker loses its execution-first identity.

Mitigation:
- Keep the timeline task-first
- Make calendar data advisory rather than dominant
- Avoid introducing write semantics or grid-first navigation

## Scope Drift Risk

Risk:
Widgets, live activities, or broader scheduling automation get treated as required for v1.

Impact:
The feature becomes too broad to ship and maintain cleanly.

Mitigation:
- Keep those items in later roadmap phases only
- Require read-only behavior to remain intact
- Gate expansions behind clear product justification
