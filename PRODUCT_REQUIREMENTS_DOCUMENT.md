# Tasker iOS - Product Requirements Document

**Version:** 4.1  
**Last Updated:** February 20, 2026  
**Platform:** iOS 16.0+  
**Status:** Active Product Direction

## Vision And Positioning

Tasker is a todo and life-management product designed for people who struggle with consistency, attention switching, and execution friction. The product position is practical: help users choose what matters now, start quickly, recover from interruptions, and sustain momentum over time.

Tasker is not positioned as a clinical treatment product. It is a productivity system designed to support ADHD-relevant day-to-day execution needs with respectful, non-judgmental UX.

## Target Users And Jobs-To-Be-Done

### Primary Segment: Adults Managing High Context Load
- Users balancing work, life admin, habits, and personal projects.
- Users who repeatedly lose momentum when contexts change.

Primary jobs-to-be-done:
- "Help me decide what to do first without overthinking."
- "Help me restart quickly after I drop off."
- "Help me keep my commitments visible without feeling overwhelmed."

### Secondary Segment: Students And Early-Career Builders
- Users with variable schedules and frequent deadline clustering.

Primary jobs-to-be-done:
- "Help me break down and sequence school/work tasks."
- "Help me avoid deadline panic from invisible backlog growth."

### Tertiary Segment: Habit-Oriented Self-Improvers
- Users focused on repeat behaviors and consistency loops.

Primary jobs-to-be-done:
- "Help me maintain streak continuity without perfection pressure."
- "Help me recover quickly from missed days."

## ADHD Design Framework

### 1. Reduce Cognitive Load
Product intent:
- Limit simultaneous decisions.
- Favor clear defaults over setup burden.
- Keep prioritization visible and lightweight.

Success indicators:
- Lower abandonment during planning.
- Higher ratio of started tasks vs created tasks.

### 2. Minimize Activation Friction
Product intent:
- Make task capture and task-start near-immediate.
- Reduce taps/time between intent and execution.

Success indicators:
- Faster time-to-first-task per session.
- Higher same-session completion rate.

### 3. Preserve Momentum After Interruption
Product intent:
- Support return-to-context after distraction or delay.
- Keep state legible so users can resume without rebuilding mental context.

Success indicators:
- Increased re-engagement after inactivity.
- Reduced carry-over of stale overdue tasks.

### 4. Reward Meaningful Progress
Product intent:
- Reinforce value-driven completion (not only quantity).
- Encourage consistency while avoiding shame loops.

Success indicators:
- Increased completion of high-priority tasks.
- Higher streak resilience after misses.

### 5. Prevent Overwhelm Through Scoped Focus
Product intent:
- Narrow visible work to actionable slices.
- Support quick filtering by context/energy/time.

Success indicators:
- Lower backlog anxiety feedback.
- Higher daily focus-list completion.

## Core Experience Pillars

### Pillar A: Capture And Clarify
- Fast task capture with minimal required fields.
- Optional structure when users have bandwidth (project/section/tag/details).

### Pillar B: Focus And Sequence
- Home views that scope attention to "now" and near-term windows.
- Practical filtering for context, energy, priority, and due windows.

### Pillar C: Plan Across Life Areas
- Organize work by life areas and projects to reduce undifferentiated backlog stress.
- Preserve clear inbox/default flow when categorization is deferred.

### Pillar D: Execute Reliably
- Ensure reminders and scheduling support execution instead of noise.
- Provide recoverable behavior when tasks shift, recur, or get deferred.

### Pillar E: Reflect And Reinforce
- Show progress trends and completion quality over time.
- Use gamification as reinforcement, not coercion.

### Pillar F: Assist Intentionally
- Support optional assistant-mediated planning actions.
- Keep user confirmation and reversibility as core trust mechanics.

## Non-Goals For This PRD Cycle

- No clinical/diagnostic positioning.
- No "engagement at all costs" notification strategy.
- No automation path that bypasses explicit user control for impactful changes.
- No roadmap commitments to platforms outside iOS in this document.

## Current Product Constraints (Release 4.1)

- The shipped app runtime is V3-only.
- Upgrade behavior for in-flight internal builds follows a destructive reset cutover policy.
- Cloud sync cutover is container-isolation based (no user-visible record-by-record migration promises in this release).
- Assistant apply/undo remains explicitly gated and must preserve confirmation + undo trust boundaries.

## Success Metrics

### Activation Metrics
- New-user first-task creation rate.
- Time-to-first-completion within onboarding window.

### Daily Focus Metrics
- Daily focused-task completion rate.
- Same-session create-to-complete conversion.

### Carry-Over And Backlog Health
- Overdue carry-over ratio day over day.
- Percentage of users with shrinking vs growing stale backlog.

### Reminder Response Quality
- Reminder acknowledgment rate.
- Reminder action conversion rate (complete/reschedule within defined window).
- Reminder dismissal-without-action rate.

### Retention And Streak Resilience
- D7/D30 retention.
- Streak continuation after one missed day.
- Return-to-active rate after inactivity windows.

## Metric Interpretation Guardrails

- Favor sustained improvement over single-day spikes.
- Review metric movement alongside user-reported overwhelm/friction feedback.
- Treat reminder and assistant metrics as quality metrics first, volume metrics second.
- Do not ship growth tactics that improve short-term activity while degrading user trust.

## Risks And Ethics

### Non-Clinical Framing
- Product language must avoid medical claims.
- Product should not imply diagnosis or treatment.

### Anti-Manipulation Guardrails
- Rewards should not punish temporary disengagement.
- Streak mechanics should support recovery paths and avoid all-or-nothing pressure.

### Privacy And Trust Expectations
- Users should clearly understand where data is stored/synced.
- AI/assistant interactions should preserve user control and explicit confirmation for impactful actions.

### Notification Responsibility
- Reminder volume and cadence should avoid overload.
- Reminder UX should optimize for helpfulness, not interruption maximization.

## Product Roadmap Themes

### Theme 1: Execution Reliability
- Improve confidence that plans become action with low friction.

### Theme 2: Adaptive Focus
- Better personalized focus scoping based on behavior patterns.

### Theme 3: Recovery Experience
- Faster and kinder re-entry after disrupted periods.

### Theme 4: Trustworthy Assistance
- Expand assistant usefulness while keeping confirmation, transparency, and undo safety.

### Theme 5: Insight That Drives Action
- Convert analytics into practical next-step guidance.

## Technical References

Technical implementation details are intentionally kept out of this PRD. Use the architecture docs:
- `docs/README.md`
- `docs/architecture/README.md`
- `docs/architecture/data-model-v2.md`
- `docs/architecture/clean-architecture-v2.md`
- `docs/architecture/usecases-v2.md`
- `docs/architecture/risk-register-v2.md`
- `docs/architecture/state-repositories-and-services-v2.md`
- `docs/architecture/domain-events-and-observability-v2.md`
- `docs/architecture/llm-assistant-stack-v2.md`
- `docs/architecture/v3-runtime-cutover-todo.md`
- `docs/operations/ci-release-and-guardrails.md`
- `docs/operations/developer-tooling-and-flowctl.md`

## Document History

- **v4.1 (February 20, 2026):** Added product constraints for V3 runtime cutover, non-goals, metric interpretation guardrails, and updated technical reference index.
- **v4.0 (February 18, 2026):** Product-only PRD with explicit ADHD framework, metrics model, ethics section, and architecture-doc handoff.
- **v3.0 (January 13, 2026):** Prior mixed product/technical PRD.
