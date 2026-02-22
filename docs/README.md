# Tasker Documentation Hub

Last updated: 2026-02-21

This directory is the canonical home for technical architecture, operations, release runbooks, and archived legacy docs.

## Doc Topology

```mermaid
flowchart TD
    ROOT["README.md (repo root)"] --> DOCS["docs/README.md"]
    DOCS --> ARCH["docs/architecture/*"]
    DOCS --> OPS["docs/operations/*"]
    DOCS --> REL["docs/release-gate-v2-efgh.md"]
    DOCS --> CK["docs/cloudkit-two-device-smoke.md"]
    DOCS --> ARC["docs/archive/*"]
```

## Primary Sections

| Section | Purpose | Canonical Docs |
| --- | --- | --- |
| Architecture | Data model, clean architecture, usecase and runtime contracts | `docs/architecture/README.md` |
| Operations | CI guardrails, release checks, developer tooling | `docs/operations/ci-release-and-guardrails.md`, `docs/operations/developer-tooling-and-flowctl.md` |
| Release Smoke | CloudKit two-device validation and evidence | `docs/cloudkit-two-device-smoke.md`, `docs/cloudkit-smoke-evidence/latest.md`, `docs/release-gate-v2-efgh.md` |
| Archive | Deprecated, non-canonical historical docs | `docs/archive/qoder-repowiki/README.md` |

## Architecture Docs

| Doc | Coverage |
| --- | --- |
| `docs/architecture/data-model-v2.md` | CoreData V2 entity model, invariants, lifecycle flows |
| `docs/architecture/clean-architecture-v2.md` | Layering, runtime DI, fail-closed behavior, feature gates |
| `docs/architecture/usecases-v2.md` | Usecase taxonomy, contracts, side effects, critical sequences |
| `docs/architecture/risk-register-v2.md` | Migration risk register, guardrails, review checklist |
| `docs/architecture/state-repositories-and-services-v2.md` | State layer repository/service internals and ownership |
| `docs/architecture/domain-events-and-observability-v2.md` | Domain events, handlers, notification bridge, observability |
| `docs/architecture/uxdesign-design-system-v2.md` | Canonical UX design system contracts: tokens, themes, adapters, motion, accessibility, migration, and component recipes |
| `docs/architecture/llm-assistant-stack-v2.md` | LLM context pipeline and assistant transaction stack |
| `docs/architecture/llm-feature-integration-handbook.md` | Mixed audience guide for AI surfaces, safety, rollout, and incident response |

## AI Docs Navigation

Use this order when planning or reviewing AI/LLM changes:
1. `docs/architecture/llm-feature-integration-handbook.md` for product behavior and operator framing.
2. `docs/architecture/llm-assistant-stack-v2.md` for contracts, payload schemas, and runtime boundaries.
3. `docs/architecture/usecases-v2.md` for mutation invariants and workflow ownership.
4. `docs/architecture/risk-register-v2.md` for failure modes and containment playbooks.
5. `docs/release-gate-v2-efgh.md` and `docs/architecture/v3-runtime-cutover-todo.md` for release evidence requirements.

## Operations Docs

| Doc | Coverage |
| --- | --- |
| `docs/operations/ci-release-and-guardrails.md` | GitHub workflows, guardrail scripts, release evidence path |
| `docs/operations/developer-tooling-and-flowctl.md` | `taskerctl`, flowctl install/verify, local-vs-CI constraints |

## Product Context

Product-facing intent remains in:
- `PRODUCT_REQUIREMENTS_DOCUMENT.md`

Root hub:
- `README.md`
