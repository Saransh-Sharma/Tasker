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

## Dense Timeline Readability Risk

Risk:
Busy calendars and scheduled tasks create overlapping regions that are technically accurate but unreadable on iPhone.

Impact:
The Home timeline looks noisy, titles truncate into meaningless fragments, and users cannot quickly understand what is happening now, what is next, or which windows are overloaded.

Mitigation:
- Render iPhone overlaps as stacked flocks instead of horizontal lanes
- Use compact, title-first single-item cards
- Compress noisy titles before truncation
- Keep extreme-density flocks relevance-prioritized rather than purely exhaustive
- Treat readability and orientation as higher priority than showing every item with equal visual weight

## Sparse Timeline Abandonment Risk

Risk:
Sparse or empty days render as blank space with little planning guidance.

Impact:
Open time feels like an abandoned screen instead of a useful opportunity, and users may leave Tasker to plan elsewhere.

Mitigation:
- Compress long gaps into labeled opportunity windows
- Offer lightweight task creation or planning affordances in open windows
- Keep empty states explicit and useful without implying a calendar failure
- Allow EVA-assisted scheduling prompts where available, framed as optional help

## EVA Guidance Noise Risk

Risk:
EVA suggestions appear too often, compete with timeline content, or imply automatic scheduling authority.

Impact:
The single-glance day surface becomes noisy, and users may lose trust in the assistant or the read-only calendar boundary.

Mitigation:
- Surface EVA guidance only when it helps the user act, repair, defer, or protect focus
- Keep assistant-driven changes behind proposal, confirmation, and undo boundaries
- Avoid persistent advice chrome that distracts from current and next actions
- Clearly separate future EVA planning direction from currently implemented workflows

## Visual Time Distortion Risk

Risk:
The collision pass moves blocks away from their exact time-scaled position to preserve readability.

Impact:
The timeline can imply more free time or less free time than actually exists if visual shifting is unbounded.

Mitigation:
- Track `temporalY` and `visualY` separately
- Mark shifted blocks with `wasVisuallyShifted`
- Cap visual shifting and compact or summarize dense flocks before the whole day drifts downward

## Compact Interaction Risk

Risk:
Dense flock rows become visually compact enough that they are hard to tap or inaccessible with larger text.

Impact:
Users can see a busy-period summary but cannot reliably open or act on individual rows.

Mitigation:
- Preserve an effective `44pt` row tap target
- Keep time visible before optional metadata
- Use agenda fallback at accessibility text sizes
- Keep completion state subtle but readable inside compact rows

## Scope Drift Risk

Risk:
Widgets, live activities, or broader scheduling automation get treated as required for v1.

Impact:
The feature becomes too broad to ship and maintain cleanly.

Mitigation:
- Keep those items in later roadmap phases only
- Require read-only behavior to remain intact
- Gate expansions behind clear product justification
