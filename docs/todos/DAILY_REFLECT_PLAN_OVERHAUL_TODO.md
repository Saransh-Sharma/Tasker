# Daily Reflect & Plan Overhaul TODO

- [ ] Add daily reflection domain models, enums, and editable plan state
- [ ] Add daily reflection store protocol and UserDefaults implementation
- [ ] Upgrade daily reflection completion APIs to explicit-date semantics
- [ ] Add target resolution, snapshot builder, plan suggestion, and save orchestration use cases
- [ ] Wire new dependencies into containers and coordinator
- [ ] Replace Home reflection eligibility with entry state and draft module support
- [ ] Replace old daily reflection sheet with new Reflect & Plan flow
- [ ] Retarget nightly notification route to the new flow
- [ ] Add logic and UI coverage for target resolution, save flow, and Home entry rendering
- [ ] Run focused tests and fix regressions
- [ ] Replace reflection load path with phased core/optional coordinator
- [ ] Add targeted daily reflection task projection to avoid broad task windows
- [ ] Make calendar plan building optional, timed, and off-main
- [ ] Fix focus-window crash when hard stop precedes a free window
- [ ] Convert Reflect & Plan screen from spinner gating to partial render
- [ ] Add load-state, timeout, cancellation, and performance regression coverage

## Compact recap follow-up

- [x] Simplify Reflect & Plan into recap, plan, and collapsed optional context
- [x] Add compact reflection preview payloads for Home and reflection flow recap
- [x] Add focused tests for compact recap ordering, narrative copy, and entry-state equality
