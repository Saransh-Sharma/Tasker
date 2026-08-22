# Eva Cloud Intelligence Architecture

**Classification:** Canonical intelligence-platform overview
**Audience:** Product, design, client/backend engineering, privacy, QA, and operations
**Last verified:** 2026-08-21

## Product contract

Eva is a Life OS layer, not a chat box with a larger prompt. A useful turn combines four independently governed capabilities:

1. Understanding: adaptive, typed context selected for the current question.
2. Retrieval: local semantic/lexical recall with durable record citations.
3. Navigation: closed product destinations and locally resolved records.
4. Actuation: typed commands whose authority, risk policy, receipt, and undo are owned by the device.

Cloud models may reason over authorized context and choose a value from a closed schema. They never emit application routes, invent durable IDs, declare their own risk class, or bypass local consent and mutation policy.

## Turn lifecycle

`EvaTurnRouter` classifies the utterance into chat, review, planning, capture, or navigation. The table is precedence-ordered and protected by the 120-example corpus in `Services/EVACloud/eval/eva-turn-router-corpus.json`.

For Cloud Eva, `EvaTurnContextAssembler` builds contract v4 sections from the route manifest. Stable sections precede volatile sections for prompt-cache reuse. The whole envelope is allocated against a single turn budget; records are removed whole, never truncated mid-identifier.

Context categories are:

- personal memory, with provenance and explicit confirmation;
- goals, retrospective, habits, and day-loop state;
- deterministic capacity and calendar constraints;
- task/project/life-area planning records;
- semantic knowledge matches;
- consent-gated journal, health, and life-moment evidence.

Every selection includes reason and freshness metadata. Sensitive sections require the corresponding local grant. Journal retrieval additionally requires the Journal-wide Eva evidence switch and per-entry AI inclusion.

## Navigation

`RecordKind`, `EvaNavigationTarget`, and `EvaRecordReference` live in `LifeBoardDomain`. `RecordRouteResolver` is the only record-kind-to-route switch. Journal references always pass through protected Journal routing. Record-specific note and journal requests resolve with local search and show disambiguation when confidence is not singular.

The Swift and TypeScript enum copies are asserted against `Shared/EVACloudContracts/fixtures/eva-record-navigation-v1.json` on both sides.

## Capture authority

`EvaCaptureLaneUseCase` is a sibling of the task proposal pipeline. It reuses `AssistantActionRepositoryProtocol`, so applied runs and their undo receipts survive relaunch without a migration. Undo is typed Codable data, not a process-local closure.

Auto-apply requires all of the following:

- one record kind per envelope;
- at most three creates/appends;
- today-only timestamps;
- a locally allow-listed domain executor;
- a domain policy pass.

Body metric outliers and duplicate same-day weights escalate to review. Backdates, mixed batches, larger batches, deletes, medication events, nutrition writes, fasting controls, and task deferrals/moves are never auto-applied through this lane. Capture currently supports body mass, notes, Journal append, tracker values, mood, hydration, and life moments. Note and Journal executors call the same extracted indexing services as their editors.

Applied cards persist `EvaRecordReference` values and offer both Open and a 30-minute durable Undo. Undo treats an already-absent created record as a converged state where the repository contract permits it.

## Memory and correction

“What Eva knows about you” lists every durable statement and distinguishes “You told me” from “Eva noticed · confirmed.” Suggestions are absent from model context until saved. A machine inference cannot silently overwrite a user-stated preference. Statements remain editable and deletable.

Proposal/capture correction events are product telemetry inputs for future inferred candidates; they are not promoted directly into memory. A repeated signal may create a candidate, but the user must confirm it.

## Evidence Lens

Recommendations expose their supporting records. “Don’t use this signal” persists a local exclusion and removes that source from Eva context, Insights, and smart Home eligibility. Exclusions can be restored from Eva’s memory/settings surface. This is enforced again during cloud context assembly, not only hidden in UI.

## Insights and proactivity

`Insight` is the shared object: claim, evidence bundle, confidence, suggested action, provenance, and lifetime. Insights, Home, and Eva should render it at full, compact, and conversational densities while sharing one identity and dismissal state.

`EvaProactiveGovernor` owns interruption authority. It enforces a maximum of two deliveries per day, a useful-probability floor, quiet hours, and 21-day silent dormancy after two dismissals of the same nudge type. The model cannot raise these limits.

## Evaluation and observability

Release checks cover:

- contract schemas and shared drift fixtures;
- the turn-router golden corpus;
- whole-envelope budget validity and overflow behavior;
- capture parsing and local escalation policy;
- durable record references and route resolution;
- proactive governor budget, quiet-hours, and dormancy decisions;
- privacy fixtures for consent and sensitive-section omission.

Operational metrics should separate answer quality from authority safety: route accuracy, context utilization, citation-open rate, capture correction/undo rate, navigation success, proactive useful-to-noise ratio, and exclusion usage.

## Component ownership

| Layer | Owns | Does not own |
|---|---|---|
| Turn router | Semantic route and deterministic precedence | Provider, consent, or mutation authority |
| Runtime resolver | One immutable provider/config/contract/budget snapshot | Context records or model output |
| Context assembler | Manifest, retrieval, consent/protection/exclusions, provenance | Prompt doctrine or store mutation |
| Worker | Admission, prompt policy, provider execution, output schema, accounting | LifeBoard database access or local navigation |
| Local resolver/policy | Destinations, risk class, command authorization | Reinterpreting a rejected model result |
| Domain executor | Validation, transaction, created references, inverse receipt | Broad agent authority |
| Product surfaces | Accurate state, review, receipt, evidence, recovery | Treating a proposal as completion |

## Canonical detailed references

- [Cloud Eva product and technical guide](eva/CLOUD_EVA_PRODUCT_AND_TECHNICAL_GUIDE.md)
- [API contract](eva/API_CONTRACT.md)
- [Context and prompt architecture](eva/CONTEXT_AND_PROMPT_ARCHITECTURE.md)
- [Navigation and capture authority](eva/NAVIGATION_AND_CAPTURE_AUTHORITY.md)
- [Memory, evidence, and proactivity](eva/MEMORY_EVIDENCE_AND_PROACTIVITY.md)
- [Evaluation and observability](eva/EVALUATION_AND_OBSERVABILITY.md)
- [Privacy and data flow](eva/PRIVACY_AND_DATA_FLOW.md)
