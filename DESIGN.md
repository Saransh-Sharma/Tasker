---
version: alpha
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
  on-surface-secondary: "#746757"
  on-surface-tertiary: "#877B68"
  outline: "#E9DFC6"
  outline-strong: "#CBBFA4"
  focus: "#5A3D1E"
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
  dark-outline: "#4A5470"
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
- Dark appearance is a designed warm-indigo composition from the adaptive Swift tokens, not a color inversion. Use semantic token roles rather than the literal values above when implementing UIKit or SwiftUI.

## Typography

Use Dynamic Type-backed system typography. SF Pro Rounded gives greetings, metrics, and friendly section emphasis their human warmth; SF Pro carries task content and long-form reading; SF Mono is only for aligned times, durations, progress, and compact metrics. Preserve the semantic role even when adaptive layout changes the point size. Never add a bundled web font or use raw fixed sizes in feature code.

The full hierarchy is display, screen title, section title, title, headline, body, strong/emphasis body, support, callout, metadata, caption, button, metric, and monospaced metadata. Use no more than three visibly competing levels in one local group. Long-form Journal and explanation text should remain readable at the user’s preferred size; dashboards must not shrink type to preserve a grid.

## Layout

Use the 2/4/8/12/16/20/24/32/40 pt rhythm. Phone content begins at the tokenized 20 pt horizontal margin; iPad uses the adaptive layout recipes rather than scaled phone geometry. Keep a minimum 44 pt hit target, reserve safe-area space for the dock and composer, and let accessibility sizes stack metadata/actions or scroll signal rails before truncating meaningful content.

Home stays open between modules so its atmosphere can breathe. A card is warranted only for one decision, one summary, or one independently movable widget. Task rows remain open and readable; Focus Now is the only deliberately dominant Home card.

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

## Do's and Don'ts

- Do use semantic tokens and named components; do not add direct colors, ad-hoc shadows, raw global font sizes, or direct material calls in feature code.
- Do make state and hierarchy perceivable with text, shape, and accessibility semantics; do not communicate status through color or animation alone.
- Do honor Reduce Motion, Reduce Transparency, Low Power Mode, thermal pressure, scene activity, and Catalyst fallbacks through `LifeBoardMotionPolicy`.
- Do use only the approved signature effects: `daypartBloom`, `evaInkReveal`, `journalMediaReveal`, `memoryDevelopReveal`, and `fastingEmberRing`. Do not add decorative loops, shimmer, or generic spring aliases.
- Do use SF Symbols or curated assets for UI icons; do not use emoji as interface icons.
- Do preserve privacy: never reveal journal text, audio, media, embeddings, or private health content in diagnostics, widgets, or system previews.
- Do distinguish explicit zero, no record, setup required, stale, denied, locked, offline, and error; do not collapse them into one empty state.
- Do use one dominant action per decision surface; do not place multiple equal-weight calls to action in the same visual group.
- Do keep external calendar items read-only and visually distinct from LifeBoard-owned work.
- Do preserve settled streaming text and user drafts on Stop/failure; do not clear recoverable work to simplify presentation state.
