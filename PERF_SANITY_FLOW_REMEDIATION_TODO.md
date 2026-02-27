# Sanity-Flow Performance Remediation TODOs

- [x] Add LLM prewarm/context strategy feature flags with safe defaults.
- [x] Introduce chat runtime session lifecycle (`acquire/release/idle unload`).
- [x] Remove eager startup prewarm path and move to adaptive on-demand flow.
- [x] Bound chat context projection with per-slice budgets and compact payload mode.
- [x] Add prompt-history truncation/recap budgeting.
- [x] Virtualize transcript rendering (`LazyVStack`) and reduce sort churn.
- [x] Coalesce Home reload fan-out with debounced batch reloading.
- [x] Remove duplicate Home startup loads from controller bind path.
- [x] Lower broad read/query ceilings and add Core Data fetch batching.
- [x] Add/update targeted LLM and prompt budget tests.
- [x] Build verification on iOS Simulator destination.

## Chat Stability v2

- [x] Harden generation cancel during prepare/load and add extra cancel checkpoints.
- [x] Keep stop control active for pre-stream phases (context/prepare) via generation-task tracking.
- [x] Prevent blank assistant messages on canceled/empty generation outputs.
- [x] Isolate transcript rows from live evaluator churn to reduce per-token re-render work.
- [x] Coalesce superseded Home analytics refresh triggers with debounce.
