# Concentric Onboarding Redesign TODO

- [x] Preserve the existing 14-step onboarding state machine and product journey.
- [x] Add LifeBoard-owned concentric transition primitives instead of a third-party dependency.
- [x] Keep the dimmed running onboarding video behind the redesigned screens.
- [x] Replace full-width primary onboarding CTAs with a floating liquid next control.
- [x] Verify the iOS app target builds after the redesign.
- [x] Re-run focused onboarding tests after the existing simulator/Core Data `repeatPattern` key-path crash is cleared.

## Darker Liquid Glass Color Pass

- [x] Darken the onboarding video backdrop consistently in light and dark mode.
- [x] Keep onboarding chrome text on a fixed dark-mode-style palette.
- [x] Increase concentric per-step color visibility.
- [x] Add native Liquid Glass treatment to concentric color field and transition pulse with fallbacks.
- [x] Build the iOS app target after the visual pass.
- [ ] Re-run focused onboarding checks after the existing simulator `basic_string(const char*) detected nullptr` crash is fixed.
