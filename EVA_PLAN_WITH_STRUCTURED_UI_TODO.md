# EVA Plan With Structured-Style UI TODO

- [x] Add EVA text planning feature flags and visual style adapter.
- [x] Extend assistant schema v3 with schedule-aware commands.
- [x] Add proposal card display models and selected-card compilation.
- [x] Build Structured-style EVA home, composer, processing, and review UI.
- [ ] Add inline timeline diff preview hooks.
- [x] Wire strict gates, selected apply, undo, and applied-run history foundation.
- [ ] Add full unit/UI coverage for schema, cards, selection, apply, undo, and review UI.

## EVA Plan Generation Parse Recovery

- [x] Use a clean one-turn planner thread instead of prior chat transcript.
- [x] Tighten planner JSON prompt with schema v3 examples and ISO-8601 dates.
- [x] Add flexible envelope decoding for ISO-8601 model dates.
- [x] Add deterministic fallback for timed plans, inbox lists, simple edits, and no-op late-day repair.
- [x] Avoid surfacing parse failures when fallback can produce review cards.
- [x] Verify focused planner tests.
- [x] Verify full iPhone 16 simulator build.
