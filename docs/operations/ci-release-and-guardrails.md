# CI, Release, and Guardrails

Last updated: 2026-02-21

This doc maps release requirements to concrete CI workflows and scripts.

Primary sources:
- `.github/workflows/ios.yml`
- `.github/workflows/cloudkit-smoke.yml`
- `.github/workflows/design-token-law.yml`
- `scripts/validate_legacy_runtime_guardrails.sh`
- `scripts/validate_cloudkit_smoke_evidence.sh`
- `scripts/install_flowctl.sh`
- `scripts/verify_flowctl.sh`
- `scripts/check-no-print-logs.sh`
- `scripts/token-law-guardrails.sh`

## CI Topology

```mermaid
flowchart TD
    PR["Pull Request / Push"] --> IOS[".github/workflows/ios.yml"]
    PR --> DESIGN[".github/workflows/design-token-law.yml"]
    REL["release/** push/PR or manual"] --> CK[".github/workflows/cloudkit-smoke.yml"]

    IOS --> G1["Runtime guardrails"]
    IOS --> G2["Unit tests"]
    IOS --> G3["Perf gate + benchmark artifact"]
    CK --> G4["Smoke evidence validation"]
    DESIGN --> G5["Token law + print guardrails"]
```

## Workflow Inventory

| Workflow | Trigger | Core Jobs | Blocking Outputs |
| --- | --- | --- | --- |
| `.github/workflows/ios.yml` | PR + push (`main/master/develop/fn-*`) | `guardrails`, `unit-tests`, `perf-gate` | runtime grep checks, `TaskerTests`, `build/benchmarks/v2_readmodel.json`, balanced SLO |
| `.github/workflows/cloudkit-smoke.yml` | `release/**` PR/push + manual dispatch | `smoke-evidence` | runbook existence + evidence markdown validity |
| `.github/workflows/design-token-law.yml` | PR + push | `token-law` | token/lint/logging guardrails |
| `.github/workflows/main.yml` | PR review automation | codeball review | non-architecture review automation |

## Script Guardrails Map

| Script | Policy Intent | Fails When |
| --- | --- | --- |
| `scripts/validate_legacy_runtime_guardrails.sh` | Prevent runtime fallback to legacy DI/screen wiring and enforce assistant mutation path constraints | legacy build graph/storyboard/singleton references appear, or chat-layer mutation bypass patterns appear |
| `scripts/validate_cloudkit_smoke_evidence.sh` | Ensure release smoke evidence is complete and non-placeholder | required sections/PASS-FAIL fields missing or placeholders remain |
| `scripts/install_flowctl.sh` | Enforce official flowctl binary in CI, controlled local shim fallback | CI missing URL/checksum or fallback misuse |
| `scripts/verify_flowctl.sh` | Verify flowctl binary is present/executable and CI-safe | missing binary, broken version output, disallowed shim in CI |
| `scripts/check-no-print-logs.sh` | Block direct `print()` in app source | `print(` appears in production app swift files |
| `scripts/token-law-guardrails.sh` | Enforce design token and style guardrails in UI modules | disallowed color/font/shadow patterns detected |

## Release Evidence Flow

```mermaid
sequenceDiagram
    participant CI as iOS CI
    participant PERF as Perf Gate
    participant SMOKE as CloudKit Smoke Workflow
    participant DOC as Smoke Evidence Doc
    participant RG as Release Gate Doc
    participant AI as AI Runtime Evidence

    CI->>PERF: generate v2_readmodel.json
    PERF-->>CI: upload benchmark artifact
    SMOKE->>DOC: validate evidence markdown content
    DOC-->>SMOKE: PASS/FAIL structured evidence
    CI->>AI: build + guardrail + AI smoke evidence
    AI->>RG: proposal/apply/undo + ask-mode + semantic fallback checks
    CI->>RG: provide CI URL + artifacts
    SMOKE->>RG: provide smoke URL + evidence path
```

## AI Validation Lane (Release Evidence)

For any release that includes AI/LLM changes, collect and attach:
1. Build evidence (`xcodebuild ... build`) and guardrail pass evidence.
2. Chat plan/apply/undo smoke evidence with run lifecycle checkpoints.
3. Ask-mode non-mutation evidence.
4. Semantic fallback evidence (`assistant_semantic_fallback_lexical` path) when embedding unavailability is simulated or observed.
5. Daily brief open/deep-link evidence (`assistant_daily_brief_opened` and seeded chat behavior).
6. Bounded freeform weak-model smoke evidence showing:
   - compact prompt path stayed within bounded budgets,
   - no self-introduction loop,
   - no repeated-token tail,
   - no visible template/control markers,
   - direct answers for both forward-looking and retrospective prompts.

## Release Evidence Checklist

| Artifact | Required Source |
| --- | --- |
| iOS CI run URL | `.github/workflows/ios.yml` |
| CloudKit smoke run URL | `.github/workflows/cloudkit-smoke.yml` |
| Benchmark snapshot | `build/benchmarks/v2_readmodel.json` |
| Smoke evidence markdown | `docs/cloudkit-smoke-evidence/latest.md` |
| AI runtime validation notes | `docs/release-gate-v2-efgh.md` + `docs/architecture/v3-runtime-cutover-todo.md` evidence rows |

## Cross-Links
- Release criteria: `docs/release-gate-v2-efgh.md`
- Runtime AI contracts: `docs/architecture/llm-assistant-stack-v2.md`
- AI handbook: `docs/architecture/llm-feature-integration-handbook.md`
- Smoke runbook: `docs/cloudkit-two-device-smoke.md`
- Docs index: `docs/README.md`
