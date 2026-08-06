---
version: "1.0"
name: "LifeBoard Warm Intelligence"
description: "Target design contract for a calm, personal, premium life operating system on iPhone and iPad."
colors:
  primary: "#2B2118"
  primary-pressed: "#4A3A2A"
  secondary: "#F0CD87"
  secondary-pressed: "#E5B96D"
  canvas: "#FFF7D8"
  canvas-muted: "#FAF1D8"
  surface: "#FFFDF7"
  surface-raised: "#FFFEFB"
  surface-recessed: "#F4E8C8"
  text-primary: "#2B2118"
  text-secondary: "#675B4D"
  text-tertiary: "#7C705F"
  border: "#E2D6B9"
  border-strong: "#A89572"
  focus: "#5A3D1E"
  inverse-text: "#FFFDF7"
  assistant: "#5A3FD0"
  success: "#536348"
  warning: "#76561E"
  error: "#963F36"
  info: "#52616F"
  selected: "#E9D8AA"
  chart-primary: "#536348"
  chart-secondary: "#975237"
  image-scrim: "rgba(43, 33, 24, 0.24)"
  dark-canvas: "#151A2A"
  dark-canvas-muted: "#111624"
  dark-surface: "#20263B"
  dark-surface-raised: "#282F47"
  dark-surface-recessed: "#191F32"
  dark-text-primary: "#F8EEDC"
  dark-text-secondary: "#D0C3AD"
  dark-text-tertiary: "#B8AA94"
  dark-border: "#4E536B"
  dark-border-strong: "#858AA2"
typography:
  display:
    fontFamily: "SF Pro"
    fontSize: 34px
    fontWeight: 700
    lineHeight: 1.12
  screen-title:
    fontFamily: "SF Pro"
    fontSize: 28px
    fontWeight: 700
    lineHeight: 1.18
  section-title:
    fontFamily: "SF Pro"
    fontSize: 20px
    fontWeight: 600
    lineHeight: 1.25
  body:
    fontFamily: "SF Pro"
    fontSize: 17px
    fontWeight: 400
    lineHeight: 1.4
  body-strong:
    fontFamily: "SF Pro"
    fontSize: 17px
    fontWeight: 600
    lineHeight: 1.35
  support:
    fontFamily: "SF Pro"
    fontSize: 15px
    fontWeight: 400
    lineHeight: 1.4
  metadata:
    fontFamily: "SF Pro"
    fontSize: 13px
    fontWeight: 500
    lineHeight: 1.3
  button:
    fontFamily: "SF Pro"
    fontSize: 17px
    fontWeight: 600
    lineHeight: 1.2
  metric:
    fontFamily: "SF Pro Rounded"
    fontSize: 28px
    fontWeight: 700
    lineHeight: 1.12
  metric-meta:
    fontFamily: "SF Mono"
    fontSize: 12px
    fontWeight: 500
    lineHeight: 1.25
rounded:
  field: 14px
  row: 16px
  card: 20px
  modal: 28px
  dock: 30px
  pill: 999px
spacing:
  xxs: 4px
  xs: 8px
  sm: 12px
  md: 16px
  lg: 20px
  xl: 24px
  xxl: 32px
  xxxl: 40px
  touch-target: 44px
  action-height: 48px
  composer-height: 52px
  phone-margin: 20px
  ipad-margin: 28px
  ipad-wide-margin: 32px
  compact-chrome-clearance: 132px
  readable-width: 680px
  content-max-width: 1080px
components:
  canvas:
    backgroundColor: "{colors.canvas}"
    textColor: "{colors.text-primary}"
  muted-canvas:
    backgroundColor: "{colors.canvas-muted}"
    textColor: "{colors.text-primary}"
  primary-action:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.inverse-text}"
    typography: "{typography.button}"
    rounded: "{rounded.pill}"
    height: "{spacing.action-height}"
    padding: "{spacing.xl}"
  primary-action-pressed:
    backgroundColor: "{colors.primary-pressed}"
    textColor: "{colors.inverse-text}"
  secondary-action:
    backgroundColor: "{colors.secondary}"
    textColor: "{colors.text-primary}"
    typography: "{typography.button}"
    rounded: "{rounded.pill}"
    height: "{spacing.action-height}"
  secondary-action-pressed:
    backgroundColor: "{colors.secondary-pressed}"
    textColor: "{colors.text-primary}"
  grouped-surface:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.text-primary}"
    rounded: "{rounded.card}"
    padding: "{spacing.lg}"
  raised-surface:
    backgroundColor: "{colors.surface-raised}"
    textColor: "{colors.text-primary}"
    rounded: "{rounded.card}"
    padding: "{spacing.lg}"
  decision-surface:
    backgroundColor: "{colors.surface-raised}"
    textColor: "{colors.text-primary}"
    typography: "{typography.body-strong}"
    rounded: "{rounded.card}"
    padding: "{spacing.xl}"
  recessed-well:
    backgroundColor: "{colors.surface-recessed}"
    textColor: "{colors.text-primary}"
    rounded: "{rounded.field}"
    padding: "{spacing.sm}"
  open-row:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.text-primary}"
    typography: "{typography.body}"
    rounded: "{rounded.row}"
    height: "{spacing.touch-target}"
  selected-control:
    backgroundColor: "{colors.selected}"
    textColor: "{colors.text-primary}"
    rounded: "{rounded.pill}"
  focus-ring:
    backgroundColor: "{colors.focus}"
    textColor: "{colors.inverse-text}"
    rounded: "{rounded.pill}"
  assistant-surface:
    backgroundColor: "{colors.assistant}"
    textColor: "{colors.inverse-text}"
    rounded: "{rounded.card}"
    padding: "{spacing.md}"
  status-success:
    backgroundColor: "{colors.success}"
    textColor: "{colors.inverse-text}"
    typography: "{typography.metadata}"
    rounded: "{rounded.pill}"
  status-warning:
    backgroundColor: "{colors.warning}"
    textColor: "{colors.inverse-text}"
    typography: "{typography.metadata}"
    rounded: "{rounded.pill}"
  status-error:
    backgroundColor: "{colors.error}"
    textColor: "{colors.inverse-text}"
    typography: "{typography.metadata}"
    rounded: "{rounded.pill}"
  status-info:
    backgroundColor: "{colors.info}"
    textColor: "{colors.inverse-text}"
    typography: "{typography.metadata}"
    rounded: "{rounded.pill}"
  signal:
    backgroundColor: "{colors.surface-recessed}"
    textColor: "{colors.text-primary}"
    typography: "{typography.metric}"
    rounded: "{rounded.card}"
  composer:
    backgroundColor: "{colors.surface-raised}"
    textColor: "{colors.text-primary}"
    typography: "{typography.body}"
    rounded: "{rounded.dock}"
    height: "{spacing.composer-height}"
    padding: "{spacing.md}"
  modal:
    backgroundColor: "{colors.surface-raised}"
    textColor: "{colors.text-primary}"
    rounded: "{rounded.modal}"
    padding: "{spacing.xl}"
  display-copy:
    backgroundColor: "{colors.canvas}"
    textColor: "{colors.text-primary}"
    typography: "{typography.display}"
  screen-heading:
    backgroundColor: "{colors.canvas}"
    textColor: "{colors.text-primary}"
    typography: "{typography.screen-title}"
  section-heading:
    backgroundColor: "{colors.canvas}"
    textColor: "{colors.text-primary}"
    typography: "{typography.section-title}"
  supporting-copy:
    backgroundColor: "{colors.canvas}"
    textColor: "{colors.text-secondary}"
    typography: "{typography.support}"
  tertiary-copy:
    backgroundColor: "{colors.canvas}"
    textColor: "{colors.text-tertiary}"
    typography: "{typography.metadata}"
  metric-meta-copy:
    backgroundColor: "{colors.canvas}"
    textColor: "{colors.text-secondary}"
    typography: "{typography.metric-meta}"
  hairline:
    backgroundColor: "{colors.border}"
    textColor: "{colors.text-primary}"
    size: "{spacing.xxs}"
  strong-hairline:
    backgroundColor: "{colors.border-strong}"
    textColor: "{colors.text-primary}"
    size: "{spacing.xs}"
  image-overlay:
    backgroundColor: "{colors.image-scrim}"
    textColor: "{colors.inverse-text}"
  chart-primary:
    backgroundColor: "{colors.chart-primary}"
    textColor: "{colors.inverse-text}"
  chart-secondary:
    backgroundColor: "{colors.chart-secondary}"
    textColor: "{colors.inverse-text}"
  dark-canvas:
    backgroundColor: "{colors.dark-canvas}"
    textColor: "{colors.dark-text-primary}"
  dark-muted-canvas:
    backgroundColor: "{colors.dark-canvas-muted}"
    textColor: "{colors.dark-text-primary}"
  dark-grouped-surface:
    backgroundColor: "{colors.dark-surface}"
    textColor: "{colors.dark-text-primary}"
    rounded: "{rounded.card}"
  dark-raised-surface:
    backgroundColor: "{colors.dark-surface-raised}"
    textColor: "{colors.dark-text-primary}"
    rounded: "{rounded.card}"
  dark-recessed-well:
    backgroundColor: "{colors.dark-surface-recessed}"
    textColor: "{colors.dark-text-primary}"
    rounded: "{rounded.field}"
  dark-supporting-copy:
    backgroundColor: "{colors.dark-canvas}"
    textColor: "{colors.dark-text-secondary}"
    typography: "{typography.support}"
  dark-tertiary-copy:
    backgroundColor: "{colors.dark-canvas}"
    textColor: "{colors.dark-text-tertiary}"
    typography: "{typography.metadata}"
  dark-hairline:
    backgroundColor: "{colors.dark-border}"
    textColor: "{colors.dark-text-primary}"
    size: "{spacing.xxs}"
  dark-strong-hairline:
    backgroundColor: "{colors.dark-border-strong}"
    textColor: "{colors.dark-canvas}"
    size: "{spacing.xs}"
  layout-phone:
    padding: "{spacing.phone-margin}"
    height: "{spacing.compact-chrome-clearance}"
  layout-ipad:
    padding: "{spacing.ipad-margin}"
    width: "{spacing.readable-width}"
  layout-ipad-wide:
    padding: "{spacing.ipad-wide-margin}"
    width: "{spacing.content-max-width}"
  section-spacing:
    size: "{spacing.xxl}"
  wide-section-spacing:
    size: "{spacing.xxxl}"
---

# LifeBoard Design System

## Overview

This document defines LifeBoard's **target experience** for a future iPhone and iPad overhaul. It is normative for future design and implementation work; the live app may temporarily differ until that work is completed. Component names below describe design-language contracts and do not claim that matching code types already exist.

LifeBoard is a warm, personal chief of staff for a real day. It helps someone understand what matters, make one good decision, record reality honestly, and move on. It must feel calm, capable, friendly, and deeply considered—never like a productivity dashboard, a technical control panel, or a collage of widgets.

### Experience pillars

- **Quiet confidence.** The interface presents the next useful truth without demanding attention.
- **Personal warmth.** Copy, atmosphere, and small moments acknowledge the person and the time of day without becoming cute or performative.
- **Effortless orientation.** A person must understand the screen's purpose, current state, and primary action within two seconds.
- **Tactile directness.** Objects follow the finger, controls respond immediately, and spatial transitions explain where content came from.
- **Earned delight.** Rich motion and signature effects appear at meaningful boundaries, not as ambient decoration.

Every screen must have one dominant decision, a clear reading order, and progressive disclosure. Supporting information stays quiet until it becomes relevant. Prefer plain, human language over system terminology. Explain consequences before destructive or consequential actions, then provide a clear receipt and Undo where reversal is possible.

Premium quality comes from exact spacing, excellent typography, stable geometry, immediate feedback, and graceful state changes. More glass, more cards, more color, or more animation does not make a screen more premium.

## Colors

The palette is warm paper and cocoa ink by day, warm indigo and parchment by night. Use semantic token roles rather than literal values in feature work so appearance, contrast, and accessibility can adapt without changing meaning.

- **Canvas** carries atmosphere and negative space. It is not a card background repeated around every section.
- **Surface** groups content only when a boundary helps comprehension. Raised surface is reserved for the hero, a movable object, a proposal, or a receipt.
- **Cocoa primary** is the strongest reading and action color in light appearance.
- **Sun secondary** is a warm highlight for one secondary emphasis. It is not a warning color.
- **Assistant violet** belongs only to Eva identity, Eva affordances, and structured assistant context.
- **Success, warning, error, and info** describe recorded state. Never infer completion, health, wellbeing, or urgency from missing evidence.
- **Selected** is paired with shape, label, or selection semantics. Color alone must never communicate selection.

Daypart color may softly influence the canvas and scenic background. It must not recolor semantic status, reduce text contrast, move controls, or change information hierarchy. Scenic art must preserve a quiet reading field; text over imagery requires the shared scrim and must remain readable across the image's full luminance range.

Support light appearance, dark appearance, Increase Contrast, and Reduce Transparency. Normal text must reach at least 4.5:1 contrast; large text, focus boundaries, and meaningful non-text controls must reach at least 3:1. High-contrast variants strengthen boundaries without turning the entire interface into outlined boxes.

## Typography

Use Dynamic Type-backed San Francisco typography. SF Pro carries navigation, tasks, conversation, and long-form reading. SF Pro Rounded is reserved for expressive metrics and rare friendly moments. SF Mono is reserved for aligned times, durations, and compact numeric metadata.

### Hierarchy

- **Display**: a short personal greeting or singular ceremonial moment; never a paragraph.
- **Screen title**: the destination or focused task.
- **Section title**: a meaningful change in content, not a label above every group.
- **Body and body strong**: primary reading, actions, and task content.
- **Support and metadata**: context that may wrap or move below primary content.
- **Metric and metric metadata**: recorded values with units, timeframe, and provenance nearby.

Use no more than three visibly competing typographic levels in one local composition. Do not use light font weights. Do not use uppercase for personality or hierarchy. Avoid center alignment outside onboarding, empty states, celebrations, and singular focus moments.

All meaningful text must scale without clipping. At accessibility sizes, stack metadata and actions, widen the reading surface where possible, and collapse grids before truncating. Journal and Eva prose must retain comfortable line length and line spacing. Never shrink type to preserve a card grid or one-line toolbar.

## Layout

LifeBoard uses an open canvas with deliberate islands of interaction. The default screen budget is:

- one hero decision or active state;
- zero to three relevance-ranked supporting signals;
- one visually dominant primary action;
- open rows or prose for ordinary content;
- deeper detail disclosed through navigation, expansion, or a secondary pane.

Avoid nested cards, duplicated counts, repeated headings, and grids where every item has equal weight. A card is justified only when its contents form one independent decision, summary, movable object, proposal, or receipt.

### Five roots

- **Home — What matters now?** One Now decision, up to three honest signals, today's committed work, and concise day-ahead context.
- **Plan — When should it happen?** A time canvas with day, week, and backlog views; scheduling is the primary activity.
- **Focus — What am I doing now?** A distraction-free active commitment, timer state, and clear pause, resume, or finish controls.
- **Track — What needs recording or sustaining?** Fast access to timely logs, followed by areas and history.
- **Journal — What do I want to remember or understand?** An open writing and reading surface with reflections, media, and derived insight disclosed gently.

Insights and Eva are first-class destinations reached from relevant context and global chrome. Insights answers “What changed, and what should I do next?” Eva answers “Help me understand or safely make a change.” Neither competes with the five-root dock.

### iPhone

Use a floating five-target root dock. Immediately above it, use a 52-point “Ask Eva or capture” composer capsule. After purposeful downward scrolling, the composer may compress into a 48-point orb; it must restore at the top or on tap. It must never collapse while editing, dictating, reviewing a proposal, waiting for a result, showing a receipt, or holding a draft.

Reserve measured bottom clearance for floating chrome; content must never disappear behind the dock or composer. Focused editors, immersive Focus sessions, customization, and daily rituals suppress competing global chrome. Root changes preserve each root's navigation state and use directional movement that reflects destination order.

### iPad

Use a five-root switcher above root content rather than stretching the phone dock. Constrain prose and forms to a 680-point readable width and primary compositions to a 1080-point maximum. Use a secondary pane only when both panes remain independently useful, such as task detail, Plan scheduling, Journal context, or Eva evidence.

Compact split-screen preserves the iPhone reading order with wider intrinsic rows. Regular width uses breathing room and conditional two-pane layouts. Wide and landscape layouts may show supporting context alongside the primary surface, but must not fill space with additional cards. Pointer targets, hover treatment, keyboard focus, and root shortcuts are part of the design.

### Adaptive behavior

Use the 4/8/12/16/20/24/32/40-point rhythm. Maintain at least 44 by 44 points for every interactive target. At large text sizes, use one content column, allow horizontal controls to scroll or stack, and keep primary actions reachable above the safe area. Support right-to-left layout by mirroring spatial navigation and directional affordances while preserving semantic meaning.

## Elevation & Depth

Depth communicates interaction and ownership, not decoration. Use four visual planes:

1. **Open canvas:** no shadow; atmosphere and ordinary reading live here.
2. **Recessed well:** tonal inset with a fine semantic boundary; use for fields, progress tracks, and embedded controls.
3. **Raised clay:** one shallow warm shadow and hairline; use for the hero, a draggable object, proposal, or receipt.
4. **Floating chrome:** Regular Liquid Glass for navigation, capture, compact menus, and approved toolbar controls.

Use Liquid Glass only on the navigation and control layer. Related glass controls must read as one surface and morph between stable silhouettes. Use Regular Glass by default. Do not use Clear Glass in the target system. Under Reduce Transparency, replace glass with an opaque semantic surface and a stronger border without changing layout.

Never place glass on ordinary rows, prose, charts, Journal entries, or assistant messages. Never stack glass on glass. Avoid glossy highlights, hard black shadows, deep floating stacks, blur as hierarchy, and card-on-card nesting. Scrolling may simplify nonessential shadows while preserving tonal and boundary hierarchy.

## Shapes

Use continuous corners with a small, purposeful vocabulary:

- **14 points:** fields and recessed wells.
- **16 points:** interactive rows and compact content controls.
- **20 points:** raised decisions, proposals, and receipts.
- **28 points:** sheets and modal presentations.
- **30 points:** dock and composer clusters.
- **Pill:** primary actions, filters, selected lenses, and status capsules.
- **Circle:** single-purpose icon controls, capture orb, progress dial, and compact marks.

Shape communicates behavior. Pills imply compact actions or selection, circles imply one direct action, and cards imply an independent object. Do not mix arbitrary corner radii within one component family. During shared-element or glass transitions, source and destination must maintain a coherent silhouette without clipping text or controls.

## Components

The components below are target design-language contracts. Implementations may use different type names, but must preserve their hierarchy, behavior, states, and accessibility.

### Decision surface

The decision surface is the single dominant object on a screen. It contains one short title, one line of useful context, one primary action, and at most one quiet alternative. It may show progress or a truthful status, but never a dashboard of metrics. On iPad it grows through spacing and composition, not oversized type or empty card area.

### Open row

Use open rows for tasks, events, habits, logs, evidence, and settings. Lead with title or value, follow with one restrained metadata line, and place status or accessory content at the trailing edge. Provide a full-row navigation target while keeping completion, disclosure, and destructive actions semantically distinct. At large text sizes, metadata moves below the title and trailing actions remain reachable.

### Signal strip

Show zero to three signals selected by current relevance, actionability, and freshness. Each signal communicates a single fact with label, value or state, timeframe, and direct destination. Loading, no record, explicit zero, stale, denied, unavailable, and error are separate states. Signals scroll on compact widths and may form a quiet row on iPad; they do not become a large metric grid.

### Morphing composer

The composer provides capture and Eva access without dominating the screen. Its states are compact capsule, capture orb, expanded input, dictation, tools, working, review, and receipt. State changes morph in place and preserve draft, keyboard focus, accessibility focus, and input mode. A working or review state cannot be dismissed by automatic chrome compression.

### Root dock and selected lens

The dock contains five equally reachable targets with one moving selected lens. Selection uses position, shape, label, and accessibility state—not tint alone. Root transitions originate from the selected target and settle before secondary content animates. On iPad, the same contract appears as a top switcher with pointer and keyboard behavior.

### Commit control and receipt

Consequential actions use idle, running, success, recoverable failure, and cancelled phases. Running prevents duplicate submission while preserving input. Success feedback begins only after the canonical action succeeds. Failure keeps user work mounted and offers a specific retry. A receipt names what changed and exposes Undo when reversal is supported.

### Directional decision deck

Inbox, Rescue, and replanning decisions may use one front card on a stable deck plane. Drag follows the finger, reveals direction meaning before threshold, and settles or returns predictably. Every gesture direction has a visible labeled button, VoiceOver action, keyboard equivalent, and non-destructive default. Destructive outcomes require explicit confirmation.

### Focus dial

The dial presents settled progress around a dominant time or activity label. Active, paused, and completed states use text, shape, and color together. Scrubbing or direct manipulation uses magnetic alignment and threshold feedback. The dial does not run an ambient shader and becomes a static progress presentation under Reduce Motion.

### Charts and evidence

Lead with one plain-language interpretation and one useful action. Charts are secondary evidence with labeled axes, timeframe, source, and a prose or table equivalent. Unknown data is not zero. Do not imply causation, health quality, or moral value through color, trend direction, or celebratory copy.

### State surfaces

Loading, genuinely empty, no record, denied, locked, offline, stale or partial, recoverable failure, destructive confirmation, and recovery must remain distinct. State surfaces replace final content geometry rather than floating above it. A successful-empty state offers one relevant next step; failure explains what remains safe and what can be retried. Protected content is never visible behind blur.

### Target compositions

- **Onboarding:** one question per step, a subtle daypart scene, personal promise, immediate CTA, and a skippable 1.2–1.4-second opening. The first committed win transforms into Home.
- **Home:** greeting and date, one Now decision, up to three signals, open Today rows, concise Day Ahead, and lower-priority modules disclosed only when relevant.
- **Plan:** compact date and capacity context around the dominant time canvas; tasks move into open windows through direct manipulation and accessible move controls.
- **Focus:** one commitment, tactile dial, clear pause/resume/finish actions, minimal chrome, and a persisted completion receipt.
- **Track:** a compact quick-log strip first, then Areas and History. Immediate reversible logs use lighter feedback than consequential commits.
- **Journal:** open writing and reading, calm line length, media that settles into the entry after commit, and derived context kept secondary.
- **Insights:** one interpretation and one action before charts; evidence and provenance expand on request.
- **Eva:** assistant prose stays open on the canvas, user messages use quiet clay, and only proposals, command results, receipts, and Undo receive bounded surfaces.
- **Inbox and Rescue:** a directional deck with visible alternatives, honest empty/failure states, and one receipt for each committed batch.
- **Daily Loop:** a focused opening decision, current-day action, blame-free repair, and an evening close with one restrained completion moment.

### Motion and delight

Use the motion grammar **source → travel → settle**. Source establishes origin, travel preserves spatial continuity, and settle confirms the new state. Direct manipulation follows the finger without perceptible delay. Persistence precedes success motion and haptics.

Concentrate rich motion at five boundaries: capture, navigation, commitment, replanning, and reflection. Ordinary scrolling, reading, and repeated row actions stay quiet. Most microinteractions complete within 120–280 milliseconds; spatial transitions complete within 280–500 milliseconds; signature moments remain below roughly 800 milliseconds and never block the next action.

Comfort profiles change expression, not capability:

- **Calm:** crossfades and short state changes; no elastic or spatial flourish.
- **Balanced:** the premium default; restrained spring, depth, and one-shot effects.
- **Playful:** slightly stronger elasticity, shimmer, and haptic texture without longer waits or changed outcomes.

Use the existing signature-effect vocabulary only:

- `firstLight` for the first daily commitment and onboarding arrival.
- `contextLens` for capture or composer mode handoff.
- `cardMorphWarp` behind a row-to-detail transition.
- `clayPressBloom` for a significant press or selection.
- `completionBurst` and `dissolveAway` only after persisted completion.
- `triageSettle` beneath Inbox, Rescue, and repair decks.
- `chartRevealSweep` when valid chart data first appears or its range changes.
- `evaInkReveal` for newly arriving Eva content.
- `journalMediaReveal` and `memoryDevelopReveal` for committed media and memories.
- `daypartBloom` and `daypartCrossDissolve` at semantic atmosphere changes.
- `healthSyncPulse`, `vitalOrbWarp`, and `fastingEmberRing` only for corresponding recorded state changes.
- `liquidGlassRefract` for approved dock, lens, and composer transitions.
- `valueDrumWarp` only while a value tape is under the finger; identity at the centre detent and at rest.
- `paperGrain` as the only static effect.

Effects mount behind text, charts, evidence, and sensitive content. Every animated effect returns to a settled state. Reduce Motion, Reduce Transparency, Low Power Mode, thermal pressure, inactive scenes, unsupported platforms, or shader failure replaces effects with short semantic crossfades or immediate state changes without removing content or delaying input.

### Accessibility and input

Every gesture has a visible control and VoiceOver action. Every control has a stable label, value, trait, and focus order. Support Dynamic Type, Bold Text, VoiceOver, Switch Control, keyboard navigation, pointer interaction, right-to-left layout, Reduce Motion, Reduce Transparency, Increase Contrast, and grayscale without changing task meaning.

Haptics confirm commit, selection, lift, threshold, settle, decline, and failure; they never carry required information. Preserve accessibility focus through morphs and route transitions. Motion, shaders, scenic art, transparency, and haptics are optional enhancements—the complete task must remain understandable and operable without them.

## Do's and Don'ts

- **Do** present one dominant decision; **don't** make unrelated modules compete at equal weight.
- **Do** use open canvas, rows, and negative space; **don't** wrap every section in a card.
- **Do** reserve raised clay for independent objects; **don't** nest cards or build glossy stacks.
- **Do** use Regular Liquid Glass for navigation and control chrome; **don't** use glass for content or stack glass surfaces.
- **Do** use semantic colors and Dynamic Type; **don't** hardcode appearance, use light font weights, or shrink text to preserve a layout.
- **Do** keep copy personal, plain, and specific; **don't** expose internal terminology or narrate obvious interface state.
- **Do** distinguish zero, no record, stale, denied, unavailable, locked, offline, and failure; **don't** collapse them into a generic empty state.
- **Do** begin success feedback after persistence; **don't** simulate success with a delay or dismiss recoverable work.
- **Do** pair gestures with buttons, keyboard, and VoiceOver alternatives; **don't** make discovery or completion depend on gesture knowledge.
- **Do** use signature motion at meaningful boundaries; **don't** run ambient loops, distort readable content, or animate every state change.
- **Do** honor comfort and accessibility settings without changing capability; **don't** make reduced effects feel like a degraded product.
- **Do** use SF Symbols or curated brand assets; **don't** use emoji as interface icons.
- **Do** preserve privacy in notifications, widgets, previews, and diagnostics; **don't** reveal Journal, health, audio, media, or assistant context outside its authorized surface.
- **Do** design iPad compositions for their window; **don't** stretch phone cards or fill extra space with more metrics.
- **Do** end consequential work with a clear receipt and Undo when supported; **don't** hide destructive consequences behind playful motion.
