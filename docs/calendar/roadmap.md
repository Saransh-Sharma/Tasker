# Calendar + Timeline Roadmap

## Near Term

- Keep the calendar contract canonical in this package and remove duplicate explanations elsewhere
- Tighten permission copy and recovery states for denied, restricted, and write-only access
- Keep multi-calendar selection and local persistence behavior clearly documented
- Align the Home schedule module terminology with the actual runtime snapshot types
- Clarify how next-meeting, free-until, and busy-block context feeds Home and task-fit hints
- Make the timeline wording explicit so it stays task-first rather than grid-first

## Mid Term

- Add calendar-set style grouping or presets if they improve selection ergonomics without complicating the current model
- Improve filter UX for declined, canceled, and all-day handling
- Polish schedule detail and glance surfaces for faster read-once comprehension
- Strengthen task-fit hints with clearer fit, tight, and conflict explanation copy
- Add clearer empty and error states across Home and schedule screens

## Long Term

- Consider widgets or Live Activities only if they remain read-only and reinforce execution context
- Consider broader planning-mode surfaces only if they do not collapse Tasker into a calendar-first app
- Expand timeline-adjacent context carefully, preserving the distinction between schedule context and task chronology

## Non-Goals

- Mutating external calendar events
- Building a full-featured calendar replacement
- Automatic rescheduling that overrides user intent
