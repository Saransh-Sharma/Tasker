# EVA Activation Redesign TODO

## Foundation

- [x] Retune the shared activation scaffold with compact top bar, tighter spacing rhythm, and a single subtle background gesture
- [x] Collapse duplicate onboarding chrome into the native green nav bar with one title and one progress bar
- [x] Add reusable onboarding components for section cards, chips, collapsed note fields, goals, install progress, and recovery
- [x] Extend activation state/config models for retry, fallback, recovery, and first-win chat customization

## Screens

- [x] Rework Meet Eva hero, trust framing, and sticky CTA treatment
- [x] Expand Meet Eva into a full-bleed hero on phone, enlarge it on regular layouts, and remove intro-only ambient decoration
- [x] Convert Quick Sync into lightweight adaptive sections with collapsed notes
- [x] Replace raw goals rows with committed goal chips and a live review card
- [x] Tighten mode choice cards and make the install CTA selection-specific
- [x] Redesign Wake Eva install with clearer progress, mode-consistent copy, and warm expressive motion
- [x] Add a dedicated blocking recovery step for install failures

## First Win

- [x] Turn activation chat into a dedicated first-win handoff with hidden utility chrome
- [x] Recommend the best first prompt, limit visible starters, and collapse onboarding coaching after first success

## Verification

- [x] Update unit coverage for activation state persistence, retry/fallback, and completion
- [x] Update UI coverage for the activation flow, recovery, and first-win handoff
- [ ] Run targeted verification and fix regressions
  Blocked: `ChatPlanApplyUndoTests` now runs, but all four UI checks currently skip because the chat entry point is not reachable with the current accessibility identifiers in simulator automation. Owner: Saransh. Due: 2026-03-20.
