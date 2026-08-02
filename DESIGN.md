---
version: dogfood-v1
name: LifeBoard Warm Clay System
description: The canonical visual contract for LifeBoard's adaptive, local-first life operating system.
colors:
  primary: "#2B2118"
  primary-pressed: "#4A3A2A"
  secondary: "#F0CD87"
  secondary-pressed: "#E7BB7E"
  canvas: "#FFF7D8"
  canvas-secondary: "#FAF2DA"
  surface: "#FFFDF7"
  surface-secondary: "#F5EBCB"
  surface-tertiary: "#F2E7C2"
  on-surface: "#2B2118"
  on-surface-secondary: "#6F6252"
  on-surface-tertiary: "#877B68"
  outline: "#E9DFC6"
  outline-strong: "#CBBFA4"
  focus: "#5A3D1E"
  decorative-ring: "rgba(90, 61, 30, 0.42)"
  assistant: "#6842FF"
  success: "#5D6A4D"
  warning: "#8A6A2F"
  error: "#A14E41"
  info: "#68727E"
  inverse: "#FFFDF7"
  selected: "#F2E7C2"
  chart-primary: "#5D6A4D"
  chart-secondary: "#E7BB7E"
  image-scrim: "rgba(43, 33, 24, 0.16)"
  dark-canvas: "#151B2D"
  dark-canvas-secondary: "#111624"
  dark-surface: "#202741"
  dark-surface-secondary: "#262E4A"
  dark-on-surface: "#F4EBDD"
  dark-on-surface-secondary: "#C6BBA8"
  dark-outline: "#4D526D"
  high-contrast-outline: "#A89572"
  dark-high-contrast-outline: "#777C9B"
typography:
  display:
    fontFamily: "SF Pro Rounded"
    fontSize: 32px
    fontWeight: 700
    lineHeight: 1.15
  screen-title:
    fontFamily: "SF Pro"
    fontSize: 28px
    fontWeight: 600
    lineHeight: 1.2
  section-title:
    fontFamily: "SF Pro Rounded"
    fontSize: 20px
    fontWeight: 600
    lineHeight: 1.25
  body:
    fontFamily: "SF Pro"
    fontSize: 16px
    fontWeight: 400
    lineHeight: 1.35
  metadata:
    fontFamily: "SF Pro"
    fontSize: 13px
    fontWeight: 500
    lineHeight: 1.25
  metric:
    fontFamily: "SF Pro Rounded"
    fontSize: 24px
    fontWeight: 700
    lineHeight: 1.2
  metric-meta:
    fontFamily: "SF Mono"
    fontSize: 12px
    fontWeight: 500
    lineHeight: 1.2
  title-lg:
    fontFamily: "SF Pro"
    fontSize: 22px
    fontWeight: 600
    lineHeight: 1.25
  title-md:
    fontFamily: "SF Pro"
    fontSize: 18px
    fontWeight: 600
    lineHeight: 1.25
  body-strong:
    fontFamily: "SF Pro"
    fontSize: 16px
    fontWeight: 600
    lineHeight: 1.35
  support:
    fontFamily: "SF Pro"
    fontSize: 15px
    fontWeight: 400
    lineHeight: 1.35
  callout:
    fontFamily: "SF Pro"
    fontSize: 14px
    fontWeight: 400
    lineHeight: 1.3
  caption:
    fontFamily: "SF Pro"
    fontSize: 12px
    fontWeight: 400
    lineHeight: 1.25
rounded:
  none: 0px
  input: 14px
  card: 18px
  modal: 28px
  dock: 28px
  pill: 999px
  full: 999px
  card-ipad: 20px
  modal-ipad: 32px
spacing:
  s2: 2px
  s4: 4px
  s8: 8px
  s12: 12px
  s16: 16px
  s20: 20px
  s24: 24px
  s32: 32px
  s40: 40px
  phone-margin: 20px
  card-padding: 20px
  section-gap: 28px
  button-height: 48px
  touch-target: 44px
  phone-dock-clearance: 150px
  ipad-compact-margin: 24px
  ipad-regular-margin: 28px
  ipad-expanded-margin: 32px
  ipad-card-padding: 24px
  ipad-section-gap: 32px
  grid-phone-columns: 4
  grid-ipad-columns: 8
  grid-wide-columns: 12
components:
  primary-action:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.inverse}"
    typography: "{typography.body}"
    rounded: "{rounded.pill}"
    height: "{spacing.button-height}"
  primary-action-pressed:
    backgroundColor: "{colors.primary-pressed}"
  secondary-action:
    backgroundColor: "{colors.secondary}"
    textColor: "{colors.on-surface}"
    typography: "{typography.body}"
    rounded: "{rounded.pill}"
  secondary-action-pressed:
    backgroundColor: "{colors.secondary-pressed}"
    textColor: "{colors.on-surface}"
  clay-card:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.on-surface}"
    rounded: "{rounded.card}"
    padding: "{spacing.card-padding}"
  clay-well:
    backgroundColor: "{colors.surface-secondary}"
    textColor: "{colors.on-surface-secondary}"
    rounded: "{rounded.input}"
    padding: "{spacing.s12}"
  subdued-surface:
    backgroundColor: "{colors.surface-tertiary}"
    textColor: "{colors.on-surface}"
    rounded: "{rounded.input}"
    padding: "{spacing.s12}"
  tertiary-mark:
    backgroundColor: "{colors.on-surface-tertiary}"
    size: 16px
  selected-chip:
    backgroundColor: "{colors.selected}"
    textColor: "{colors.on-surface}"
    rounded: "{rounded.pill}"
  canvas:
    backgroundColor: "{colors.canvas}"
    textColor: "{colors.on-surface}"
  canvas-secondary:
    backgroundColor: "{colors.canvas-secondary}"
    textColor: "{colors.on-surface}"
  focus-ring:
    backgroundColor: "{colors.focus}"
    textColor: "{colors.inverse}"
  assistant-card:
    backgroundColor: "{colors.assistant}"
    textColor: "{colors.inverse}"
    rounded: "{rounded.card}"
  status-success:
    backgroundColor: "{colors.success}"
    textColor: "{colors.inverse}"
  status-warning:
    backgroundColor: "{colors.warning}"
    textColor: "{colors.inverse}"
  status-info:
    backgroundColor: "{colors.info}"
    textColor: "{colors.inverse}"
  strong-outline:
    backgroundColor: "{colors.outline-strong}"
    textColor: "{colors.on-surface}"
  glass-dock:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.on-surface}"
    rounded: "{rounded.dock}"
  destructive-action:
    backgroundColor: "{colors.error}"
    textColor: "{colors.inverse}"
    rounded: "{rounded.pill}"
  task-row:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.on-surface}"
    typography: "{typography.body}"
    rounded: "{rounded.input}"
    height: "{spacing.touch-target}"
  focus-card:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.on-surface}"
    typography: "{typography.body-strong}"
    rounded: "{rounded.card}"
    padding: "{spacing.card-padding}"
  signal-ring:
    backgroundColor: "{colors.surface-secondary}"
    textColor: "{colors.on-surface}"
    size: 64px
  eva-composer:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.on-surface}"
    rounded: "{rounded.dock}"
    height: "{spacing.button-height}"
  image-overlay:
    backgroundColor: "{colors.image-scrim}"
  chart-primary:
    backgroundColor: "{colors.chart-primary}"
    textColor: "{colors.inverse}"
  chart-secondary:
    backgroundColor: "{colors.chart-secondary}"
    textColor: "{colors.on-surface}"
  dark-canvas:
    backgroundColor: "{colors.dark-canvas}"
    textColor: "{colors.dark-on-surface}"
  dark-canvas-secondary:
    backgroundColor: "{colors.dark-canvas-secondary}"
    textColor: "{colors.dark-on-surface}"
  dark-surface:
    backgroundColor: "{colors.dark-surface}"
    textColor: "{colors.dark-on-surface}"
    rounded: "{rounded.card}"
  dark-surface-secondary:
    backgroundColor: "{colors.dark-surface-secondary}"
    textColor: "{colors.dark-on-surface-secondary}"
  dark-outline:
    backgroundColor: "{colors.dark-outline}"
    textColor: "{colors.dark-on-surface}"
---

# LifeBoard Design System

## Overview

LifeBoard is a calm, tactile operating surface for a real day. It should feel warm, capable, and adult: like a well-made paper planner with responsive depth, not a toy, a dashboard collage, or a decorative 3D scene. The interface reduces cognitive load by making one decision primary, keeping supporting context quiet, and preserving honest states when data is unavailable.

The implementation source of truth is `LifeBoardColorTokens` and its spacing, typography, corner, elevation, motion, and surface companions. This document is the persistent design contract for people and coding agents; it does not replace the Swift token system.

## Colors

- **Cocoa ink (`#2B2118`)** is the primary action and strongest reading color on light paper.
- **Warm paper (`#FFF7D8`)** is the scenic canvas; raised paper (`#FFFDF7`) is the primary content surface.
- **Sun (`#F0CD87`)** and apricot are warm highlights, not a substitute for semantic status.
- **Assistant violet (`#6842FF`)** is reserved for EVA/assistant context. It must not become a generic selection color.
- **Success, warning, and error** communicate recorded state only. Never infer health, completion, or wellbeing from incomplete data.
- **Focus (`#5A3D1E` light / `#F3E6C8` dark)** is an opaque accessibility affordance. It is not an alias for the translucent decorative accent ring; focus indicators must preserve their 3:1 boundary contrast.
- **Hairlines respond to Increase Contrast.** The semantic hairline strengthens from `#E9DFC6` to `#A89572` in light appearance and from `#4D526D` to `#777C9B` in dark appearance.
- Dark appearance is a designed warm-indigo composition from the adaptive Swift tokens, not a color inversion. Use semantic token roles rather than the literal values above when implementing UIKit or SwiftUI.

## Typography

Use Dynamic Type-backed system typography. SF Pro Rounded gives greetings, metrics, and friendly section emphasis their human warmth; SF Pro carries task content and long-form reading; SF Mono is only for aligned times, durations, progress, and compact metrics. Preserve the semantic role even when adaptive layout changes the point size. Never add a bundled web font or use raw fixed sizes in feature code.

The full hierarchy is display, screen title, section title, title, headline, body, strong/emphasis body, support, callout, metadata, caption, button, metric, and monospaced metadata. Use no more than three visibly competing levels in one local group. Long-form Journal and explanation text should remain readable at the user’s preferred size; dashboards must not shrink type to preserve a grid.

## Layout

Use the 2/4/8/12/16/20/24/32/40 pt rhythm. Phone content begins at the tokenized 20 pt horizontal margin; iPad uses the adaptive layout recipes rather than scaled phone geometry. Keep a minimum 44 pt hit target, reserve safe-area space for the dock and composer, and let accessibility sizes stack metadata/actions or scroll signal rails before truncating meaningful content.

Home stays open between modules so its atmosphere can breathe. A card is warranted only for one decision, one summary, or one independently movable widget. Task rows remain open and readable; Focus Now is the only deliberately dominant Home card.

### LifeBoard 5 root architecture

Every root answers one question and preserves its own navigation state:

- **Home — What matters now?** One dominant Now decision, no more than four honest signals, Today's committed work, Day ahead, conditional Needs attention, then Keep steady, Close the loop, and user-owned supporting widgets. Home does not restate the same projection twice: if the Now card, a section state, and a summary line would all narrate the open-task count, only one of them survives.
- **Plan — When should it happen?** Day, Week, and Backlog. Focus is a typed destination from work rather than a competing root lens.
- **Track — What needs recording or sustaining?** Today, Areas, and History. Today carries only what is time-sensitive — a running fast appears there and returns to its area when it ends. Every domain is reachable from the new tree; nothing is exclusive to an older surface. History records the whole tracked life, not just care. Configuration and grading belong in detail/settings.
- **Insights — What changed, and what should I do next?** Overview, Trends, and Review. Interpretation precedes metrics; raw provenance is disclosed as Evidence.
- **Eva — Help me understand or safely make a change.** Full-height conversation; all mutations remain explicit proposals with receipts.

The floating conversational composer owns capture on every root except Eva, which hosts its own. Its leading control expands into the capture tray; every capture kind with a working host has a visible control there. The compact root header owns capture only where the composer is suppressed, plus the overflow menu, the Home mode control, and Add to Home. The bottom dock is an unobstructed five-target Regular Glass capsule; composer and dock share one `GlassEffectContainer` so they morph as a single surface. Home orientation roles are anchored and rendered once; schema-v5 migration removes only app-owned duplicates and preserves user IDs, payloads, order, size, visibility, ownership, and unknown widgets.

### Card archetypes

`HomeCardSnapshot` carries a typed `HomeCardPayload` alongside its strings, so a card can be a number, a series, a target or a queue rather than a joined sentence. Every registered kind declares a `HomeCardArchetype` — metric, ring, trend, queue, streak, decision, spine, moment, countdown, action — and every archetype renders at all five size presets. This is a correctness rule, not a style one: accessibility text sizes force the wide preset, so an archetype that cannot draw at wide is a blank card for anyone using large type.

Charts always ship their prose equivalent, and degrade to it entirely at accessibility sizes rather than shrinking type. Hero numerals roll only on a real value change. Sensitive cards drop their payload before reaching any widget, Spotlight item or notification preview.

`DashboardWidgetDescriptor.sectionRole` is the single source of truth for which Home section a card belongs to — it replaced three hardcoded string sets in the Home view and a fourth copy in the layout repository.

### Home modes

Smart, Work, Personal and Low Energy each change content, not just palette. `DashboardModePolicy` resolves the permitted planning contexts, which cards a mode will surface, and how many sections it shows; providers filter their own queries rather than the view hiding rows afterwards. Work excludes sensitive cards outright. Low Energy reduces Home to Now, Signals and Keep steady.

Phone uses the canonical four-column semantic grid, regular iPad eight columns, and wide iPad twelve. Persist semantic spans, not device pixels. The system scales authored spans proportionally and falls back to one content column at accessibility sizes. Content must reserve the measured floating chrome height rather than assuming a fixed safe-area inset.

## Elevation & Depth

Create clay depth with tonal paper layers, a fine warm hairline, and shallow named shadows. Raised content is tactile but quiet; do not use glossy highlights, hard black shadows, deep floating stacks, or card-on-card nesting. Use the existing clay-card and embedded-well primitives instead of inventing new shadow geometry.

Named depth roles are embedded well, grouped/reading surface, raised card, floating action, dock, rescue tile, and focused overlay. Scroll-optimized rendering may remove nonessential shadows while retaining border and tonal hierarchy. Never encode importance solely as a larger blur.

Regular glass is navigation and control chrome only: the bottom dock, capture control, EVA composer, compact menus/filters, and approved sheet headers. Clear glass requires local dimming and verified contrast over scenic art. Under Reduce Transparency, substitute opaque semantic surfaces with stronger hairlines.

## Shapes

Use continuous corners. Inputs use 14 pt corners; standard cards 18 pt; sheets and dock clusters 28 pt; chips and primary actions are pills. Circular controls are genuinely circular and must retain their target size. Do not mix sharp, squared controls into the clay system without a platform-owned reason.

## Components

- **Primary action:** one per decision surface where possible; cocoa on paper, with a visible pressed state and semantic inverse label.
- **Secondary actions and chips:** quieter paper/well treatments; selected state uses a semantic token and never relies on color alone.
- **Task row:** 44 pt completion target, title first, one restrained metadata line, optional truthful status chip, and no nested gamification card.
- **Focus card:** the dominant daily commitment; show one visible action and a one-line explanation. Put deeper reasoning in EVA or detail.
- **Signal ring:** distinguish loading, setup required, stale, unavailable, explicit zero, and recorded value visually and in accessibility labels.
- **EVA composer and dock:** approved Regular Glass chrome with an opaque fallback. Do not place required reading copy on translucent material over uncontrolled imagery.
- **Loading, empty, error, and denied states:** replace final content geometry rather than overlay it; explain recovery and keep actions available.
- **Destructive work:** use an explicit confirmation, warning color, stable layout, and undo/receipt where supported by the canonical mutation path.
- **Charts:** use semantic series colors, labeled axes, timeframe/source context, and a table or prose equivalent. Never imply causation or wellness quality through color.
- **Scenic imagery:** preserve a calm negative-space reading field and use the shared luminance/readability policy before placing text over images.
- **Direct manipulation:** pair drag/swipe with buttons, keyboard commands, and VoiceOver actions. Preserve velocity only within named interaction policies.
- **Protected surfaces:** show a content-free clay unlock/recovery surface; never render sensitive content behind a blur.

### Commit controls

`LifeBoardCommitControl` is the canonical presentation for a consequential async
save. Its phase comes from the store’s real `AsyncActionPhase<Receipt>`:

- idle shows the enabled action;
- running suppresses duplicate taps and reports progress;
- success draws the completion mark only after the canonical mutation returns;
- recoverable failure keeps the input mounted and offers retry;
- cancellation returns to an actionable settled state.

Feature views must not synthesize success with a delay, dismiss before persistence,
or create a receipt before the awaited mutation succeeds. Editors that need space
for progress, error, and retry place the commit action in the bottom safe area.
Immediate reversible logs, such as hydration quick-add, use lighter feedback.

### Focus dial

`LifeBoardFocusDial` is a presentation-only circular progress surface. Timer
ownership remains in the Focus domain. The dial receives settled progress, paused
state, accessible text, and center content; it never schedules commands or persists
time.

The track uses a quiet recessed cocoa/paper tone. Active progress uses
apricot/ember; paused progress uses sage. The center clock remains the dominant
reading element and uses numeric text transitions at one Hz. Under Reduce Motion,
progress updates without spring travel. Never mount a continuously running shader
on the dial.

### Focused Home customization

Home editing is a transactional mode:

- hide the global dock and capture composer;
- freeze contextual reordering;
- expose one Cancel/Done action group;
- show drag and context controls only as editing affordances;
- preserve the normal Home hierarchy and production defaults until Done succeeds;
- restore the exact pre-edit layout on Cancel.

Do not leave persistent Pinned badges, repeated ellipsis buttons, or global capture
chrome competing with the layout task.

### Directional decks

Use `LifeBoardDirectionalDeck` and `LifeBoardDeckPhysics` for flickable decision
cards. The resolver owns threshold, axis dominance, predicted translation, exit
offset, and tilt. Render only the front card; depth belongs to the deck plane, not
live sibling content that may leak when card heights differ.

Every direction must have:

- a visible labeled alternative;
- a VoiceOver action;
- one unambiguous domain meaning;
- a non-destructive default;
- a persisted-state boundary before success feedback.

### Daily Loop

The Daily Loop is Home's non-pinnable spine and the app's primary daily rhythm.
Its resolver has five mutually exclusive stages: `.commit` offers an explicit
morning confirmation, `.act` leads with the current decision, `.repair` surfaces
drift without blame, `.close` opens the evening ritual, and `.rest` asks for
nothing after closure. Persisted open/close state outranks the clock. Loading,
genuinely empty, stale, unavailable, denied, explicit zero, unknown evidence,
and recoverable failure remain visibly and semantically distinct.

The evening ritual is one scroll with four acts: reconcile unfinished work,
reflect, choose tomorrow's anchor, and close. A liquid ring reports only recorded
planned/focused time. A vertical act thread has four clay knots; a knot settles
only when its act is complete, never merely because it was scrolled past. The
deck exposes all four alternatives as labels, buttons, gestures, VoiceOver
actions, and keyboard-accessible controls: tomorrow, someday, done anyway, and
release. Undo restores the previous shuffle and zoom transitions share the named
Home/ritual source and destination.

Directional feedback stays tactile but bounded. Morning proposal cards retain
the established lean sequence `[6, -4, 9, -7, 3]` points with `0.22` rotation
factor. An armed `.doneAnyway` card stays square and firm; its completion burst
runs once on the persisted summary, never on selection. An armed `.release`
preview uses `0.22` erosion; the settled release effect also waits for the batch
receipt. One act is one batch, one receipt, and one canonical Undo.

Rhythm copy is consistency-first: `9 of 14 days · 1 day running`. Both facts use
the same typography in one wrapping label. No red, flame, loss, streak-rescue, or
recovery language is permitted. XP is absent from Home and Loop celebrations.
The app schedules one configurable gentle evening nudge — “Whenever you're ready
— see how the day went and carry what's left.” — suppresses it after a successful
close, and schedules no later follow-up.

Morning commitment remains explicit until 14 eligible local days exist. The
local `DayOpenProposalSignalStore` records edited/unedited proposal evidence only
after scenario apply succeeds, keyed by receipt ID; a failed sidecar write is
unknown evidence and cannot fail or roll back the commitment. Reports join only
currently applied receipts, so Undo stops contributing automatically and a
missing sidecar never means “edited.” If fewer than 40% of eligible days were
opened before 11:00, the resolver switches to zero-interaction confirmation: it
writes an empty `dayOpen` receipt without silently changing tasks. Proposal
ranking remains unchanged until known evidence is sufficient.

Under Reduce Motion, proposal lean is removed, knot and liquid changes settle
without travel, deck exits use the reduced transition, and one-shot erosion or
burst feedback crossfades or snaps. Labels, direction alternatives, receipt
timing, and Undo behavior do not change. Increase Contrast strengthens the
semantic hairline around knots, cards, and focus; effects never carry required
meaning by themselves.

### Overdue Rescue

Overdue Rescue is one canonical decision deck entered from Home, Plan, Insights,
the Day Compass, or universal input. `OverdueRescueLaunchCoordinator` owns the
launcher phase, active plan, overdue and Day-Rescue task maps, reference date,
batch run identity, and presentation context. Presentation hosts receive task
edit, delete, restore, apply, Undo, planning-metadata, tracking, retry, and
dismiss services explicitly; no root view reaches through a legacy controller.

`RescueBatchApplier` is the mutation boundary. It resolves current task rows,
rejects missing/completed/subtask/stale or no-longer-eligible work, builds the
validated proposal, then proposes, confirms, and applies in order. Transactional
apply rollback remains authoritative. A planning-metadata failure compensates
through the same batch Undo path exposed to the person. One safe-fix act remains
one run and one Undo; a failed compensation is named and remains retryable.

The `.universalInputDayRescue` variant shares the deck, physics, controls, and
service boundary while using only today's replan task map and its own persisted
session scope. Its genuine empty state says that nothing needs rescuing today;
repository failure, stale work, retry, and an exhausted deck remain separate
states. Launch failure stays mounted with Retry and Dismiss. Closing a completed
run clears presentation but does not erase the durable run identity needed by
Undo.

### Guided Routine runner

Guided Routines use one full-screen presentation route. Interactive dismissal is
disabled because presentation dismissal is not a domain command. Running, paused,
and interrupted states must all expose explicit End. Abandonment is confirmed and
uses the canonical routine mutation. Continue/Resume is primary; Pause and Skip are
secondary.

Routine step motion uses existing clay surfaces and a bounded card-swap transition.
Reduce Motion crossfades. Semantic typography and persisted run state must survive
backgrounding, restoration, and accessibility sizes.

### Signature-effect governance

The Swift registry and Metal source are one atomic contract:

- every registry name has exactly one `[[ stitchable ]]` declaration;
- every declaration appears in the registry;
- the expected count is 18;
- all functions live in
  `LifeBoard/View/Effects/LifeBoardSignatureEffects.metal`;
- `LifeBoardSignatureShaders.warmUp()` is all-or-nothing;
- one misspelled or orphaned function disables the signature set and must fail a
  unit test.

Mount effects on the plane whose state changed. `triageSettle` belongs below the
Inbox deck; `daypartBloom` belongs at the root atmosphere boundary;
`chartRevealSweep` belongs to chart marks, not labels or evidence. All effects
except static `paperGrain` are bounded and return to a fully settled state.

Fallback order is semantic SwiftUI state first, then a short token-based tint
crossfade. Reduce Motion, Reduce Transparency, Low Power Mode, thermal pressure,
inactive scenes, unsupported Catalyst paths, and shader failure must never remove
content, delay input, or change layout.

### Accessibility and automation contracts

Feature-qualified accessibility identifiers are part of the component API. Prefer
stable roles such as `home.addToHome.<destination>`,
`lifeThread.composer.tool.<type>`, `track.lens.<lens>`, and
`home.widget.edit.<placementID>` over localized labels or hierarchy positions.

At accessibility text sizes, use adaptive layout before truncation:

- collapse multi-column card grids;
- switch fixed horizontal headers to intrinsic vertical layouts;
- keep safe-area commit actions reachable;
- reserve measured floating chrome;
- preserve native control traits;
- allow lens controls to scroll.

Gestures, color, transparency, scenic art, and shader output are all optional
enhancements. The complete task must remain understandable and operable without
them.

## Do's and Don'ts

- Do use semantic tokens and named components; do not add direct colors, ad-hoc shadows, raw global font sizes, or direct material calls in feature code.
- Do make state and hierarchy perceivable with text, shape, and accessibility semantics; do not communicate status through color or animation alone.
- Do honor Reduce Motion, Reduce Transparency, Low Power Mode, thermal pressure, scene activity, and Catalyst fallbacks through `LifeBoardMotionPolicy`.
- Do use only the approved signature effects: `daypartBloom`, `evaInkReveal`, `journalMediaReveal`, `memoryDevelopReveal`, `fastingEmberRing`, `healthSyncPulse`, `vitalOrbWarp`, `clayPressBloom`, `daypartCrossDissolve`, `completionBurst`, `contextLens`, `chartRevealSweep`, `liquidGlassRefract`, `cardMorphWarp`, `paperGrain`, `dissolveAway`, `triageSettle`, and `firstLight`. `contextLens` is a 380 ms control/background-plane handoff with an 8 pt maximum sample offset, and is the app's only touch ripple — do not add a second one. `triageSettle` mounts only on the plane beneath the Inbox deck after a persisted skip or committed review direction; `daypartBloom` mounts only at the root atmosphere boundary when the semantic daypart changes. Neither may touch readable foreground content. `paperGrain` is the single exception to the one-shot rule: it is static and never animates. Every other effect is one-shot and interaction-, threshold-, or boundary-bound; do not turn any of them into ambient loops. Do not distort text, charts, evidence, or sensitive content — per-glyph *displacement* under `TextRenderer` is permitted at up to 6 pt because layout, wrapping, and semantics stay with SwiftUI, but scaling, shearing, rotating, or blurring text is not.
- Do add new stitchable functions to `LifeBoard/View/Effects/LifeBoardSignatureEffects.metal`; do not create a new `.metal` file. `check-xcode-target-membership.sh` only scans `.swift`, so an orphaned `.metal` passes CI and then fails `LifeBoardSignatureShaders.warmUp()`, which is all-or-nothing and disables *every* signature effect at runtime.
- Do use SF Symbols or curated assets for UI icons; do not use emoji as interface icons.
- Do preserve privacy: never reveal journal text, audio, media, embeddings, or private health content in diagnostics, widgets, or system previews.
- Do distinguish explicit zero, no record, setup required, stale, denied, locked, offline, and error; do not collapse them into one empty state.
- Do use one dominant action per decision surface; do not place multiple equal-weight calls to action in the same visual group.
- Do keep external calendar items read-only and visually distinct from LifeBoard-owned work.
- Do preserve settled streaming text and user drafts on Stop/failure; do not clear recoverable work to simplify presentation state.
