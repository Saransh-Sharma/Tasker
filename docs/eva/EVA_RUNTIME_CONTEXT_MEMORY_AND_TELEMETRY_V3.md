# Eva runtime, context, memory, receipts, and telemetry v4

**Classification:** Migration and implementation summary
**Audience:** iOS, backend, security, privacy, QA, operations
**Last verified:** 2026-08-21

> The filename is retained to preserve existing links from the v3 migration. This document now describes the v4 baseline. For normative detail, use [Context and prompt architecture](CONTEXT_AND_PROMPT_ARCHITECTURE.md), [Memory, evidence, and proactivity](MEMORY_EVIDENCE_AND_PROACTIVITY.md), and [Evaluation and observability](EVALUATION_AND_OBSERVABILITY.md).

## Turn authority

Every turn resolves one immutable `EvaTurnRuntime` before context assembly. It snapshots provider, model/route, signed configuration version, contract version, consent revision/grants, credit readiness, input/output budgets, render mode, output policy, and timeout policy. The same value flows through projection, prompt construction, transport, output handling, persistence, and receipt creation.

- Cloud preference uses Cloud only when the complete route is ready.
- Cloud failure is visible and never invokes MLX automatically.
- Offline preference uses an explicitly installed MLX model and compact context.
- Legacy Automatic decodes as Cloud unless Offline was explicitly selected.
- Consent or signed-policy drift during assembly fails the turn and requires a new resolution.
- Rich Cloud context cannot enter the MLX path.

Cloud responses receive server safety, schema validation, whitespace normalization, and persistence validation. They bypass MLX template cleanup, thinking-tag stripping, local repetition retries, and local visible-character clamps. Offline output retains those MLX-specific defenses.

Control-plane requests use short sessions. SSE inference has a route-aware resource deadline beyond the Worker execution window plus first-byte/inactivity policy. Cancellation closes the stream; backend reservations are released on cancellation, timeout, moderation rejection, invalid output, and provider failure.

## Contract v4

The Worker continues to decode versions 1–3 while the current signed configuration advertises versions 1–4. The client negotiates the highest mutually supported major and does not send newer required fields to an older Worker.

V3 introduced typed sections and required availability metadata for planning, capacity, goals, habits, day loop, retrospective, calendar, journal, Health, Life Moments, personal memory, and Knowledge. V4 requires temporal/surface `turnContext` plus one or more closed selection reasons for every admitted section. Unknown planning counts remain unknown rather than becoming zero. Conversation summaries are forbidden in v3 and later.

Sensitive category grants, route manifests, protection rules, and local per-record exclusions are applied before budgeting. Typed and semantic retrieval rank eligible records. Whole records are dropped at limits; identifiers and structured values are never truncated. Metadata is recomputed after admission. The Worker validates the final `modelInput(request)`, including wrappers and user instructions, before reserving credit. Cache keys include prompt-policy, route, and contract major; the account-independent doctrine remains stable before the cache breakpoint.

## User-owned memory

`EvaMemoryStoreV3` is local and contains at most 30 active statements of at most 240 characters in Preferences, Routines, Current Goals, Capacity, and Boundaries. Provenance is `userStated` or a user-confirmed `inferredCandidate`. Only confirmed statements enter context.

V1/V2 migration preserves stated entries before inferred entries, normalizes whitespace, deduplicates equivalent text, converts legacy inference provenance, and keeps the newest records within the cap. Onboarding may seed at most six deterministic user-stated memories; seeding never activates EVA.

After an eligible successful Cloud turn, the non-billable `memoryCandidate` route receives only the latest user turn and bounded confirmed-memory context. It returns zero or one strict candidate. The candidate is persisted inactive and shown inline with Save, Edit, Later, and Dismiss:

- Save confirms it and makes it eligible for future consented context.
- Edit changes the proposed text before confirmation.
- Later removes it from chat but keeps it in the Settings inbox.
- Dismiss stores a normalized suppression key.
- Pending candidates expire after 30 days.
- At cap, saving replaces an inferred/old entry before a stated entry.

No conversation-summary request, store, or v3+ field exists.

## Immutable context receipts and exclusions

Every persisted Cloud assistant message may carry `EvaContextReceiptSnapshot`; Offline and historical messages may have none. A receipt records provider, route, timestamp, consent/config revisions, categories, availability/counts, and stable source keys. It does not contain prompt text, journal/Health/Life Moment bodies, or the serialized envelope.

The **Context used** sheet provides category status, redacted per-record labels, future-turn **Don’t use in Eva**/Undo controls, category consent controls, and an Eva privacy/settings route. `EvaContextExclusionStore` is local and keyed by category plus stable source ID. Excluding a record never deletes its canonical source. It invalidates the next projection, updates included counts/partial reasons, and removes derived content that could otherwise retain the excluded record. The same projection exclusion governs Eva, Insights, and Home. Historical receipts remain byte-immutable.

## Worker safety and product telemetry

The Worker moderates normalized messages, projected context, and fenced user instructions. Maximum-size inputs are chunked and checked concurrently. User preferences never gain policy authority. Structured routes receive schema and semantic identifier validation. OpenAI response state is not retained server-side.

`ProductEventV1` is a separate optional product-analytics stream, not a security/account audit stream. The client uses a rotating pseudonymous installation identifier and batches only enumerated content-free dimensions. The Worker rejects unknown events and additional/content-bearing fields. Opt-out discards pending events and stops transmission immediately; the signed `productEventsEnabled` switch can stop it independently. Raw events have a 90-day operational-retention target; aggregates may remain afterward. Security/account audit requirements remain separately governed.

## Deployment and rollback order

1. Deploy shared schemas and a Worker that accepts versions 1–4, including closed capture/navigation schemas and the disabled-by-default `memoryCandidate` policy.
2. Publish and verify a schema-v2 signed policy advertising `[1,2,3,4]` and explicit app runtime controls.
3. Ship the client; it negotiates the highest compatible version and fails cloud context closed when runtime authority cannot be verified.
4. Enable routes in staging; run contract, manifest, selection, moderation, whole-budget, cancellation, receipt, exclusion, authority, and privacy tests.
5. Qualify navigation, each capture domain, memory candidate, Evidence Lens, and proactive governor independently.
6. Enable production by signed route policy. Roll back a route or presentation independently; never alter provider preference or delete local records during rollback.

## Verification map

- iOS: runtime authority drift, Cloud/Offline matrix, MLX byte-baseline, long Cloud output, SSE cancellation, V1/V2 memory migration, candidate actions/expiry/suppression, receipt immutability, exclusions, consent CAS, navigation/capture authority, and telemetry opt-out.
- Contracts: every route fixture, v1–v4 admission, v3 metadata, v4 turn context and selection reasons, summary rejection, source identifiers, and strict structured candidate/capture/navigation shapes.
- Worker: moderation coverage, exact model-input budget, credit release, cache versioning, product-event allowlist, signed config validation, expiry/cache/offline behavior.
- Manual: VoiceOver/Dynamic Type, denied permissions, offline launch, low-memory MLX, delayed stream, Apple physical-device trust, capture receipts/undo, protected navigation, memory correction, proactive delivery, and Settings recovery routes.
