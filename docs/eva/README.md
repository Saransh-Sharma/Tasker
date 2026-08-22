# Eva documentation

This directory is the canonical product and engineering documentation set for Eva, the intelligence layer in Life OS. It describes what Eva should do, what the currently shipped system does, the boundaries between cloud reasoning and device authority, and how the team operates the service safely.

## Start here

| Reader | Primary document | Purpose |
|---|---|---|
| Product, design, support, and QA | [Insights and Eva product specification](../product/INSIGHTS_AND_EVA.md) | User value, journeys, interaction states, authority, trust, and acceptance criteria |
| Product and engineering | [Cloud Eva product and technical guide](CLOUD_EVA_PRODUCT_AND_TECHNICAL_GUIDE.md) | End-to-end system overview and shared vocabulary |
| Client and backend engineers | [API contract](API_CONTRACT.md) | Wire formats, route schemas, compatibility, errors, and idempotency |
| Privacy and security reviewers | [Privacy and data flow](PRIVACY_AND_DATA_FLOW.md) | Consent, minimization, retention, sensitive-data controls, and data-flow boundaries |
| Backend and release engineers | [Backend runbook](BACKEND_RUNBOOK.md) | Configuration, deployment, verification, rollback, and production qualification |
| On-call engineers | [Incident runbook](INCIDENT_RUNBOOK.md) | Detection, containment, diagnosis, recovery, and communication |

## Intelligence and authority references

- [Context and prompt architecture](CONTEXT_AND_PROMPT_ARCHITECTURE.md) defines route-scoped retrieval, selection provenance, whole-record budgeting, prompt construction, and degradation behavior.
- [Navigation and capture authority](NAVIGATION_AND_CAPTURE_AUTHORITY.md) defines how Eva turns language into safe navigation or local actions, including confirmation, receipts, and undo.
- [Memory, evidence, and proactivity](MEMORY_EVIDENCE_AND_PROACTIVITY.md) defines correctable memory, evidence exclusions, insight presentation, and proactive-notification governance.
- [Evaluation and observability](EVALUATION_AND_OBSERVABILITY.md) defines quality metrics, offline evaluation, telemetry, release gates, and operational dashboards.
- [Provider architecture](../EVA_CLOUD_INTELLIGENCE_ARCHITECTURE.md) describes provider abstraction, authentication, backend topology, and migration boundaries.
- [Local intelligence architecture](../architecture/LOCAL_LLM_EVA_ARCHITECTURE.md) describes the on-device fallback and the relationship between deterministic local features and cloud Eva.

## Strategy and delivery

- [Roadmap status and gap analysis](EVA_ROADMAP_STATUS.md) — current stage, completed foundation, decisions, critical path, and remaining work
- [Life OS product roadmap](LIFE_OS_PRODUCT_ROADMAP.md)
- [Eva intelligence roadmap](EVA_INTELLIGENCE_ROADMAP.md)
- [Cloud migration TODO](EVA_CLOUD_MIGRATION_TODO.md)
- [Runtime, context, memory, and telemetry migration](EVA_RUNTIME_CONTEXT_MEMORY_AND_TELEMETRY_V3.md)
- [Risk register](RISK_REGISTER.md)

## Source-of-truth rules

When documents and code disagree, use this order while resolving the drift:

1. Shared contract schemas and fixtures define the wire protocol.
2. Signed runtime configuration defines which compatible features and models are enabled.
3. Swift authority policy and local executors define what the app may mutate.
4. The product specification defines the intended user experience and trust contract.
5. Migration and roadmap documents describe sequencing, not current runtime behavior.

Portfolio status uses five explicit labels: defined, implemented, staging-qualified, production-enabled, and graduated. See [Roadmap status and gap analysis](EVA_ROADMAP_STATUS.md); do not infer production availability from an implementation checkbox.

Every change to a route, context category, mutation family, memory field, or telemetry event must update its shared schema, tests, and the relevant canonical documents in the same pull request.

## Current implementation baseline

As of 21 August 2026:

- The worker emits contract version 4 and accepts compatible client requests for versions 1 through 4.
- The current prompt policy identifier is `eva-cloud-v3`; prompt-policy versioning is independent of the wire-contract version.
- Signed runtime configuration uses schema version 2.
- The cloud provider is configured for `gpt-5.6-luna`; speech uses `tts-1` with the `nova` voice.
- Context version 4 requires turn context plus explicit selection reasons for every admitted section. `conversationSummary` is prohibited for version 3 and later requests.
- Production cloud enablement remains gated by qualification and signed configuration. Offline and unavailable states are explicit product states, not silent substitutions.

## Terminology

- **Eva**: the user-facing intelligence layer across assistant, planning, navigation, capture, insights, and review.
- **Turn route**: the semantic capability requested by the client, such as `chat`, `plan`, `capture`, or `navigation`.
- **Cloud route**: the HTTP endpoint used to execute a turn. Multiple turn routes may share transport infrastructure.
- **Context category**: a typed class of user data, such as planning, goals, knowledge, journal, or health.
- **Consent grant**: explicit permission to include a sensitive context category in a cloud turn. A manifest entry alone is never consent.
- **Proposal**: a structured candidate action that still requires user review or confirmation.
- **Direct capture**: a narrowly allowlisted, reversible local write that can execute immediately and produces a receipt with undo.
- **Insight**: an evidence-backed observation or suggestion that does not mutate data by itself.
