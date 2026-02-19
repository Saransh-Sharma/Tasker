# V2 Hard-Cut Execution TODO (Archived)

This file is retained for historical context only.
Active release gating moved to `docs/architecture/v3-runtime-cutover-todo.md`.

## Archive Summary

- V2-to-V3 runtime cutover and bridge removals were completed.
- Core Data model/version naming was moved to `TaskModelV3`.
- Legacy runtime guardrails were introduced and are now part of release verification.
- Unit test baseline (`TaskerTests`) was stabilized at migration handoff.

## Historical Milestones (Completed)

- [x] Remove legacy task protocol/usecase/repository bridge surfaces
- [x] Canonicalize task mutations on `TaskDefinition` contracts
- [x] Move runtime bootstrap to V3 keys and container naming
- [x] Remove Fluent-only dependency/runtime paths
- [x] Add and pass runtime guardrail checks
- [x] Stabilize core build and unit-test gates after migration

## Non-Gating Note

Do not add new TODO items to this file.
Track all current migration and release evidence in:
- `docs/architecture/v3-runtime-cutover-todo.md`
