# Design Changelog

## 2026-02-21 - Canonical UX design system architecture doc published
- Published `docs/architecture/uxdesign-design-system-v2.md` as the canonical implementation-facing source of truth for:
  - token architecture and defaults
  - theme system and migration behavior
  - color, typography, spacing, corner, elevation, motion, and transition contracts
  - SwiftUI/UIKit adapter access paths
  - component recipe and accessibility rules
  - validation ownership and maintenance policy
- Documentation contract established: changes in `To Do List/DesignSystem/*` require synchronized updates to the architecture UX design doc.

## 2026-02-21 - Pre-overhaul baseline
- Captured redesign scope and baseline debt for Calm Clarity overhaul.
- Identified major debt clusters:
  - Warm neutral ramp and overly luxe contrast profile not aligned with calm utility goals.
  - Nine accent themes with legacy mapping complexity and inconsistent personality.
  - Color-only priority signaling in several compact contexts.
  - Legacy storyboard tabs (`Inbox`, `Week`, `Upcoming`) still using placeholder styling.
  - Inconsistent microcopy tone and casing across Home/Add Task/Search/LLM.

## 2026-02-21 - Calm Clarity redesign v2 (in progress)
- Planned token architecture expansion:
  - Interaction tokens (hit targets, focus ring, press fallback)
  - Icon size tokens
  - Motion/transition tokens
  - Priority indicator token mapping (icon + label + color)
- Planned theme architecture change from 9 themes to 3 curated themes with explicit 9 -> 3 migration map and migration epoch bump.
- Planned motion constraints for subtle animated gradients with reduced-motion fallback rules and performance guards.
- Planned screen-level overhaul for Home, Add Task, Search, Settings, Assistant, Task Detail/Analytics, and legacy storyboard surfaces.
