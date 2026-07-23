# LifeBoard Product UI/UX Guide

**Classification:** Canonical behavioral design reference

**Normative tokens:** [DESIGN.md](../../DESIGN.md)

**Feature behavior:** [Product handbook](../product/README.md)

**Active status:** [Remaining execution ledger](../todos/LIFEBOARD_5_REMAINING_EXECUTION_LEDGER.md)

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

- press: 90 ms;
- fast feedback: 140 ms;
- local state: 220 ms;
- panel/reflow: 220–280 ms;
- hero/route reveal: 360–420 ms;
- bounded celebration: approximately 540 ms.

Use direct manipulation only when the content visibly follows the gesture. Preserve velocity through the approved resolver and provide non-gesture alternatives.

Approved signature effects:

- `daypartBloom`;
- `evaInkReveal`;
- `journalMediaReveal`;
- `memoryDevelopReveal`;
- `fastingEmberRing`.

Haptic vocabulary:

- selection for tabs/chips;
- soft impact for placement/opening;
- success for committed save/completion/apply;
- warning for blocked destructive work;
- never for passive loading or every streamed token.

Reduce Motion, Low Power Mode, thermal pressure, inactive scenes, unsupported shaders, and Catalyst resolve through the central motion policy. One-shot effects are replay-safe across refresh and navigation.

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
| Home | Orientation and Focus Now | Start/continue the current commitment | Signals, tasks, timeline, reflection |
| Plan Day | Date and capacity | Place/start/repair | Fixed events and unplaced work |
| Plan Week | Distribution across seven days | Open/adjust a day | Weekly operating context |
| Track | Today capture/due state | Record or continue | History, trends, management |
| Journal | Date and entries | Capture/write | Media, search, reflection |
| Insights | Supported pattern | Inspect/save/follow up | Evidence and timeframe |
| EVA | Conversation context | Send or review proposal | Sources, history, model state |
| Settings | Current control category | Save/change | Explanation and dependencies |

## Accessibility acceptance

- All controls have a 44-point effective target or an equivalent accessible action.
- VoiceOver order matches semantic hierarchy.
- Custom gestures have labeled actions and visible controls.
- Charts, rings, progress, and color-coded states have text equivalents.
- Errors and progress are announced without repeated interruption.
- Dynamic Type through accessibility XXXL keeps primary tasks and recovery controls reachable.
- Increase Contrast, grayscale, Reduce Transparency, and Reduce Motion preserve hierarchy and meaning.
- Keyboard and pointer behavior covers root navigation, capture, forms, lists, dialogs, and primary commands on iPad/Catalyst.

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
