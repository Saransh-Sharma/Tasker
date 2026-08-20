# Cloud EVA API Contract

**Status:** Implemented v1 wire contract; staging qualification in progress
**Production origin:** `https://api.getlifeboard.app`
**Contract authority:** `Shared/EVACloudContracts`
**Last verified:** 2026-08-17

This document explains the public boundary between LifeBoard and the EVA Cloud Worker. TypeBox schemas and fixtures in `Shared/EVACloudContracts` are canonical; this document is the human-readable operating contract.

## Contract principles

- The client selects a semantic route, never an OpenAI model, system prompt, tool, token budget, price, or safety identifier.
- Every request is authenticated, device-bound where the platform permits, age-eligible, consent-revision checked, rate limited, and budgeted before model work.
- Stored LifeBoard objects never cross the boundary. The client sends bounded projection DTOs containing only categories the person enabled.
- A provider is selected once per run. A failed cloud run offers Offline EVA; it never silently changes provider mid-answer.
- Consequential changes remain proposals. The API cannot write LifeBoard tasks, calendar events, health data, journal entries, or other app state.
- Request and response bodies are not retained by the Worker. Operational events are content-free.

## Endpoint surface

| Method and path | Authentication | Additional proof | Purpose |
|---|---|---|---|
| `GET /health` | None | None | Liveness, environment, deployment version |
| `GET /v1/eva/config` | None | Ed25519 response signature | Fail-closed runtime policy |
| `POST /v1/auth/challenge` | None | Rate limit | Single-use Apple/auth challenge |
| `POST /v1/auth/apple/exchange` | Apple credential | Challenge and nonce | Create or resume a cloud account |
| `POST /v1/auth/refresh` | Refresh token | Session-family binding | Rotate access and refresh tokens |
| `POST /v1/auth/logout` | Access token | Device session | Revoke the current session |
| `POST /v1/auth/apple/events` | Apple-signed event | Apple chain/signature | Revocation and account events |
| `POST /v1/attestation/challenge` | Access token | None | Issue single-use App Attest challenge |
| `POST /v1/attestation/register` | Access token | App Attest attestation | Register an iOS device key |
| `POST /v1/age/eligibility` | Access token | iOS assertion or Catalyst session | Register a 24-hour 18+ lease |
| `GET /v1/eva/credits` | Access token | Device trust | Account balance and refill anchor |
| `GET /v1/eva/consent` | Access token | Device trust | Authoritative remote-context policy |
| `PUT /v1/eva/consent` | Access token | Device trust and revision | Update context grants atomically |
| `POST /v1/eva/responses` | Access token | Trust, age, consent, credits/budget | Luna response stream |
| `POST /v1/eva/speech` | Access token | Trust and signed speech ticket | `tts-1` PCM stream |
| `DELETE /v1/account` | Recent Apple reauthentication | Device trust | Delete the EVA cloud account |

All JSON request objects reject unknown properties. The Worker applies a 256 KiB body ceiling before JWT or attestation work. UUID fields use the shared canonical UUID pattern rather than an ambient JSON Schema format registry.

## Authentication and trust lifecycle

1. The client obtains a one-time challenge and binds it to the Sign in with Apple nonce.
2. The Worker validates Apple issuer, audience, signature, nonce, expiry, and authorization-code exchange identity.
3. The Worker derives a pseudonymous account key; the Apple subject is not used as a public identifier.
4. The Worker issues a 15-minute access token and rotating opaque refresh token. Only refresh-token hashes are stored.
5. iOS registers App Attest and binds assertions to method, path, request body, challenge, and monotonic counter. Catalyst supplies a signed App Transaction as a weaker risk signal and receives lower limits.
6. Apple 18+ eligibility is registered per device and expires after 24 hours without revalidation.
7. Refresh-token reuse, Apple credential revocation, failed trust validation, or account deletion revokes the affected session.

## Inference request

`EvaInferenceRequest` contains:

- `requestId`: canonical UUID and idempotency key.
- `route`: one semantic route listed below.
- `contractVersion`: **negotiated, not hardcoded.** The client sends the highest version present in both its own ceiling and the `contractVersions` array of the verified signed configuration, falling back to `1` when there is no verified configuration or no overlap. Only a v2 request may carry `userInstructions`, and a v1 request omits the field entirely rather than sending null — an older strict schema has no such property and rejects the whole request.
- `locale`, `timeZone`, `clientVersion`, `platform`, and `installationId`.
- `messages`: bounded conversation history, at most 64 turns.
- `context`: the typed projection envelope, at most 12 sections — one per category.
- `userInstructions` *(v2, optional)*: the person's own standing instruction from Settings.
- `consentRevision`: the account policy revision used by the projection.
- `providerCapabilities`: client decoding/playback capabilities, not provider controls.

The server owns model selection, stable prompts, schemas, reasoning effort, caching boundaries, output caps, moderation, repairs, safety identifiers, attempt graph, and credit/cost charging.

### Context envelope (v3, with v1/v2 compatibility)

v1 carried `payload: unknown`, so a drifted client projection degraded answer
quality silently — nothing on the server could notice a field had disappeared.
Each category now declares a TypeBox schema in
`Shared/EVACloudContracts/src/context.ts`, and a mismatch fails at the request
boundary with `schema_invalid`.

| Category | Grant required | Carries |
|---|---|---|
| `planning` | — | Typed task records, summary counts, projects, life areas, and the rendered overview |
| `capacity` | — | Working/fixed/buffer/usable/planned minutes, overload, confidence, free windows |
| `goals` | — | Goal titles, `whyItMatters`, status, target date, progress, risk reason |
| `habits` | — | Streaks, adherence, the last 14 days oldest-first, best time of day |
| `dayLoop` | — | Closes, opens, run length, reversals, and yesterday's close ring |
| `retrospective` | — | Week focus statement, outcomes, and the person's own wins/blockers/lessons |
| `calendar` | — | Read-only busy blocks; the title may be withheld while the block still constrains the day |
| `journal` | `journal` | Authorized, already-redacted evidence events |
| `health` | `health` | Authorized, already-redacted evidence events |
| `lifeMoments` | `lifeMoments` | Authorized, already-redacted evidence events |
| `personalMemory` | `personalMemory` | Up to 30 confirmed statements tagged `userStated` or `inferredCandidate` |

Only the last four are consent-gated (`sensitiveContextCategories`). The rest
project records the person already sees inside LifeBoard and ride on the
request's own authorization, so widening the list does not widen what a grant
means.

Two conventions hold across every schema:

- **V3 sections carry availability metadata.** `complete`, `partial`, or
  `unavailable`, optional known counts, bounded partial reasons, and stable
  source identifiers power honest receipts and exclusions. Conversation
  summaries are rejected in v3.

- **Durations are minutes**, never seconds and never wall-clock strings. One unit
  makes capacity arithmetic reliable.
- **Absent and `null` mean the same thing: not known.** Swift's synthesized
  `Encodable` uses `encodeIfPresent`, so a nil property is omitted rather than
  written as `null`. Schemas that demanded an explicit null would reject every
  request the client actually sends. `additionalProperties: false` still keeps
  each shape closed.

Task records carry `deferredCount` and `replanCount`. These are the fields that
change the character of an answer — the difference between reading someone's list
back to them and being able to say "you have moved this four times."

### Client budgets

The client sizes its envelope from `RoutePolicy.inputTokenCap` in the signed
configuration, not from a local model's token table. `EvaContextBudget` is the
only place a budget is produced and it **fails closed to the offline budget**
whenever a cloud turn cannot be positively confirmed: no verified configuration,
a disabled route or cloud state, an unready account, or a model name that is not
the cloud sentinel. Offline budgets are unchanged from the per-model table.

### User instructions (v2)

`userInstructions.persona` is **user-authored text, not developer authority**. It
reaches the model inside the developer message so tone and working style take
effect, but it is fenced, explicitly subordinated to the doctrine and
constraints above it, capped server-side at 2,000 characters, moderated with the
rest of the input, and placed *after* the prompt-cache breakpoint so it cannot
poison the shared prefix. It cannot grant capabilities, relax a constraint, or
change what counts as a refusal.

## Semantic routes

| Route | Result | Metering | Product job |
|---|---|---|---|
| `chat` | Streamed text | Billable | Explain, summarize, or discuss authorized context |
| `plan` | Structured | Billable | Prepare a reviewable plan proposal |
| `planRepair` | Structured | Included repair | Repair a bounded invalid plan |
| `fieldSuggestion` | Structured | Unmetered | Suggest bounded capture fields |
| `topThree` | Structured | Billable when explicit | Select at most three priorities |
| `taskBreakdown` | Structured | Billable | Create bounded, reviewable steps |
| `dailyBrief` | Structured | Billable | Name what is fixed, what fits, and the tradeoff |
| `universalInputClassification` | Structured | Unmetered | Classify submitted universal input |
| `dynamicChips` | Structured | Unmetered | Produce bounded next-prompt chips |
| `journalAnswer` | Structured | Billable | Answer from explicitly granted journal evidence |
| `knowledgeAnswer` | Structured | Billable | Answer from explicitly granted knowledge evidence |
| `shortcutsAnswer` | Structured | Billable | Return a bounded Siri/Shortcuts answer |
| `debugSmoke` | Text | Environment policy | Internal end-to-end qualification |

Every structured route has its own strict schema, bounds, enums, identifier rules, and semantic validator. Identifiers must originate in supplied context; outputs cannot invent mutation authority. One unmetered repair is allowed. Final schema or semantic failure releases reservations.

`semanticValidationError` authorizes identifiers by scanning **`request.context`
only**. A route that returns a `taskID`, `projectID`, `task_id`, `lifeAreaID`,
`tagIDs`, or `evidenceTaskIDs` must therefore carry its roster in the context
envelope, not inlined in the prompt text — otherwise every non-empty result is
rejected as referencing an identifier outside supplied context. This applies to
`plan`, `planRepair`, `topThree`, and `dailyBrief`.

`dailyBrief` returns a structured brief: `brief` (required, and the only field a
v1 client reads), plus optional `fixedCommitments`, `nextMove`,
`tradeoff { drop, because }`, `evidenceTaskIDs`, and `isOvercommitted`. Modelling
the tradeoff rather than burying it in prose is what makes "what fits, what does
not, and why" checkable.

Runtime configuration encodes `routes` as a JSON object keyed by the semantic route strings above. Swift must explicitly translate those string keys to `EvaCloudRoute`; synthesized `Codable` for an enum-keyed dictionary is not the wire contract and may expect an alternating array instead.

## Streaming lifecycle

The response uses normalized server-sent events. Every event includes `requestId` and a monotonically increasing `sequence`.

1. `response.accepted` confirms admission and reservation.
2. `response.text.delta` carries moderated, releasable text for free-text routes.
3. `response.structured` carries one fully buffered, moderated, schema-valid result.
4. `response.usage` reports normalized token/cache/cost usage without content.
5. `response.completed` closes the run and may include a signed speech ticket plus the exact `speechSource` used to hash structured speech.
6. `response.failed` returns the stable error envelope and ends the run.

Cancellation propagates to OpenAI. Only classified connection, timeout, 429, or 5xx failures may retry, and only before the first visible delta. Explicit refusals, incomplete results, moderation rejection, cancellation, or schema failure are not charged as successful answers.

## Stable errors and recovery

All errors include `requestId`, a safe message, `retryable`, and a recovery action. `retryAfter` and current credit state are optional.

| Error | Typical recovery |
|---|---|
| `unauthenticated`, `session_expired` | Sign in or refresh |
| `adult_eligibility_required` | Share a current Apple 18+ result on this device |
| `attestation_required` | Re-register device trust; simulator cannot qualify |
| `consent_required`, `consent_revision_conflict` | Review or reload context permissions |
| `insufficient_credits` | Show balance/refill; do not retry automatically |
| `rate_limited` | Retry only after the supplied delay |
| `budget_exhausted` | Offer explicit Offline EVA |
| `input_rejected`, `output_rejected` | Explain safe limitation; do not log content |
| `schema_invalid` | Correct the client body or server result; no charge |
| `provider_unavailable`, `configuration_unavailable` | Retry or offer explicit Offline EVA |
| `request_cancelled` | Preserve settled client text; allow a new run |
| `client_upgrade_required` | Require a compatible app version |

Replaying a completed billable `requestId` never charges again. Because v1 deliberately stores no answer content, it returns a stable no-charge replay error and requires a new request ID for regeneration.

## Credits and speech

New accounts receive 100 credits, refill by 20 for each complete elapsed 24-hour interval, and cap at 100. A billable answer reserves one credit before upstream work and commits only for a nonempty, nonrefusal, valid result. The first successful speech rendering is included through a single-use signed ticket. Local replay is free; paid regeneration after cache loss requires explicit confirmation.

Speech accepts at most 12,000 source characters, validates the exact SHA-256-bound ticket, splits sentence-aware chunks at 4,000 characters, and streams PCM without server persistence. Spoken output is independent of text availability. Cloud speech-to-text and full-duplex conversation are outside this contract.

## Versioning

- `/v1` paths remain stable for compatible additions. `contractVersion` `1` and `2` are both admitted; `runtime-config` publishes `contractVersions: [1, 2]`.
- v2 added optional fields and new context categories only. A v1 client never sends them, so one schema serves both and admission control does not fork.
- **Deploy order is not load-bearing, by design.** Version negotiation means a v2-capable app against a v1 Worker simply speaks v1. Hardcoding the client ceiling instead made every request fail with `schema_invalid` until the Worker caught up.
- **One payload shape per category, regardless of how the projection went.** A degraded projection emits the same planning object with an empty `tasks` array and the rendered text in `renderedOverview` — never a differently-shaped object. `contractVersion` is decided per request while payloads are built in several places, so if fallback paths emitted their own shapes, any turn that took one would be rejected. `EvaContextSectionFactory` is the only sanctioned constructor; nothing may bypass it.
- New required fields, changed semantics, or incompatible output schemas require a new contract version and dual-read migration period.
- Runtime configuration publishes supported contract versions and minimum client version.
- The client rejects invalid signatures, environment mismatch, unsupported versions/models, future documents, or monotonic rollback.
- Debug points only at staging; Release points only at production. No build may derive the API origin from the marketing domain at runtime.
