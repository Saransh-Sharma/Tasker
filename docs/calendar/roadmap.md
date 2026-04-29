# Calendar + Timeline Roadmap

## Near Term

- Keep the calendar contract canonical in this package and remove duplicate explanations elsewhere
- Tighten permission copy and recovery states for denied, restricted, and write-only access
- Keep multi-calendar selection and local persistence behavior clearly documented
- Align the Home schedule module terminology with the actual runtime snapshot types
- Clarify how next-meeting, free-until, and busy-block context feeds Home and task-fit hints
- Add visual snapshot coverage for single cards, small flocks, dense flocks, extreme flocks, now-inside-flock, smallest iPhone width, large Dynamic Type, and bottom navigation overlap
- Polish the detail/open behavior for extreme flock summary rows

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
- Evolve EVA into a quiet day-management layer on top of the timeline, with conflict detection, overloaded-window repair, focus-time protection, task deferral, and free-gap planning assistance
- Keep EVA timeline guidance optional, reviewable, and oriented toward the next useful action rather than persistent advice noise

## Non-Goals

- Mutating external calendar events
- Building a full-featured calendar replacement
- Automatic rescheduling that overrides user intent
