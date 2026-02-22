# Tasker UX Design System Architecture (V2)

**Last validated against code on 2026-02-21**

## Purpose + Scope

This document is the canonical architecture reference for Tasker's shipped Calm Clarity design system.
It is written for engineers and design implementers who need code-verifiable contracts for tokens, themes, adapters, motion, accessibility, and migration behavior.

### In Scope

- Shipped V3 token system in `To Do List/DesignSystem/*`
- Theme and migration behavior in `To Do List/DesignSystem/TaskerTheme.swift`
- SwiftUI and UIKit adapter access paths
- Accessibility and motion constraints baked into token defaults and reusable components
- Validation ownership (unit and UI tests)

### Out of Scope

- Product roadmap decisions
- Localization rollout strategy
- Domain logic or persistence schema redesign

## Source Anchors (Code-Verifiable)

- `To Do List/DesignSystem/TaskerTokens.swift`
- `To Do List/DesignSystem/TaskerTheme.swift`
- `To Do List/DesignSystem/ColorTokens.swift`
- `To Do List/DesignSystem/TypographyTokens.swift`
- `To Do List/DesignSystem/SpacingTokens.swift`
- `To Do List/DesignSystem/CornerTokens.swift`
- `To Do List/DesignSystem/ElevationTokens.swift`
- `To Do List/DesignSystem/GradientTokens.swift`
- `To Do List/DesignSystem/TaskerAnimations.swift`
- `To Do List/DesignSystem/SwiftUI+TokenAdapters.swift`
- `To Do List/DesignSystem/UIKit+TokenAdapters.swift`
- `To Do List/DesignSystem/TaskerTheme+SwiftUI.swift`
- `To Do List/Domain/Models/TaskPriorityConfig.swift`
- `To Do ListTests/DesignSystem/ColorTokenGenerationTests.swift`
- `To Do ListTests/DesignSystem/TypographyTokenTests.swift`
- `To Do ListTests/DesignSystem/SpacingElevationCornerTests.swift`
- `To Do ListTests/DesignSystem/TaskerThemeManagerTests.swift`
- `To Do ListUITests/Tests/Secondary/ThemeAndAppearanceTests.swift`
- `To Do ListUITests/AddTaskSuggestionFlowTests.swift`

## Design Principles

1. Calm Clarity over decorative complexity.
2. Readability first: semantic roles, high-contrast text, predictable hierarchy.
3. Motion is subtle and bounded, never attention-grabbing by default.
4. Color is never the sole carrier of critical meaning.
5. Tokenized access is mandatory; avoid hardcoded style literals in feature code.

## Token Architecture

`TaskerTokenContainer` is the root contract and exposes all token groups through a single entrypoint (`TaskerTokens`).

### Token Container Composition

| Group key | Concrete type |
| --- | --- |
| `color` | `TaskerColorTokens` |
| `typography` | `TaskerTypographyTokens` |
| `spacing` | `TaskerSpacingTokens` |
| `elevation` | `TaskerElevationTokens` |
| `corner` | `TaskerCornerTokens` |
| `interaction` | `TaskerInteractionTokens` |
| `iconSize` | `TaskerIconSizeTokens` |
| `motion` | `TaskerMotionTokens` |
| `transition` | `TaskerTransitionTokens` |
| `priorityIndicator` | `TaskerPriorityIndicatorTokens` |

### Interaction Tokens (`TaskerInteractionTokens`)

| Token | Default |
| --- | --- |
| `minInteractiveSize` | `44` |
| `focusRingWidth` | `2` |
| `focusRingOffset` | `2` |
| `pressScale` | `0.97` |
| `pressOpacity` | `0.92` |
| `reducedMotionPressScale` | `1.0` |

### Icon Size Tokens (`TaskerIconSizeTokens`)

| Token | Default |
| --- | --- |
| `small` | `16` |
| `medium` | `20` |
| `large` | `24` |
| `hero` | `32` |

### Motion Tokens (`TaskerMotionTokens`)

| Token | Default |
| --- | --- |
| `gradientCycleDuration` | `15s` |
| `gradientCycleRandomness` | `2s` |
| `gradientHueShiftDegrees` | `8` |
| `gradientSaturationShiftPercent` | `5` |
| `gradientOpacityDeltaMax` | `0.08` |
| `gradientCurve` | `easeInOut` |
| `maxAnimatedGradientLayers` | `2` |
| `maxAnimatedElementsPerView` | `2` |
| `reduceMotionUsesStaticGradient` | `true` |
| `reduceMotionUsesOpacityPressFeedback` | `true` |

### Transition Tokens (`TaskerTransitionTokens`)

| Token | Default |
| --- | --- |
| `pushPopDuration` | `0.30s` |
| `modalDuration` | `0.35s` |
| `sheetSpringDamping` | `0.85` |
| `reduceMotionCrossfadeDuration` | `0.20s` |

### Priority Indicator Tokens (`TaskerPriorityIndicatorTokens`)

| Priority | `symbolName` | `shortLabel` | `accessibilityLabel` |
| --- | --- | --- | --- |
| max | `exclamationmark.triangle.fill` | `Max` | `Maximum priority` |
| high | `arrow.up.circle.fill` | `High` | `High priority` |
| low | `arrow.down.circle.fill` | `Low` | `Low priority` |
| none | `minus.circle` | `None` | `No priority` |

### Copy Taxonomy (`TaskerCopy`)

`TaskerCopy` centralizes string categories:

- `TaskerCopy.EmptyStates`
- `TaskerCopy.Actions`
- `TaskerCopy.Confirmations`
- `TaskerCopy.Errors`
- `TaskerCopy.Onboarding`
- `TaskerCopy.Assistant`

## Theme System

### Curated Themes (3)

| Theme | Subtitle | Accent Base | Pressed | Wash | Secondary Base |
| --- | --- | --- | --- | --- | --- |
| Harbor | Calm and trustworthy | `#0D9488` | `#0F766E` | `#CCFBF1` | `#14B8A6` |
| Horizon | Focused and productive | `#3B82F6` | `#2563EB` | `#DBEAFE` | `#60A5FA` |
| Canopy | Grounded and natural | `#16A34A` | `#15803D` | `#DCFCE7` | `#22C55E` |

### Accent Ramp Generation (`TaskerAccentRamp`)

Ramps are generated from a base color in HSL space and produce:

- `accent050`
- `accent100`
- `accent400`
- `accent500`
- `accent600`
- `onAccent`
- `ring`

The generator clamps saturation/lightness to keep derived ramps usable across light/dark contexts.

### Persistence + Migration Contract

- Selected theme key: `selectedThemeIndex`
- Migration key: `selectedThemeIndexMigrationVersion`
- Current migration version: `2`

Migration path:

1. Legacy 28-theme index -> v1 9-theme index (`legacyToV1IndexMap`)
2. v1 9-theme index -> v2 3-theme index (`v1ToV2IndexMap`)

Verbatim 9 -> 3 map:

| v1 index | v2 index |
| --- | --- |
| `0` | `0` |
| `1` | `1` |
| `2` | `0` |
| `3` | `1` |
| `4` | `2` |
| `5` | `0` |
| `6` | `0` |
| `7` | `1` |
| `8` | `1` |

## Color System

Semantic roles are exposed via `TaskerColorRole` and resolved through `TaskerColorTokens.color(for:)`.

### Calm Neutral Palette

| Role | Light | Dark |
| --- | --- | --- |
| `bgCanvas` | `#F8FAFB` | `#0F1114` |
| `bgElevated` | `#FFFFFF` | `#1A1D22` |
| `surfacePrimary` | `#FFFFFF` | `#22262D` |
| `surfaceSecondary` | `#F1F4F7` | `#2A2E36` |
| `surfaceTertiary` | `#E7EDF3` | `#323844` |
| `textPrimary` | `#111827` | `#F1F4F7` |
| `textSecondary` | `#4B5563` | `#9CA3AF` |
| `textTertiary` | `#9CA3AF` | `#6B7280` |

### Status + Priority Semantics

| Semantic | Hex |
| --- | --- |
| `statusSuccess` | `#16A34A` |
| `statusWarning` | `#D97706` |
| `statusDanger` | `#DC2626` |
| `priorityMax` | `#DC2626` |
| `priorityHigh` | `#EA580C` |
| `priorityLow` | `#2563EB` |
| `priorityNone` | `#6B7280` |

### Non-Color Requirement

Priority and status indicators must pair color with icon and/or label.
This is enforced through `TaskerPriorityIndicatorTokens` and reflected in `TaskPriorityConfig.Priority.indicatorSymbolName`.

## Typography, Spacing, Corner, Elevation

### Typography (`TaskerTypographyTokens`)

| Style | TextStyle | Point | Weight | Max Point |
| --- | --- | --- | --- | --- |
| `display` | `largeTitle` | `34` | semibold | `44` |
| `title1` | `title1` | `28` | semibold | - |
| `title2` | `title2` | `22` | semibold | - |
| `title3` | `title3` | `18` | semibold | - |
| `headline` | `headline` | `17` | semibold | - |
| `body` | `body` | `17` | regular | - |
| `bodyEmphasis` | `body` | `17` | medium | - |
| `callout` | `callout` | `15` | regular | - |
| `caption1` | `caption1` | `13` | medium | - |
| `caption2` | `caption2` | `12` | regular | - |
| `button` | `body` | `17` | semibold | - |
| `buttonSmall` | `callout` | `15` | semibold | - |

Dynamic type scaling is mandatory via `UIFontMetrics`.

### Spacing (`TaskerSpacingTokens`)

Core scale:
`2, 4, 8, 12, 16, 20, 24, 32, 40`

Layout recipes:

- `screenHorizontal = 16`
- `cardPadding = 16`
- `cardStackVertical = 10`
- `sectionGap = 24`
- `listRowVerticalPadding = 10`
- `titleSubtitleGap = 6`
- `chipSpacing = 8`
- `buttonHeight = 48`

### Corner (`TaskerCornerTokens`)

Core:
`r0=0`, `r1=8`, `r2=12`, `r3=16`, `r4=24`, `pill=999`

Component mappings:

- `card = 16`
- `input = 12`
- `chip = 999`
- `bottomBar = 24`
- `modal = 24`

### Elevation (`TaskerElevationTokens`)

`e0` through `e3` define shadow/border/blur recipes.
Usage guidance:

- `e0`: flat surfaces
- `e1`: default card/container elevation
- `e2`: emphasized card/modal surfaces
- `e3`: top-most overlays requiring stronger separation

## Motion, Gradient, and Transition

### Animated Gradient Constraints

| Constraint | Contract |
| --- | --- |
| cycle duration | `15s ±2s` |
| hue shift | up to `±8` degrees |
| saturation shift | up to `±5%` |
| opacity drift | up to `0.08` |
| easing | `easeInOut` |
| max animated gradient layers | `2` |
| max animated elements per view | `2` |

### Accessibility Fallbacks

- Reduced motion uses static gradients.
- Press feedback can switch to opacity-based behavior.
- Reduced motion transition fallback is crossfade (`reduceMotionCrossfadeDuration`).

### Debug Toggle

- UserDefaults key: `tasker.design.gradientMotionDisabled`
- Purpose: allow QA to disable gradient motion without code changes.

## Adapter Contract

### SwiftUI Access Path

- `TaskerSwiftUITokens`
- `Color.tasker`
- `Font.tasker`
- `TaskerTheme.Colors`, `TaskerTheme.Typography`, `TaskerTheme.Spacing`, `TaskerTheme.CornerRadius`, `TaskerTheme.Interaction`
- Reusable components: `TaskerTextFieldStyle`, `TaskerChip`, `TaskerCard`

### UIKit Access Path

- `TaskerUIKitTokens`
- `UIColor.tasker`
- `UIFont.tasker`
- `UIView.applyTaskerElevation(_:)`
- `UIView.applyTaskerCorner(_:)`
- Reusable components: `TaskerTextField`, `TaskerChipView`, `TaskerCardView`
- Nav button contract: `TaskerNavButtonStyle`

### Single Access Path Rule

Feature code should consume design values through token adapters and helper components.
Avoid introducing hardcoded colors, font sizes, corner values, spacing constants, or motion timings.

## Component Recipes

### Text Field

- Use tokenized typography, surface, border, and focus-ring values.
- Enforce minimum touch target with `TaskerInteractionTokens.minInteractiveSize`.

### Chip

- Support both `tinted` and `filled` selection styles.
- Preserve icon/text contrast and min hit area.

### Card

- Use tokenized corner/elevation and semantic border states.
- Elevated and highlighted states should map to token levels, not ad-hoc styles.

### Navigation Button

- Use `TaskerNavButtonStyle` for context-aware emphasis and pressed state.
- Maintain minimum hit target from interaction tokens.

### Priority Indicator

- Always render color plus icon and label/accessibility text.
- Source symbols from `TaskerPriorityIndicatorTokens` or `TaskPriorityConfig`.

## Testing + Validation Map

### Unit Test Ownership

| Test file | Validates |
| --- | --- |
| `To Do ListTests/DesignSystem/ColorTokenGenerationTests.swift` | semantic palette generation and color contracts |
| `To Do ListTests/DesignSystem/TypographyTokenTests.swift` | typography scale and dynamic type expectations |
| `To Do ListTests/DesignSystem/SpacingElevationCornerTests.swift` | spacing/corner/elevation defaults |
| `To Do ListTests/DesignSystem/TaskerThemeManagerTests.swift` | theme count, migration path, persistence behavior |

### UI Test Ownership

| Test file | Validates |
| --- | --- |
| `To Do ListUITests/Tests/Secondary/ThemeAndAppearanceTests.swift` | theme propagation across major surfaces and settings contracts |
| `To Do ListUITests/AddTaskSuggestionFlowTests.swift` | task creation flow stability under redesigned tokens and components |

Doc drift signals:

- Token or migration code changes with no test update and no doc update.
- UI component contract changes that break theme/appearance or Add Task smoke paths.

## Maintenance Policy

1. Update this doc in the same PR as any `To Do List/DesignSystem/*` contract changes.
2. Keep all key statements code-verifiable with source anchors.
3. Preserve semantic naming over ad-hoc style descriptions.
4. Update the migration section whenever theme persistence or mapping logic changes.
5. Keep adapter contract examples aligned with actual helper APIs.

### PR Checklist (Design System Changes)

- [ ] Updated `docs/architecture/uxdesign-design-system-v2.md`
- [ ] Updated tests covering changed token/theme behavior
- [ ] Updated `docs/design/DESIGN_CHANGELOG.md`
- [ ] Verified no hardcoded style literals were added to feature code paths
