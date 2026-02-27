# XP Correctness + Analytics Performance V4 TODO

- [x] Add canonical post-commit ledger mutation notification + payload (`gamificationLedgerDidMutate`).
- [x] Emit ledger mutation from `GamificationEngine.recordEvent` after persistence paths (success + idempotent/no-op).
- [x] Route Home gamification state updates from ledger mutation payloads instead of early task mutation timing.
- [x] Route Insights updates from ledger mutation payloads with incremental projection updates.
- [x] Remove stale-read races by resetting gamification read context after each write completion.
- [x] Fix reflection UX no-op path: keep sheet open on `0 XP` and show explicit already-completed state.
- [x] Remove duplicate mutation triggers where canonical ledger mutation already covers refresh.
- [x] Avoid redundant post-focus/post-reflection gamification fetches (`loadDailyAnalytics(includeGamificationRefresh: false)`).
- [x] Add regression coverage for read-after-write freshness and ledger-mutation projection updates.
- [x] Add HomeViewModel regression coverage for ledger mutation notification state propagation.
- [x] Fix streak ordering in `GamificationEngine`: emit ledger mutation after streak update completes.
- [x] Add regression test verifying ledger mutation streak reflects post-update streak state.
- [ ] Full manual smoke audit: task completion XP, reflection first/second claim UX, insights tab values, top nav pie, widget snapshot freshness.
- [ ] Full UI perf audit on seeded data set (rapid tab switch + per-tab scroll + mutation burst).
