---
version: "1.1"
name: "LifeBoard Warm Intelligence"
description: "Target design contract for a calm, personal, premium life operating system on iPhone and iPad."
classification: "Canonical visual and interaction contract"
audience: "Product, design, engineering, and QA"
capability_status: "Current workspace design authority"
source_authority: "Swift semantic tokens and current design-system implementation"
last_verified: "2026-08-11"
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
  hero-scrim: "rgba(255, 253, 247, 0.52)"
  hero-scrim-dark: "rgba(21, 26, 42, 0.58)"
  specular-rim: "rgba(255, 253, 247, 0.60)"
  specular-rim-dark: "rgba(248, 238, 220, 0.22)"
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
  hero: 24px
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
  hero-surface:
    backgroundColor: "{colors.hero-scrim}"
    textColor: "{colors.text-primary}"
    typography: "{typography.body-strong}"
    rounded: "{rounded.hero}"
    padding: "{spacing.xl}"
  hero-surface-fallback:
    backgroundColor: "{colors.surface-raised}"
    textColor: "{colors.text-primary}"
    rounded: "{rounded.hero}"
    padding: "{spacing.xl}"
  specular-rim:
    backgroundColor: "{colors.specular-rim}"
    textColor: "{colors.text-primary}"
    size: "{spacing.xxs}"
  metric-hero:
    backgroundColor: "{colors.surface-raised}"
    textColor: "{colors.text-primary}"
    typography: "{typography.metric}"
    rounded: "{rounded.card}"
    padding: "{spacing.md}"
  section-header:
    backgroundColor: "{colors.canvas}"
    textColor: "{colors.text-primary}"
    typography: "{typography.section-title}"
    height: "{spacing.touch-target}"
  live-state-pill:
    backgroundColor: "{colors.surface-raised}"
    textColor: "{colors.text-primary}"
    typography: "{typography.metadata}"
    rounded: "{rounded.pill}"
    height: "{spacing.touch-target}"
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
- **Hero scrim** is the adaptive veil between the scenic atmosphere and a hero surface's content. It is sized by the contrast it must achieve, not by taste, and it strengthens rather than disappears as the scene brightens.
- **Specular rim** is the lit edge of raised and floating clay. It is a material property, not an accent, and it never carries meaning or state.

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

Depth communicates interaction and ownership, not decoration. Use five visual planes:

1. **Open canvas:** no shadow; atmosphere, prose, and ordinary reading live here.
2. **Recessed well:** tonal inset with a fine semantic boundary; use for fields, progress tracks, and embedded controls.
3. **Raised clay:** one shallow warm shadow, a hairline, and a specular rim; use for rows, supporting cards, charts, draggable objects, proposals, and receipts. This is the default material for content.
4. **Hero glass:** Regular Liquid Glass over the scenic atmosphere, for the single dominant object on a screen.
5. **Floating chrome:** Regular Liquid Glass for navigation, capture, lens rails, compact menus, and approved toolbar controls.

Clay is the material of content and glass is the material of decision and control. The two are not interchangeable, and a screen that reaches for glass a second time has stopped having a hero.

### The hero rule

Exactly one object per screen may be hero glass. It is the object the screen exists to present: the Now decision, today's recorded state, the one interpretation, the invitation to begin. Everything else on that screen is clay.

Four constraints make the privilege safe, and all four are normative:

- **One per screen.** The claim is exclusive and belongs to the composition, not to the component. A hero nested inside another hero renders as floating clay, and that much must be enforced mechanically rather than by convention. Choosing between two candidate heroes *side by side* is the screen's decision, made explicitly where the screen is assembled — a section must never award itself prominence without knowing what sits next to it.
- **Contrast floor.** Hero glass composites a scrim beneath its content until body text reaches 4.5:1 and the metric numeral reaches 3:1 against the *scrimmed composite*, measured across the scene's full luminance range — not against the palette the scene is nominally using.
- **One silhouette, two materials.** The glass presentation and its opaque fallback share geometry, corner radius, padding, and reading order. Swapping materials must never reflow, resize, or reorder anything.
- **Never over evidence.** A hero may hold a title, one line of context, a metric numeral, a ring or truthful status, and one primary action with at most one quiet alternative. It may not contain a chart, a table, an evidence list, body prose, or an assistant message. A hero that has grown a second metric has become a dashboard and must return to clay.

Reduce Transparency, Increase Contrast, Low Power Mode, thermal pressure, an inactive scene, or unavailable shaders all resolve hero glass to floating clay with a strengthened hairline. Glass is an enhancement; the decision it carries is not.

### Glass discipline

Use Regular Glass by default. Do not use Clear Glass in the target system. Related glass controls must read as one surface and morph between stable silhouettes. Under Reduce Transparency, replace glass with an opaque semantic surface and a stronger border without changing layout.

Never place glass on ordinary rows, prose, charts, Journal entries, or assistant messages. Never stack glass on glass — hero glass sits on the scene, never on other glass, which is precisely what makes one-per-screen load-bearing. Avoid glossy highlights, hard black shadows, deep floating stacks, blur as hierarchy, and card-on-card nesting. Scrolling may simplify nonessential shadows while preserving tonal and boundary hierarchy.

### Specular rim

Raised and floating clay carry a thin light edge along the lit side, angled to the current daypart. It is what makes clay read as a soft solid catching light rather than a flat tinted rectangle, and it is the quiet half of "claymorphic liquid glass" — the half that appears on every card rather than once per screen.

The rim is a static gradient stroke. It does not animate, does not consume the ambient motion budget, and does not survive Increase Contrast, where the semantic hairline takes over and boundary clarity outranks material character.

## Shapes

Use continuous corners with a small, purposeful vocabulary:

- **14 points:** fields and recessed wells.
- **16 points:** interactive rows and compact content controls.
- **20 points:** raised decisions, proposals, and receipts.
- **24 points:** the hero surface and its opaque fallback.
- **28 points:** sheets and modal presentations.
- **30 points:** dock and composer clusters.
- **Pill:** primary actions, filters, selected lenses, and status capsules.
- **Circle:** single-purpose icon controls, capture orb, progress dial, and compact marks.

Shape communicates behavior. Pills imply compact actions or selection, circles imply one direct action, and cards imply an independent object. Do not mix arbitrary corner radii within one component family. During shared-element or glass transitions, source and destination must maintain a coherent silhouette without clipping text or controls.

The 24-point hero radius is shared by three things that must read as one object across a transition: the card that represents the surface elsewhere, the hero it becomes when opened, and the opaque fallback that replaces it under reduced transparency. Radius is not a decorative choice at this size — it is the continuity.

## Components

The components below are target design-language contracts. Implementations may use different type names, but must preserve their hierarchy, behavior, states, and accessibility.

### Decision surface

The decision surface is the single dominant object on a screen. It contains one short title, one line of useful context, one primary action, and at most one quiet alternative. It may show progress or a truthful status, but never a dashboard of metrics. On iPad it grows through spacing and composition, not oversized type or empty card area.

### Hero surface

The hero surface is the decision surface rendered in glass over the scenic atmosphere, and it is the only content in the product permitted that material. Its content budget is the decision surface's budget, unchanged: title, one line of context, one metric or truthful status, one primary action, at most one quiet alternative.

It owns the exclusive per-screen claim, the contrast floor, and the opaque fallback described in Elevation & Depth. A screen with no obvious single dominant object does not get a hero — it gets clay throughout, which is a legitimate and common outcome. History, evidence, settings, and browsing surfaces have no hero.

When a hero is reached from a card elsewhere in the product, the card and the hero share a silhouette and the transition preserves it, so the object appears to open rather than to be replaced.

### Metric hero

One recorded value presented at reading scale: label, value, unit, and provenance, with an optional trend and timeframe. It is the single component for every "what is this number right now" moment, whether it sits in a card, a hero, a supporting row, or a grid.

Recorded, explicit zero, no record, stale, denied, and unavailable are six different states with six different presentations. A metric hero must never render an absent value as zero, and must never imply freshness it cannot support. Provenance travels with the value, because a number without a source is not evidence.

### Section header

A title, an optional count, and at most one trailing action. It marks a meaningful change in content, never a label above every group. One type size and one spacing across the entire product; a section header that has been individually restyled is a defect.

### Live-state pill

A compact glass capsule reporting genuinely live state — a running fast, a session in progress, a sync in flight. It carries the corresponding recorded-state signature effect only while that state is actually running, and becomes static the moment it stops.

A live-state pill must never be used for state that is merely recent, merely selected, or merely important. If it is animating, something is happening right now.

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

The dial presents settled progress around a dominant time or activity label. Active, paused, and completed states use text, shape, and color together. Scrubbing or direct manipulation uses magnetic alignment and threshold feedback. While a session is running the dial carries ambient motion within the budget above, so an active session reads as alive rather than frozen; it settles to a static progress presentation when paused, when completed, and whenever the ambient budget withdraws.

### Charts and evidence

Lead with one plain-language interpretation and one useful action. Charts are secondary evidence with labeled axes, timeframe, source, and a prose or table equivalent. Unknown data is not zero. Do not imply causation, health quality, or moral value through color, trend direction, or celebratory copy.

Charts and evidence are always clay and never glass, and never appear inside a hero. Translucency behind a data mark makes the mark's value depend on what happens to be behind it, which is exactly the property evidence must not have. The interpretation may be the hero; the chart that supports it sits below in raised clay.

A chart draws its reveal once, when valid data first appears or its range changes. Empty, denied, and unavailable states never sweep, because a reveal animation implies data arrived.

### State surfaces

Loading, genuinely empty, no record, denied, locked, offline, stale or partial, recoverable failure, destructive confirmation, and recovery must remain distinct. State surfaces replace final content geometry rather than floating above it. A successful-empty state offers one relevant next step; failure explains what remains safe and what can be retried. Protected content is never visible behind blur.

### Target compositions

- **Onboarding:** one question per step, a subtle daypart scene, personal promise, immediate CTA, and a skippable 1.2–1.4-second opening. The first committed win transforms into Home.
- **Home:** greeting and date, one Now decision, up to three signals, open Today rows, concise Day Ahead, and lower-priority modules disclosed only when relevant.
- **Plan:** compact date and capacity context around the dominant time canvas; tasks move into open windows through direct manipulation and accessible move controls.
- **Focus:** one commitment, tactile dial, clear pause/resume/finish actions, minimal chrome, and a persisted completion receipt.
- **Track:** a greeting carrying an explicit daypart reading, then a compact quick-log strip on the control layer, then one hero for the active lens, then Areas and History in clay. Immediate reversible logs use lighter feedback than consequential commits. The daypart reading uses the celestial art already in the product — sun through the daylight phases, moon at night, positioned by how far the day has actually travelled — so two glances an hour apart differ.
- **Journal:** open writing and reading, calm line length, media that settles into the entry after commit, and derived context kept secondary.
- **Insights:** the interpretation is the hero — one claim, one recommended action, one completeness statement. Charts, tallies, and evidence follow in clay; provenance expands on request.
- **Eva:** assistant prose stays open on the canvas and never receives glass or a card. User messages use quiet clay. Glass belongs to the composer, the privacy bar, and — when there is no transcript yet — the invitation to begin, which is the empty screen's hero. Proposals, command results, receipts, and Undo receive bounded clay surfaces.
- **Recorded health surfaces** — sleep, movement, workouts, body metrics, meals, fasting, and nutrition — share one contract across three appearances. As a card elsewhere in the product: raised clay, one value, one unit, one provenance line. As a destination: one hero holding today's state and the capture action, then supporting clay, then the chart, then history rows. As a capture sheet: the clay composer kit with a glass commit bar. The three share a silhouette so opening one reads as the same object growing, and every value on all three carries its source.
- **Inbox and Rescue:** a directional deck with visible alternatives, honest empty/failure states, and one receipt for each committed batch.
- **Daily Loop:** a focused opening decision, current-day action, blame-free repair, and an evening close with one restrained completion moment.

### Motion and delight

Use the motion grammar **source → travel → settle**. Source establishes origin, travel preserves spatial continuity, and settle confirms the new state. Direct manipulation follows the finger without perceptible delay. Persistence precedes success motion and haptics.

Concentrate rich motion at five boundaries: capture, navigation, commitment, replanning, and reflection. Most microinteractions complete within 120–280 milliseconds; spatial transitions complete within 280–500 milliseconds; signature moments remain below roughly 800 milliseconds and never block the next action.

Scrolling is not a quiet moment. Content entering the viewport rises, focuses, and settles; repeated row actions stay restrained but never silent. A surface the person is reading may carry ambient life, and the atmosphere behind every screen is always in motion.

#### Two tiers of motion

Motion in LifeBoard belongs to one of two tiers, and the tier decides the rules:

- **Boundary motion** is one-shot. It is triggered by an event, it plays once, and it returns to a settled state. Every signature effect below is boundary motion unless named otherwise.
- **Ambient motion** is continuous. It has no settled state — it has a bounded envelope, and it exists so the product feels alive rather than paused.

Ambient motion is a privilege with a budget, and the budget is normative:

- At most **one** ambient timeline per screen. Ambient surfaces share it; they do not each start their own.
- **30 frames per second or fewer.**
- Amplitude **at or below 2%** of the affected element's dimension, and never enough to shift a reading position or a touch target.
- Never behind body text, charts, evidence, or sensitive content. Ambient motion belongs to atmosphere, hero surfaces, and live indicators.
- Always paused when the scene is inactive, under Low Power Mode, or under thermal pressure — and absent entirely under the Calm comfort profile or the Still rendering tier.

Ambient motion that cannot state its envelope is not ambient motion; it is a distraction, and it does not ship.

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
- `liquidGlassRefract` for approved dock, lens, composer, and hero-surface transitions.
- `heroGlassSettle` once, when a hero surface arrives or commits; never on scroll, and never while its content is still loading.
- `valueDrumWarp` only while a value tape is under the finger; identity at the centre detent and at rest.
- `paperGrain` as a static texture; it never animates.
- `ambientDrift` and `ambientBreath` as the ambient tier, subject to the budget above.

Effects mount behind text, charts, evidence, and sensitive content. Every **boundary** effect returns to a settled state; **ambient** effects instead stay within their stated envelope and come to rest whenever the budget withdraws them. Reduce Transparency, Low Power Mode, thermal pressure, inactive scenes, unsupported platforms, or shader failure replaces effects with short semantic crossfades or immediate state changes without removing content or delaying input.

Reduce Motion is honoured the same way, with one deliberate exception: LifeBoard offers a **Full motion** setting that overrides the system preference for this app alone. It is on by default, because motion is central to what this product is. Turning it off restores the complete Reduce Motion path everywhere at once. Energy and thermal limits are never overridable — they are not comfort preferences.

### Accessibility and input

Every gesture has a visible control and VoiceOver action. Every control has a stable label, value, trait, and focus order. Support Dynamic Type, Bold Text, VoiceOver, Switch Control, keyboard navigation, pointer interaction, right-to-left layout, Reduce Motion, Reduce Transparency, Increase Contrast, and grayscale without changing task meaning.

Haptics confirm commit, selection, lift, threshold, settle, decline, and failure; they never carry required information. Preserve accessibility focus through morphs and route transitions. Motion, shaders, scenic art, transparency, and haptics are optional enhancements—the complete task must remain understandable and operable without them.

## Do's and Don'ts

- **Do** present one dominant decision; **don't** make unrelated modules compete at equal weight.
- **Do** use open canvas, rows, and negative space; **don't** wrap every section in a card.
- **Do** reserve raised clay for independent objects; **don't** nest cards or build glossy stacks.
- **Do** use Regular Liquid Glass for navigation and control chrome; **don't** stack glass surfaces or use glass for ordinary content.
- **Do** give a screen exactly one hero and let everything else be clay; **don't** let a hero accumulate a second metric until it becomes a dashboard.
- **Do** put glass on the decision and the controls; **don't** put it behind a chart, a table, an evidence list, prose, or an assistant message.
- **Do** keep the hero's glass and its opaque fallback identical in geometry and reading order; **don't** let a comfort or accessibility setting reflow the screen.
- **Do** use semantic colors and Dynamic Type; **don't** hardcode appearance, use light font weights, or shrink text to preserve a layout.
- **Do** keep copy personal, plain, and specific; **don't** expose internal terminology or narrate obvious interface state.
- **Do** distinguish zero, no record, stale, denied, unavailable, locked, offline, and failure; **don't** collapse them into a generic empty state.
- **Do** begin success feedback after persistence; **don't** simulate success with a delay or dismiss recoverable work.
- **Do** pair gestures with buttons, keyboard, and VoiceOver alternatives; **don't** make discovery or completion depend on gesture knowledge.
- **Do** use signature motion at meaningful boundaries, and bounded ambient motion within its stated budget; **don't** run an ambient loop you cannot bound, distort readable content, or animate every state change.
- **Do** honor comfort and accessibility settings without changing capability; **don't** make reduced effects feel like a degraded product.
- **Do** use SF Symbols or curated brand assets; **don't** use emoji as interface icons.
- **Do** preserve privacy in notifications, widgets, previews, and diagnostics; **don't** reveal Journal, health, audio, media, or assistant context outside its authorized surface.
- **Do** design iPad compositions for their window; **don't** stretch phone cards or fill extra space with more metrics.
- **Do** end consequential work with a clear receipt and Undo when supported; **don't** hide destructive consequences behind playful motion.
