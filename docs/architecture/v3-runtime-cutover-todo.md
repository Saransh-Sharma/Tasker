# V3 Runtime Cutover TODO

**Last updated: 2026-02-21**

## Purpose

Single source of truth for release-gate checks required before promoting V3 runtime changes.
All resolved rows must include a verifiable evidence pointer.

## Release Evidence Matrix

| Gate | Command or check | Evidence pointer | Status |
| --- | --- | --- | --- |
| Build gate | `xcodebuild -workspace Tasker.xcworkspace -scheme "To Do List" -configuration Debug -destination "platform=iOS Simulator,name=iPhone 17" build` | `/tmp/tasker_full_build_after_fix9.log` | [x] Resolved |
| Guardrail gate | `./scripts/validate_legacy_runtime_guardrails.sh` | `/tmp/tasker_guardrails_docs_refresh.log` | [x] Resolved |
| Plan/apply flow smoke | proposal card -> confirm/apply -> undo | pending evidence link in release PR notes | [ ] Open |
| Ask mode non-mutation | verify no pipeline mutation path in ask mode | pending evidence link in release PR notes | [ ] Open |
| Enriched context logging | validate `assistant_context_built` fields (`energy`, `context`, `project_id`, `timezone`) | pending observability snapshot link | [ ] Open |
| Semantic fallback behavior | verify `assistant_semantic_fallback_lexical` emitted when embeddings unavailable | pending fallback test evidence link | [ ] Open |
| Background task registration | occurrences + reminders + daily brief handlers verified | pending startup/runtime evidence link | [ ] Open |

## Documentation Sync Checklist

| Doc | Required evidence pointer | Status |
| --- | --- | --- |
| `docs/architecture/llm-assistant-stack-v2.md` | architecture diff in current PR | [x] Updated |
| `docs/architecture/usecases-v2.md` | architecture diff in current PR | [x] Updated |
| `docs/architecture/risk-register-v2.md` | architecture diff in current PR | [x] Updated |
| `docs/architecture/clean-architecture-v2.md` | architecture diff in current PR | [x] Updated |
| `docs/architecture/llm-feature-integration-handbook.md` | new file in current PR | [x] Added |
| `docs/operations/ci-release-and-guardrails.md` | ops diff in current PR | [x] Updated |
| `docs/release-gate-v2-efgh.md` | release-gate diff in current PR | [x] Updated |
| `docs/README.md` and `docs/architecture/README.md` cross-links | docs hub diff in current PR | [x] Updated |

## Rollback Notes

Plan/apply surfaces can be disabled with:
- `feature.assistant.plan_mode`
- `feature.assistant.copilot`

Semantic reranking can be disabled with:
- `feature.assistant.semantic_retrieval`

Daily brief generation can be disabled with:
- `feature.assistant.brief`

Task breakdown can be disabled with:
- `feature.assistant.breakdown`
