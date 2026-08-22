# Eva Product Roadmap

**Classification:** Portfolio summary; implementation sequencing lives in the detailed roadmap
**Status:** Platform spine shipped in code; production cloud qualification and differentiated arcs remain staged
**Last verified:** 2026-08-21
**Detailed roadmap:** [Eva intelligence roadmap](eva/EVA_INTELLIGENCE_ROADMAP.md) and [24-month Life OS roadmap](eva/LIFE_OS_PRODUCT_ROADMAP.md)
**Current report:** [Eva roadmap status and gap analysis](eva/EVA_ROADMAP_STATUS.md)

## Outcome

Eva should be the fastest trusted path to capture, find, understand, decide, and recover across LifeBoard. It succeeds when users make a better decision or complete a meaningful workflow with less burden—not when they send more messages.

## Shipped foundation

- Cloud contract v4 with typed turn context, Knowledge, selection metadata, and compatibility for supported older requests.
- Adaptive route-specific context, semantic task/note selection, consent-gated Journal retrieval, calendar/capacity/goals/habits/day-loop/retrospective context, and whole-turn allocation.
- Server prompt v3 and strict capture/navigation schemas.
- Unknown-card forward compatibility.
- Typed record references, one record route resolver, local navigation, disambiguation cards, and created-record links.
- Extracted Knowledge and Journal indexing services.
- Durable capture lane for body mass, notes, Journal append, trackers, mood, hydration, and life moments, including local escalation and relaunch-safe undo.
- Editable provenance-aware memory and confirmed memory suggestions.
- Evidence Lens exclusions, a unified Insight contract, and the proactive governor.

## Product principles

- Deterministic systems calculate; Eva interprets and adjudicates.
- The cloud reasons; the device grants authority.
- Context is earned per route and consent, not attached as a universal firehose.
- Every write has a durable receipt and an honest undo boundary.
- Every important claim can show its evidence and lose access to a rejected signal.
- One insight has one dismissal across every surface.

## Next product arcs

The platform now supports the differentiated experiences described in the original roadmap: Commitment Realism, Drift Report, Renegotiation, “Why did this fall off?”, habit timing coaching, Scenario Studio, Life Moments pressure, onboarding continuity, and Weekly Reset.

Each arc should ship behind an evaluation set and an explanation bundle. No arc receives write authority merely because another domain has it; preview, idempotency, partial failure, activity history, and revocation are reviewed per domain.

## Sequencing

| Stage | Product promise | Required proof |
|---|---|---|
| 0. Production qualification | Current cloud, navigation, capture, memory, evidence, and proactive controls work safely on real devices | Privacy/ZDR, route evals, physical trust/age/account flows, load/cost, accessibility, kill-switch drill |
| 1. Daily decisions | Day Compass and Momentum Rescue produce believable keep/drop/defer choices | Capacity subtraction, proposal edit/accept, reduced overload, no pressure language |
| 2. Reflection loop | Weekly Reset, Drift Report, and “Why did this fall off?” connect evidence to adaptation | Grounding, evidence comprehension, exclusion propagation, repeat usefulness |
| 3. Simulation | Scenario Studio and Renegotiation compare options without mutating canonical state | Assumption visibility, state isolation, scenario-to-plan conversion |
| 4. User-owned orchestration | Reusable playbooks and carefully expanded action domains | Per-domain authority, reversibility, activity history, revocation, independent kill switch |

The portfolio is currently in Stage 0. The platform primitives in the shipped foundation are implemented, while real-device, quality, privacy, cost, load, and rollback qualification remain incomplete. Stages 1–4 are not production claims.

## Product work required for every arc

- Define the user decision and the failure mode in the existing workflow.
- Choose answer, navigation, direct capture, or proposal authority explicitly.
- Define eligible context, evidence, consent, freshness, and exclusion behavior.
- Provide empty, partial, ambiguous, stale, offline, protected, failure, and recovery states.
- Define an evaluation rubric and a product outcome that can improve without content-invasive analytics.
- Ship behind signed policy or a local feature control with a rehearsed rollback.

## Deliberate exclusions

- No open-ended tool bus or model-declared authority.
- No silent external communication, purchase, booking, calendar mutation, destructive change, medication/dose action, or high-stakes financial/legal action.
- No raw bulk upload for “personalization.”
- No always-listening or full-duplex companion.
- No engagement metric that rewards interruption, anxiety, or dependency.

## Success measures

- Context utilization and citation-open rate increase without sensitive-context leakage.
- Navigation requests land on the intended section/record without a cloud round trip.
- Capture correction and undo rates remain low enough to justify auto-apply.
- Memory corrections reduce repeat misunderstandings.
- Proactive useful-to-noise feedback remains above the governor floor.
- Users complete more renegotiations and realistic commitments, not simply more AI turns.

Guardrails are zero unauthorized sensitive-context use, zero excluded-evidence influence in qualification tests, zero prohibited direct mutations, accurate completed/proposed state, and deterministic proactive limits.
