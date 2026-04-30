# Habit Risk Register

This register captures the product and UX risks that come with a streak-based habit system.

## Known Risks

### Empty-State Dead Ends

- Risk: users open the Habit Board or Habit Library and do not see a clear next action.
- Mitigation: add forward CTAs and direct create paths in empty states.

### Error-State Masking

- Risk: a load failure looks like an empty habit set.
- Mitigation: render explicit error state and retry affordances.

### Mutation Feedback Gaps

- Risk: a habit action fails silently after the user taps it.
- Mitigation: surface visible feedback on Home and habit surfaces.

### Accessibility Drift

- Risk: fixed typography or dense board layouts become hard to read at larger sizes.
- Mitigation: keep Dynamic Type behavior and readable labels aligned across row and board surfaces.

### Notification Fatigue

- Risk: gentle reminders become noisy if they are too frequent or too broad.
- Mitigation: keep reminders optional, configurable, and batchable by time window where useful.

### Overcommitment

- Risk: users create too many habits and then collapse.
- Mitigation: surface shrink, pause, and rescope suggestions when repeated friction appears.

### False Misses

- Risk: pause, archive, or cadence changes generate misleading missed days.
- Mitigation: preserve historical truth and rebuild projections carefully.

### Punitive Framing

- Risk: the UI turns streak loss into moral failure.
- Mitigation: use restart language, not blame language, and keep recovery visible.

## Ongoing Watch Items

- Habit-specific deep links
- Board loading and error UX
- History correction correctness
- Recovery analytics consistency
- Quiet-tracking behavior for lapse-only habits
