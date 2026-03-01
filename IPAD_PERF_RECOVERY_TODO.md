# iPad Performance Recovery TODO

- [x] Add iPad perf feature flags (`bottomBar`, `search`, `theme`, `llm`).
- [x] Add execution tracker for Trace 2 recovery work.
- [x] Refactor `HomeBottomBarState` to a single idle reveal scheduler.
- [x] Add stress coverage for bottom bar scheduler churn.
- [x] Add `SearchRefreshCoordinator` and route all search refresh through it.
- [x] Add revision-keyed caching and stale-result suppression in `LGSearchViewModel`.
- [x] Add theme token cache keyed by layout + traits.
- [x] Cache SwiftUI color token adapters to avoid repeated allocations.
- [x] Defer LLM prewarm to chat entry + idle delay, with cancellation on exit/background.
- [x] Stabilize keyboard focus transitions in home/add/chat surfaces.
- [x] Replace render-path dictionary rebuilds in home/search with memoized caches.
- [x] Run targeted test suite and simulator build verification.

## Trace 3 Recovery

- [x] Add Trace 3 iPad perf feature flags (`primary_surface`, `search_focus`, `animation_trim`, `render_memo`, `coredata_snapshot`).
- [ ] Keep the iPad primary home surface mounted across `Tasks`, `Search`, and `Analytics`.
- [ ] Skip iPad search auto-focus on tab switches and avoid redundant search refreshes.
- [ ] Trim iPad-only home appearance animations that replay during primary destination switching.
- [ ] Memoize task row / section derived state and today-layout composition.
- [ ] Cache weekly calendar formatters and reduce day-cell rebuild churn.
- [ ] Replace hot-path Core Data task mapping KVC loops with snapshot mapping.
- [ ] Reuse the existing `UIHostingController` when remounting the home shell.
- [ ] Run focused tests and a new iPad sanity build/profile pass.
