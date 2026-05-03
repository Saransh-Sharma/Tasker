# Tasker Docs

This directory is the navigation hub for product, architecture, audit, and feature documentation in Tasker.

## Canonical References

- [Local EVA / LLM architecture](./architecture/LOCAL_LLM_EVA_ARCHITECTURE.md) - source of truth for local inference, chat routing, Chief of Staff day overview cards, planner proposals, apply/undo boundaries, and timeline-aware assistant context.
- [Assistant mascot persona placement guide](./design/EVA_MASCOT_PLACEMENT_GUIDE.md) - source of truth for selectable Chief of Staff personas, sprite resources, placement mapping, accessibility rules, and QA checklist.
- [Tasker V2 architecture guide](./architecture/TASKER_V2_ARCHITECTURE_GUIDE.md)
- [Habit UX audit](./audits/HABITS_IOS_UX_AUDIT_2026-04-17.md)

## Feature Packages

- [Habits feature docs](./habits/README.md)
- [Calendar + timeline docs](./calendar/README.md) - canonical Home/timeline product contract for the single-glanceable day command center, read-only calendar schedule context, timeline runtime, task-fit hints, timeline-aware Eva guidance, risks, and roadmap.

## Day Management Model

The timeline, calendar schedule feature, and Eva are one product system:

- Calendar schedule provides read-only reality: fixed commitments, busy periods, next meeting, free-until state, and selected-calendar scope.
- The Home timeline interprets that reality alongside tasks, habits, routines, completed work, and open gaps.
- Eva acts as the chat-first Chief of Staff over that day picture, helping the user understand, sequence, repair, defer, and protect focus without silently mutating tasks or external calendars.

When documenting this system, keep the split clear:

- Product behavior and user-facing schedule semantics belong in the calendar package.
- LLM, chat, prompt routing, context projection, day overview cards, proposal cards, and apply/undo trust mechanics belong in the Eva architecture document.
- Broad product priorities, success metrics, and acceptance criteria belong in the PRD.

## Working Rule

When a feature gets its own documentation package, keep the PRD, roadmap, and supporting notes linked to that package instead of duplicating the same contract in multiple places. Calendar, timeline, and Eva-assisted day management now follow that rule.
