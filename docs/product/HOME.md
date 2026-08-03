# Adaptive Home and Daily Orientation

**Classification:** Canonical feature contract

**Root:** Home
**Related:** [Calendar + Timeline](../calendar/README.md), [Plan and Focus](./PLAN_AND_FOCUS.md), [Product UI/UX Guide](../design/LIFEBOARD_PRODUCT_UI_UX_GUIDE.md)

## Promise and user jobs

Home answers “What matters now?” without requiring the user to reconcile a task list, calendar, trackers, and assistant conversation manually.

Users come to Home to:

- understand the daypart, date, capacity, fixed commitments, and current focus;
- start or complete the next meaningful action;
- see a small set of honest health/care signals;
- capture an interruption before it is forgotten;
- repair overdue or overloaded work;
- enter the appropriate native detail without losing Home context.

## Entry points and hierarchy

Home is the default root. Widgets, notifications, deep links, Spotlight, EVA proposals, and typed feature routes may return to it with context.

The default reading order is:

1. Mode and customization controls.
2. Greeting, date, and day context.
3. Focus Now.
4. Honest daily signals.
5. Care or medication context.
6. Tasks and routines.
7. Calendar capacity and timeline.
8. Journal/reflection and progress summaries.

The layout may adapt or omit unavailable modules, but orientation, Focus Now, and authoritative signal state must not be displaced by decorative or low-priority cards.

## Screen and component behavior

### Greeting and atmosphere

The greeting is concise and time-aware. Daypart changes scenic atmosphere, never the meaning of system appearance. Scenic art remains background context with enough negative space for reading; it must not become a promotional banner or obscure controls.

### Focus Now

Focus Now is the dominant Home card. It shows one selected task or a truthful setup/empty state, one visible primary action, and a short explanation. Deeper reasoning routes to task detail or EVA. It must not compete visually with other large cards.

### Signals

Signals can include hydration, mood/energy, fasting, movement, or other enabled domains. Each signal distinguishes:

- recorded zero;
- no target or setup required;
- no permission;
- not yet recorded;
- stale projection;
- unavailable service;
- loading;
- current recorded value.

Signal color is secondary to its label, value, and accessibility description.

### Tasks and routines

Tasks use open rows with a minimum 44-point completion target, title-first hierarchy, one restrained metadata line, and an optional status chip. Routines/habits use compact tactile rows or rails and route to their canonical records. Completion uses the canonical mutation path and exposes the established feedback/receipt behavior.

The standard Home tasks card is a four-row preview (two rows in Low Energy mode) of open overdue deadlines followed by open tasks due today. When matching rows are hidden, the footer places **Show more** opposite **Add a task**. Show more expands the existing card in place—never into a nested scroll view—and exposes every matching task plus a compact date picker. Selecting another date shows open deadlines before that day followed by open tasks due on that day. **Show less** restores the compact preview and resets the card to today. Task detail, completion, and Undo continue through the canonical planning routes and receipt-backed mutation path.

### Timeline and capacity

The timeline combines LifeBoard work with read-only external calendar reality. Fixed events are never mutated from Home. Busy blocks, gaps, current time, and task placements remain distinguishable. Placement and repair actions route through Plan or a canonical mutation preview.

### Dashboard customization and Smart Slots

The Home layout is one ordered placement set. Modes influence context but do not create separate persisted dashboards. Editing is transactional: changes remain a draft until committed, Cancel restores the exact prior layout, and unsupported/unknown widgets survive migrations without appearing.

Smart Slots may recommend or place contextually useful content only within the documented schedule/freeze rules. Mandatory orientation content remains stable. Feedback actions—Hide Today, Suggest Less, Never, Keep—are persistent and must be respected.

### Universal Capture

Compact Home exposes a raised capture control in the floating chrome. Expanding it reveals enabled capture kinds with 44-point targets. Drag selection, tap selection, keyboard alternatives, VoiceOver labels, and draft recovery lead into the same capture router.

The adjacent persistent composer is Universal Input rather than a chat-only shortcut. It accepts typed or live SpeechAnalyzer-dictated language and can open Journal, Note, Task capture, today’s meetings, Day Plan, Weekly Planner, Day Rescue, or Overdue Rescue. Deterministic interpretations can appear while typing; semantic Foundation Models/MLX classification runs only after submission. Ambiguous results ask, low-confidence results fall through to Eva, and no classification auto-saves. The complete contract is [Universal Input and Speech](./UNIVERSAL_INPUT.md).

### Overdue Rescue

Overdue Rescue is a bounded decision deck for unresolved work. It can launch from Home and, where supported, a selected Plan day. Each card exposes Keep for the launch context, Move, Edit, and Delete with matching VoiceOver actions and visible alternatives to gestures.

Requirements:

- The launch context determines the decision anchor date and session identity.
- Keep must describe the actual target day and synchronize planning metadata only when launched from Plan.
- Move uses a visible resolved date; Edit preserves the current card/session.
- Delete requires confirmation where the task’s structure or history warrants it.
- Swipe prediction uses intent/velocity thresholds, supports cancellation spring-back, and never makes gestures the only path.
- Session progress and Undo are scoped to account, workspace, date, and launch purpose.
- A failed update stays on the card with recovery; it is not counted as resolved.

The canonical implementation is complete. `OverdueRescueLaunchCoordinator` owns
launch identity and presentation state; `RescueBatchApplier` owns validation,
apply, compensation, retry, and Undo. Seeded and contract tests cover normal and
Day Rescue launches, empty/failure/stale-task states, and receipt-preserving Undo.

## State matrix

| State | Home behavior | Primary recovery |
|---|---|---|
| Populated | Curated hierarchy with Focus Now, signals, tasks, and timeline | Act on the primary decision |
| Empty day | Preserve greeting and orientation; explain how to begin | Capture or plan |
| Loading | Geometry-matched skeletons replace pending modules | Continue using available modules |
| Stale | Show last known projection with freshness context | Refresh |
| Permission denied | Keep non-dependent Home content visible | Explain and open Settings |
| Offline | Keep local tasks/plans/capture working | Retry external projections later |
| Error | Localize failure to the affected module | Retry or open native detail |
| Overloaded | Reduce visible choices and surface recovery | Open Rescue or Plan repair |

## Visual and interaction rules

- Home uses warm scenic canvas and open space; content uses paper/clay.
- Only the dock, capture chrome, and shared composer use approved glass.
- Avoid card-on-card nesting and multiple equal-weight heroes.
- Completion, drag commit, and placement use named motion/haptic roles.
- Skeletons stop when authoritative state arrives and never overlay loaded content.
- Errors and denied states include text and action; color alone is insufficient.

## Platform behavior

- Compact iPhone: single reading column, floating dock, measured bottom clearance.
- Accessibility sizes: signals and actions stack or scroll; decoration yields before content.
- iPad: 8/12-column semantic grid, atomic edit controls, split navigation, preserved card identities.
- Catalyst: keyboard/pointer access to customization, capture, filters, and routing.

## Implementation and evidence

Primary anchors include `LifeOSFoundationShell`, `LifeBoardAppRouter`, Home provider/placement registries, `HomeRenderState`, the timeline presentation system, and Overdue Rescue views/view models. Evidence includes packing/restoration contracts, root-state fixtures, appearance captures, typed route journeys, and focused accessibility UI tests.

Primary retained flags include `lifeOSFoundationV1Enabled`,
`lifeOSUnifiedPresentationV2Enabled`, and `dashboardCustomizationV2Enabled`.
They default on in Debug and Release and remain disable-only, data-preserving
rollback paths. Adaptive Home is canonical and has no fallback or feature flag.

Provider composition, Smart Slot schedule/freeze, continuous packing,
restoration, native navigation, and Rescue are implemented. The final automated
checkpoint is 2,071 tests with 3 environment skips and zero failures, five
available build paths, and all eight guardrails. Signed-device performance and
hardware delivery observations remain external release evidence; see the
[Unified Completion Status](../life-os/LIFEBOARD_UNIFIED_COMPLETION_STATUS.md).
