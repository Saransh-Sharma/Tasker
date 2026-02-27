# Analytics Performance Remediation TODOs

- [x] 1) Isolate analytics recomposition surface in Home
- [x] 2) Refactor Insights refresh policy to lazy per-tab with event-driven in-flight guards
- [x] 3) Coalesce XP mutation refreshes (debounced)
- [x] 4) Move gamification read IO off main thread and make reads non-destructive
- [x] 5) Fix weekly tab diff identity and micro-inefficiencies
- [x] 6) Replace geometry-heavy progress/bar layouts with fixed-cost layouts
- [x] 7) Guard Home preference writes and remove non-essential height animations
- [x] 8) Add accessibility/testability hooks for insights performance
- [x] 9) Add focused regression + perf tests
- [x] 10) Build and build-for-testing verification
