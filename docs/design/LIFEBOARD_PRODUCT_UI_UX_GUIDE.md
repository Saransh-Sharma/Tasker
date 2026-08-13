# LifeBoard Product UI/UX Guide

**Classification:** Canonical behavioral design reference

**Audience:** Product, design, engineering, accessibility, and QA
**Capability status:** Current workspace
**Source authority:** DESIGN.md, Swift tokens/components, and current product chapters
**Last verified:** 2026-08-13

**Normative tokens:** [DESIGN.md](../../DESIGN.md)

**Feature behavior:** [Product handbook](../product/README.md)

**Broader release status:** [Unified Completion Status](../life-os/LIFEBOARD_UNIFIED_COMPLETION_STATUS.md)

## Experience principles

### Orient before asking

Every root first establishes location, current state, and the most relevant decision. Avoid opening with configuration, an undifferentiated feed, or a wall of metrics.

### One decision at a time

Each surface has one dominant action. Secondary actions remain discoverable without matching its visual weight. Recovery screens focus on the next safe step.

### Preserve momentum

Drafts, selected dates, filters, navigation stacks, session progress, and settled assistant output survive interruption where their underlying state is recoverable. Cancellation returns control; it does not punish the user by erasing context.

### Be honest about evidence

LifeBoard distinguishes facts, projections, suggestions, and generated interpretation. Zero, missing, stale, unavailable, denied, and error are different product states. Health, care, and reflection language remains descriptive and non-clinical.

### Make privacy visible

Protected content has explicit lock, consent, source, and external-surface behavior. Privacy is not represented only in legal copy or Settings.

## Global shell

### Compact iPhone

- Five equal root targets: Home, Plan, Track, Insights, EVA.
- Selected state uses a stable semantic well; target width does not animate.
- The raised capture control and persistent composer integrate with the same floating chrome.
- Every root measures and reserves chrome height so its final content remains reachable.
- Root reselection returns to that root; switching roots preserves inactive stacks.

### iPad and Catalyst

- Use sidebar/content and optional detail/inspector structure at regular width.
- Home scales semantic placements across 8/12 columns.
- Plan Week presents seven stable day destinations.
- Toolbar capture replaces oversized phone chrome where appropriate.
- Keyboard focus, pointer feedback, native menus, and window resizing are first-class behavior.

### Typed routing

Route by stable typed identity. Select a cross-root destination before appending its leaf. Missing/stale identities show an explanatory destination and never substitute a different record. Protected routes authenticate before mounting content.

## Visual hierarchy

### Canvas and atmosphere

The scenic warm-paper canvas supplies emotional context and daypart atmosphere. Functional system appearance remains independent. Keep high-frequency content on readable paper/clay and reserve clear negative space around greetings and large metrics.

### Surfaces

Use:

- open canvas for broad page grouping;
- embedded clay wells for local controls or subordinate values;
- reading/grouped paper for related content;
- raised clay for one decision or movable widget;
- floating clay/glass only for chrome and transient control;
- semantic destructive surfaces only during destructive work.

Avoid full-width cards around every section, nested cards, ornamental gradients behind body text, and deep shadows in scroll-heavy content.

### Typography

- Display: greeting or singular major metric.
- Screen title: route identity.
- Section title: one semantic group.
- Body: tasks, explanations, Journal, and settings detail.
- Metadata/caption: time, source, freshness, and supporting context.
- Monospaced metric: aligned duration/time/progress only.

Use Dynamic Type roles. At accessibility sizes, restructure layout before truncating. Decorative labels and imagery yield before tasks, care, schedule, evidence, Save, Cancel, Retry, or privacy controls.

### Icons and imagery

Use consistent SF Symbols or curated attributed assets. Icons reinforce a visible label or have an explicit accessibility label. Emoji is not interface iconography. Scenic and mascot art cannot carry required state or replace a control label.

## Interaction states

Every interactive component defines:

- resting;
- pressed/highlighted;
- selected;
- focused/keyboard;
- disabled with reason where useful;
- working;
- success/receipt;
- warning/error;
- destructive confirmation.

Disabled controls remain legible and do not rely on opacity alone when the reason is important. Working state freezes only the affected scope. Success appears only after canonical persistence or an explicit durable receipt.

### Mutation and commit behavior

Long-form or consequential mutations use one truthful commit lifecycle:

1. Keep the draft visible and editable until the user commits.
2. Disable duplicate submission while the canonical mutation is running.
3. Replace only the primary action with progress; do not freeze unrelated
   navigation or recovery controls.
4. Show success only after persistence or a domain receipt returns.
5. Keep the surface mounted on failure, preserve the draft, and show an inline
   message with Retry, Edit, or Cancel.
6. Dismiss only after confirmed success.

`LifeBoardCommitControl` is the standard full commit treatment. It consumes
`AsyncActionPhase<Receipt>` and must never be driven by an artificial delay.
One-tap logs, toggles, and reversible local selections remain immediate; they use
intent haptics and settled value updates instead of a full success morph.

Bottom safe-area commit actions are preferred for editors at accessibility text
sizes. Cancel, Close, and overflow actions may remain in the toolbar, but Save
must not be squeezed into a trailing navigation item when its label, progress,
failure, or retry state needs more room.

### Direct manipulation

Gesture-first surfaces must also provide visible and accessible controls.

- Directional decks use the shared resolver for threshold, axis dominance,
  predicted end translation, exit offset, and tilt.
- The visual surface follows the gesture; the domain mutation does not occur until
  the resolver commits a direction.
- Destructive work is never a casual flick.
- A gesture that opens review is not allowed to silently persist the reviewed
  object.
- VoiceOver actions and buttons use the same domain command as the gesture.

### Focused editing modes

When a screen enters a spatial editing mode, unrelated global chrome yields.
Home customization hides the dock and capture composer, freezes contextual
reordering, and presents one Cancel/Done action group. Cancel restores the
pre-edit transaction; Done persists the complete draft. Per-card edit controls
are subordinate to the selected card and do not become permanent badges in the
normal reading state.

## Loading, empty, and failure

### Loading

Use geometry-matched skeletons for stable content and a progress/status row for indefinite operations. Skeletons replace content and stop immediately when authoritative state arrives. Do not shimmer large reading surfaces continuously.

### Empty

Explain why the surface matters, what is absent, and one next action. Empty is not an error and does not use warning color.

### Stale and offline

Keep useful local/cached content visible, label freshness, and identify what cannot update. Do not block local capture, planning, reading, or correction because an optional external service is unavailable.

### Error

Place the message near the failed work, announce it accessibly, preserve input, and offer Retry/Edit/Cancel as appropriate. Avoid a generic full-screen error for a single failed module.

### Locked and denied

Locked is a privacy state with no content-derived preview. Denied is a permission state with an explanation and Settings/retry path. Neither should resemble “no data.”

## Motion and haptics

Named motion roles:

- press: 90–140 ms;
- selection and symbol replacement: 180–260 ms;
- local insertion/reflow: 260–360 ms;
- control morph and sheet: 320–440 ms;
- shared-element route: 380–500 ms;
- bounded completion: 420–600 ms, once;
- exits: approximately 75% of the corresponding entrance.

Use direct manipulation only when the content visibly follows the gesture. Preserve velocity through the approved resolver and provide non-gesture alternatives.

Approved signature effects:

- `daypartBloom`;
- `evaInkReveal`;
- `journalMediaReveal`;
- `memoryDevelopReveal`;
- `fastingEmberRing`;
- `healthSyncPulse`;
- `vitalOrbWarp`;
- `clayPressBloom`;
- `daypartCrossDissolve`;
- `completionBurst`;
- `contextLens` (capture/Eva background and control planes only, 8 pt maximum offset);
- `chartRevealSweep`;
- `liquidGlassRefract`;
- `cardMorphWarp`;
- `paperGrain` (static; the only non-one-shot treatment);
- `dissolveAway`;
- `triageSettle` (Inbox under-deck plane only).

`daypartBloom` mounts at the root atmosphere boundary and triggers only when the
semantic daypart changes. `triageSettle` mounts below the Inbox deck and follows a
committed direction. Both return to a fully static state and use a short tint
crossfade under Reduce Motion, Reduce Transparency, Low Power Mode, Catalyst, or
shader unavailability.

Haptic vocabulary:

- selection for tabs/chips;
- soft impact for placement/opening;
- success for committed save/completion/apply;
- warning for blocked destructive work;
- never for passive loading or every streamed token.

Reduce Motion, Low Power Mode, thermal pressure, inactive scenes, unsupported shaders, and Catalyst resolve through the central motion policy. One-shot effects are replay-safe across refresh and navigation.

### Motion mounting rules

Motion belongs to the plane whose state changed:

- route zoom belongs to the source and destination surfaces;
- selection motion belongs to the selected control/content boundary;
- chart reveal belongs to the chart plane, never labels or evidence text;
- Inbox triage settles below the deck;
- daypart bloom belongs to the root atmosphere;
- commit morph belongs to the primary action;
- Routine step movement belongs to the replaceable step card.

Do not apply `.animation` high in a feature tree to “make everything smooth.”
That animates unrelated layout and produces duplicate paths. Feature code uses
`.lifeBoardMotion(_:value:)`; raw timing and springs stay in the design system.

### Reduce Motion behavior

Reduce Motion is an alternate choreography, not a disabled product:

- route and step movement becomes a short crossfade;
- charts mount settled;
- numeric state may update without travel;
- dial progress updates statically;
- shaders become token-based tint crossfades;
- direct manipulation still tracks the user’s finger while decorative release
  travel is minimized.

No accessibility fallback may delay input or require waiting for an invisible
animation to finish.

## Content design

- Lead with the decision or state, then rationale.
- Use concrete dates and outcomes for Move, Defer, Delete, Retry, and Undo.
- State the source and timeframe of metrics or claims.
- Distinguish “not recorded” from “0.”
- Avoid moralized productivity, adherence, nutrition, sleep, or mood language.
- Explain why a suggestion appeared and how to suppress future suggestions.
- Destructive confirmation names affected objects, retained history, and reversibility.
- Assistant working copy describes actual work and never rotates decorative status phrases.

## Feature hierarchy summaries

| Surface | First | Dominant action | Secondary context |
|---|---|---|---|
| Home | Greeting, day summary, and one Now card | Start/continue the current commitment | Signals, Day ahead, conditional care, user space |
| Plan Day | Day/Week/Backlog lens, date, and capacity | Place/start/repair on one time spine | Fixed events, open windows, conflicts |
| Plan Week | Distribution across seven days | Open/adjust a day | Weekly operating context |
| Track | Today/Areas/History lens | Record or continue one useful check-in | Typed history and area detail |
| Journal | Date and entries | Capture/write | Media, search, reflection |
| Insights | Overview/Trends/Review lens and one supported interpretation | Follow one recommendation | Disclosed evidence and timeframe |
| EVA | Conversation context | Send or review proposal | Sources, history, model state |
| Settings | Current control category | Save/change | Explanation and dependencies |

## Feature interaction contracts

### Home

Home answers “What matters now?” before it offers configuration.

- Canonical default widgets are tasks, care, routines, journal, and
  progress/reflection.
- Schedule capacity and compact timeline are optional.
- The shared Life Thread composer is the single Home capture entry.
- Customization is transactional and hides global chrome.
- User space remains visually distinct but may be empty without warning language.
- At accessibility sizes, widgets form one readable column and use intrinsic
  height.

Home must not duplicate the same projection in the hero, a metric row, and a
widget. If two modules answer the same question, keep the one with the clearest
action.

### Inbox

Inbox separates capture review from task commitment.

- Right opens review.
- Left skips without mutating the capture.
- Discard is explicit and menu-only.
- Review remains mounted through failure.
- Repeated skips may disclose the count without guilt or urgency language.
- The under-deck settle effect confirms direction but carries no required meaning.

### Plan

Plan answers “When should it happen?” and keeps time capacity subordinate to the
next planning decision.

- Scheduled items use stable task routes.
- Capacity values roll only on real numeric changes.
- A fixed event, LifeBoard task, open window, and conflict remain visually and
  semantically distinct.
- Focus is a destination from work, not a fourth Plan lens.

### Focus

The active Focus surface has one obvious next action in every state.

- The dial presents elapsed or remaining progress but owns no timer state.
- The center clock uses one-Hz numeric updates.
- Pause or Resume is primary.
- Interruption, next phase, completion, continue later, and abandonment are
  secondary commands.
- Outcome commits are receipt-driven.
- Reflection uses the same commit truthfulness.
- Accessibility values state remaining time, phase, and pause state in plain
  language.

### Track

Track separates time-sensitive recording from configuration.

- Today contains current actions and active sessions.
- Areas contains domain detail and settings such as habit resilience.
- History contains typed records and correction paths.
- Hydration quick logs are immediate; target editing is separate.
- At accessibility sizes, card pairs stack and headers become intrinsic.
- Care language remains observational and non-clinical.

### Habit

- Day, Week, and Graph selection uses the shared selection motion.
- Graph reveal runs only on first valid data or a material range change.
- Month/year labels and navigation remain stable.
- Graph meaning is available without color, motion, or the visual chart.

### Guided Routine

- Running, paused, and interrupted states all expose an explicit End path.
- Full-screen presentation is not interactively dismissible.
- Abandonment is confirmed and dispatched through the canonical mutation.
- Continue/Resume is primary; Pause and Skip are secondary.
- Step change may use a restrained card swap; Reduce Motion crossfades.
- Persisted routine state restores after navigation or backgrounding.

## Accessibility acceptance

- All controls have a 44-point effective target or an equivalent accessible action.
- VoiceOver order matches semantic hierarchy.
- Custom gestures have labeled actions and visible controls.
- Charts, rings, progress, and color-coded states have text equivalents.
- Errors and progress are announced without repeated interruption.
- Dynamic Type through accessibility XXXL keeps primary tasks and recovery controls reachable.
- Increase Contrast, grayscale, Reduce Transparency, and Reduce Motion preserve hierarchy and meaning.
- Keyboard and pointer behavior covers root navigation, capture, forms, lists, dialogs, and primary commands on iPad/Catalyst.

### Accessibility layout recipes

At accessibility text sizes:

- switch `HStack` title/action headers to an adaptive vertical layout;
- collapse two-column grids to one column;
- preserve native controls and traits rather than rebuilding them as text;
- put verbose Save/progress/retry actions in the bottom safe area;
- reserve measured floating-chrome height plus an additional readable margin;
- allow segmented or lens controls to scroll horizontally when labels cannot fit;
- keep scene art and decorative labels out of the minimum readable geometry.

Test reachability with real scrolling. Element existence is insufficient if a
floating action, keyboard, or clipped container prevents a control from being
hittable.

## Automation contract

UI identifiers use feature-qualified semantic names:

```text
home.addToHome.<destination>
home.widget.edit.<placementID>
home.widget.drag.<placementID>
lifeThread.composer.tool.<type>
track.lens.<lens>
track.resilience.commit
plan.focus.commit
task.editor.save
```

Rules:

- identify the control’s role, not its current localized label;
- include stable domain identity for repeated rows;
- do not use hierarchy position or `firstMatch` as the contract when an exact
  identity can be supplied;
- do not place menu identifiers under a row-query prefix if tests count rows by
  that prefix;
- UI-test-only seed data must be deterministic and must not alter production
  defaults.

Do not pass `-DISABLE_ANIMATIONS` to Foundation UI tests. Disabling UIKit
animations globally also disables the machinery used by XCUITest scrolling.
The app’s central motion policy already suppresses token-routed decorative motion
under `-UI_TESTING`.

## Release verification

Every revised flagship flow should be reviewed across:

- light and dark appearance;
- standard and accessibility XXXL Dynamic Type;
- Reduce Motion and Reduce Transparency;
- Increased Contrast and grayscale;
- VoiceOver and right-to-left layout;
- compact iPhone and regular-width iPad;
- Catalyst keyboard, pointer, menu, resize, and shader fallback behavior.

Automated acceptance must cover stable routes, mutation success/failure/retry,
duplicate-tap suppression, gesture alternatives, and accessibility reachability.
Visual review must cover hierarchy, clipping, chrome overlap, card density, and
motion restraint. Instruments review should cover animation hitches, unexpected
SwiftUI update spikes, offscreen rendering, and Metal cost under Low Power Mode.

Keep automated evidence distinct from recommended manual/device QA. A successful
build is not proof of VoiceOver order, haptic quality, sustained frame pacing, or
visual polish.

## Review checklist

- Is the user’s current question obvious within one scan?
- Is there exactly one dominant action in the decision group?
- Are zero, empty, stale, denied, locked, offline, and error distinct?
- Can every mutation fail without losing the user’s input?
- Does destructive work explain scope and reversibility?
- Does the screen remain complete without animation, transparency, color, or scenic art?
- Can VoiceOver and keyboard users perform gesture-driven actions?
- Are sensitive fields absent from logs and external previews?
- Does the feature route back to the canonical record rather than a projection?
