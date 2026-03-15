# V2 E-H Release Gate Checklist

Release tag promotion is blocked until every gate below is green.

## Required Gates

1. `iOS CI` workflow is green:
- legacy runtime guardrails pass
- V2 fail-closed guardrails pass
- `TaskerTests` pass
- benchmark artifact generated
- balanced SLO thresholds pass (`p95` Home/Project <= 250ms, `p95` Search <= 300ms, `p99` <= 600ms)

2. `CloudKit Two-Device Smoke` workflow is green for release branch:
- runbook file present at `docs/cloudkit-two-device-smoke.md`
- evidence file exists at `docs/cloudkit-smoke-evidence/latest.md`
- evidence includes Test Matrix, Device A timeline, Device B timeline, and final result

3. Flow-Next tooling gate passes:
- `.flow/bin/flowctl` exists and executable
- `scripts/verify_flowctl.sh` passes in CI and local bootstrap
- CI must use official binary install (`FLOWCTL_DOWNLOAD_URL`) with checksum (`FLOWCTL_DOWNLOAD_SHA256`)
- shim is forbidden in CI

4. Runtime safety gate passes:
- V2 create/sync/assistant paths fail closed when dependencies are missing
- no production compile path to legacy `DependencyContainer.shared` runtime

5. Kill-switch regression tests pass:
- `v2Enabled`
- reminders sync
- assistant apply
- assistant undo
- reminders background refresh behavior

6. AI behavior gate passes:
- plan/apply/undo smoke evidence available: proposal card -> confirm/apply -> undo
- ask mode verified non-mutating (no pipeline mutation path)
- semantic fallback behavior verified (`assistant_semantic_fallback_lexical` path)
- daily brief notification open verified with seeded chat behavior
- overdue triage apply-all verified to use pipeline mutation contract
- bounded freeform chat smoke verified on weakest supported model with:
  - direct answer to `What tasks should I focus on`
  - direct answer to `How was my last week?`
  - no persona self-introduction loops
  - no repeated-token tails
  - no visible template/control markers

## Workflow-to-Gate Traceability

| Gate | Workflow | Script/Check Surface |
| --- | --- | --- |
| iOS runtime guardrails | `.github/workflows/ios.yml` (`guardrails`) | `scripts/validate_legacy_runtime_guardrails.sh`, runtime grep checks |
| iOS unit tests | `.github/workflows/ios.yml` (`unit-tests`) | `xcodebuild ... -only-testing:TaskerTests` |
| Performance gate | `.github/workflows/ios.yml` (`perf-gate`) | `scripts/perf_seed_v3.swift`, in-workflow SLO assertions |
| CloudKit smoke docs/evidence gate | `.github/workflows/cloudkit-smoke.yml` | `scripts/validate_cloudkit_smoke_evidence.sh` + runbook existence |
| Token/logging UI guardrails (supporting quality gate) | `.github/workflows/design-token-law.yml` | `scripts/token-law-guardrails.sh`, `scripts/check-no-print-logs.sh` |
| flowctl tooling gate | `.github/workflows/ios.yml` (`guardrails`) | `scripts/install_flowctl.sh`, `scripts/verify_flowctl.sh` |
| AI behavior gate | iOS CI + manual/automated smoke evidence | release evidence rows in `docs/architecture/v3-runtime-cutover-todo.md`, including bounded freeform weak-model smoke |

## Release Evidence Bundle

For each release candidate, attach:
1. CI run URL for `iOS CI`.
2. CI run URL for `CloudKit Two-Device Smoke`.
3. benchmark artifact `build/benchmarks/v2_readmodel.json`.
4. smoke evidence markdown path and commit SHA.
5. AI evidence references from `docs/architecture/v3-runtime-cutover-todo.md`.
6. weakest-model freeform chat smoke evidence for bounded prompt path.

## Block Criteria

1. Any red gate above blocks release.
2. Any missing evidence artifact blocks release.
3. Any unresolved P0/P1 issue from E-H test matrix blocks release.
4. Missing AI behavior evidence blocks release when AI/LLM code or flags changed.
5. Any conflicting AI contract statements between architecture and release docs blocks release until reconciled.

## Related Docs

- CloudKit smoke runbook: `docs/cloudkit-two-device-smoke.md`
- Latest smoke evidence pointer: `docs/cloudkit-smoke-evidence/latest.md`
- CI guardrail inventory: `docs/operations/ci-release-and-guardrails.md`
- LLM runtime contracts: `docs/architecture/llm-assistant-stack-v2.md`
- AI handbook: `docs/architecture/llm-feature-integration-handbook.md`
