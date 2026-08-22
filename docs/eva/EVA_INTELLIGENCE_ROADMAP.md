# Eva Intelligence Roadmap — from chat box to Life OS layer

**Status:** architecture spine implemented; differentiated product arcs remain staged releases
**Companion architecture:** [Eva Cloud Intelligence Architecture](../EVA_CLOUD_INTELLIGENCE_ARCHITECTURE.md)
**Strategic horizons:** [EVA and the Ultimate Life OS](./LIFE_OS_PRODUCT_ROADMAP.md)
**Current status:** [Eva roadmap status and gap analysis](EVA_ROADMAP_STATUS.md)

## Intended outcome

Eva is the fastest path to anything in LifeBoard: capture it, find it, understand it, decide about it. Three capabilities compound:

1. **Actuation** — write through locally governed domain executors, tiered by risk.
2. **Navigation** — open any supported section or durable record reference.
3. **Understanding** — retrieve authorized life context, cite evidence, and remember correctable preferences.

Cloud models reason over request-scoped context. The device owns consent, identifiers, routes, mutation authority, risk classification, receipts, and Undo.

## Strategic thesis

The model upgrade is valuable only if the product feeds it a coherent view of the current decision. Eva should evolve from “chat with a summary” into an orchestration layer with five compounding assets:

1. **A shared life ontology:** stable references for tasks, projects, goals, habits, knowledge, journal evidence, insights, and destinations.
2. **A context compiler:** route manifests, hybrid retrieval, consent/protection checks, selection provenance, and a whole-turn budget.
3. **An authority kernel:** deterministic risk policy, local resolvers and executors, idempotent traces, receipts, and undo.
4. **A correctable personalization layer:** confirmed memory, evidence exclusions, and explicit feedback that changes future selection.
5. **An evaluation flywheel:** seeded workspaces, subtraction tests, production outcome signals, and independently releasable policies.

The differentiation is not the chat surface or the provider name. It is the quality and trustworthiness of this life-context loop.

## Current portfolio status

| Roadmap layer | State | Next gate |
|---|---|---|
| Platform spine | Implemented | Integrated quality, authority, privacy, and operations qualification |
| A — Navigator and actuator | Implemented | Physical-device and adversarial matrix |
| B — Ask my life | Foundation implemented | Seeded grounding, subtraction, irrelevance, and exclusion evaluation |
| C — Differentiated intelligence | Defined | Select and ship the first independently evaluated decision loop |
| Production Cloud Eva | Disabled | P0 release gates and limited cohort approval |

“Implemented” is not “production-enabled.” The maintained evidence and critical path are in [Eva roadmap status and gap analysis](EVA_ROADMAP_STATUS.md).

## Foundation delivered

- Contract v4 carries typed turn context, Knowledge, selection reasons, freshness, and closed capture/navigation schemas.
- Route-specific assembly includes goals, capacity, calendar, habits, day-loop and retrospective state, semantic Knowledge, and consent-gated Journal evidence under one whole-turn budget.
- Unknown cards degrade to readable text; record/navigation enum drift is pinned by a fixture asserted from Swift and TypeScript.
- `EvaTurnRouter` is precedence-ordered and guarded by a 120-utterance golden corpus.
- `EvaRecordReference` and `RecordRouteResolver` preserve durable IDs and the protected Journal path.
- Knowledge and Journal indexing are callable from editor, Shortcut, and Eva capture paths.
- Applied task proposals retain created references and expose Open/Edit.
- `EvaCaptureLaneUseCase` auto-applies only allow-listed, today-only, same-kind batches of at most three and persists typed Undo for 30 minutes.
- Body metric, note, Journal append, tracker, mood, hydration, and life-moment capture are enabled. Outliers, duplicate weight, backdates, mixed/large batches, medication, nutrition, fasting, deletes, and rescheduling escalate to review.
- “What Eva knows about you” exposes provenance, editing, deletion, and confirmed suggestions.
- Evidence exclusions are enforced at context assembly and reflected across Insights/Home eligibility.
- One `Insight` identity and dismissal state powers full and conversational rendering; a governor limits event-triggered delivery to two per day, honors quiet hours, and applies silent dormancy.

## Release sequence

### A — Navigator and actuator

Navigation lands before new writes. Created IDs remain in result cards. Capture domains earn authority independently; no generic tool bus exists. Habit occurrence remains review-only until gamification XP has a genuine reversal receipt.

### B — Ask my life

Hybrid lexical/semantic retrieval extends across tasks, Knowledge, and authorized Journal entries. Answers should name the supporting record and expose an Evidence Lens. Rejected signals are removed from subsequent selection, not merely hidden in the interface.

### C — Differentiated intelligence

Ship Commitment Realism, Drift Report, Renegotiation, “Why did this fall off?”, habit timing coaching, Scenario Studio, Life Moments pressure, onboarding continuity, and Weekly Reset as separate evaluated product arcs. Deterministic services calculate; Eva explains, compares, and adjudicates.

## Workstreams and dependencies

| Workstream | Product outcome | Platform dependency | Launch evidence |
|---|---|---|---|
| Context relevance | Eva uses the right evidence without oversharing | v4 envelope, route manifest, semantic retrieval, budget allocator | retrieval recall, irrelevance, subtraction, exclusion |
| Fast navigation | Natural language becomes the shortest route to any eligible record | shared record references, target enum, local resolver | exact/ambiguous/protected/no-match success |
| Safe capture | Common logging completes in one turn | deterministic parser, strict cloud schema, authority policy, typed executors | correction, rejection, duplicate, receipt, undo |
| Planning intelligence | Plans reflect capacity, goals, constraints, and history | typed planning/capacity/calendar, proposal pipeline | acceptance/edit, conflict detection, subtraction |
| Personalization | Eva stops asking for durable preferences repeatedly | confirmed memory, provenance, correction/deletion | candidate acceptance and later-correction rate |
| Evidence and Insights | Claims remain inspectable and exclusions change future output | shared evidence references and projection eligibility | grounding, evidence open, cross-surface exclusion |
| Proactivity | Timely help creates value without attention debt | insight eligibility and deterministic governor | helpful action/interruption, dismiss, disable, policy breaches |
| Operations | Changes can ship and roll back independently | signed config, route policy, event model, eval pipeline | release-gate evidence and incident drills |

## Now, next, and later

### Now — qualify the platform spine

- Complete physical-device and staged cloud qualification for contract v4, navigation, capture, memory, Evidence Lens, and proactive policy.
- Establish route-level dashboards and a versioned offline evaluation baseline for the current model and prompt policy.
- Close production privacy/ZDR, consent-comprehension, accessibility, pricing, load, and rollback gates.
- Treat correction, undo, disambiguation, exclusion, and unavailable-source outcomes as first-class product signals.

**Exit:** the platform can be enabled for a limited cohort without unresolved zero-tolerance privacy or authority failures, and each capability can be disabled independently.

This work is P0. Quality evaluation, physical-device authority validation, and privacy/operational qualification are parallel mandatory workstreams; success in one does not compensate for a failure in another.

### Next — ship differentiated decision loops

- Commitment Realism: compare stated priorities with capacity and actual follow-through.
- Renegotiation: turn an overloaded plan into explicit keep/drop/defer choices.
- Drift Report and “Why did this fall off?”: connect plan changes, deferrals, habits, and reflections without moral judgment.
- Weekly Reset: synthesize evidence into a reviewable next-week proposal.
- Scenario Studio: compare bounded alternatives without applying any of them.

Each loop ships as a product feature with a dedicated route or deterministic service, evaluation rubric, evidence model, and authority level—not as another system-prompt paragraph.

**Exit:** users complete a measurable planning or reflection outcome more reliably than with current manual flows, with no regression in trust guardrails.

### Later — broader Life OS orchestration

- Cross-domain questions that combine goals, planning, habits, knowledge, and authorized personal evidence.
- User-created routines and reusable workflows executed through typed, reviewable steps.
- Cross-device receipt and undo convergence where domain repositories can guarantee it.
- More proactive surfaces only after topic preference, explanation, and feedback controls are proven.
- New write domains only after each earns a schema, local executor, reversible semantics, and independent kill switch.

**Non-goal:** an open-ended agent with arbitrary tools, broad background autonomy, or a single global “allow Eva to act” permission.

## Prioritization model

Score roadmap candidates on:

- frequency and severity of the user problem;
- advantage from private Life OS context over a generic chatbot;
- evidence quality and evaluability;
- authority/reversibility cost;
- privacy and interruption burden;
- platform reuse across other jobs;
- operational cost and latency.

Prefer high-frequency jobs that use existing typed evidence and read-only or reversible authority. Defer impressive demos that need speculative context, irreversible action, or unmeasurable success.

## Guardrails

- No general agent toolset and no model-declared risk class.
- External messages, purchases, bookings, destructive changes, and safety-relevant health actions are never silent.
- Auto-apply is visible, reversible, today-only, and at most three same-kind writes.
- Read consent never implies write consent.
- Cross-device Undo treats an already-absent created record as converged where the repository contract permits it.
- Offline and permission-denied states explain which cloud capability is unavailable while leaving ordinary LifeBoard usable.

## Evaluation gates

- contract/type drift and privacy fixtures;
- 120-example route corpus;
- per-domain capture parsing, escalation, receipt, relaunch, and idempotent Undo tests;
- navigation target and missing-record tests, including protected Journal routing;
- context budget, sensitive-section omission, citation, and evidence-exclusion tests;
- proactive budget, quiet-hours, useful-probability, dismissal, and dormancy tests;
- seeded-workspace quality evaluation scored on grounding, subtraction, evidence traceability, capture correction, navigation success, and repeat misunderstanding.

Messages sent, session length, and assistant streaks are not success metrics.

## Decision metrics

| Product layer | Primary outcome | Diagnostic | Hard guardrail |
|---|---|---|---|
| Ask | Grounded useful completion | context utilization, evidence opens, retries | no excluded-data influence |
| Navigate | Destination reached | disambiguation/no-match rate | no protected-record leak |
| Capture | Correct un-reversed write | parser/cloud split, policy rejection, undo | no prohibited mutation |
| Plan | Accepted or productively edited decision | constraint detection, proposal edits | no hidden overload/conflict |
| Remember | Fewer repeated corrections | accept/edit/delete/correction | no silent memory promotion |
| Proactive | Helpful action per interruption | dismiss, dormancy, disable | policy caps never breached |

## Governance

- Product owns the job, authority level, user-facing state, and success measure.
- Domain engineering owns local validation, execution, reversibility, and data integrity.
- Intelligence platform owns route contracts, context selection, provider prompts, and evaluations.
- Privacy/security owns data-class, consent, retention, abuse, and incident review.
- Release/operations owns signed policy, staging evidence, dashboards, budgets, and rollback.

A capability cannot move from roadmap to “shipped” until these owners agree on its schema, authority, context, degraded behavior, measurement, and kill switch.
