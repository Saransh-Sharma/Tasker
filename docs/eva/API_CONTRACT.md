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

`EvaInferenceRequestV1` contains:

- `requestId`: canonical UUID and idempotency key.
- `route`: one semantic route listed below.
- `contractVersion`: currently `1`.
- `locale`, `timeZone`, `clientVersion`, `platform`, and `installationId`.
- `messages`: bounded manual conversation history.
- `context`: bounded projection envelope, not persistence models.
- `consentRevision`: the account policy revision used by the projection.
- `providerCapabilities`: client decoding/playback capabilities, not provider controls.

The server owns model selection, stable prompts, schemas, reasoning effort, caching boundaries, output caps, moderation, repairs, safety identifiers, attempt graph, and credit/cost charging.

## Semantic routes

| Route | Result | Metering | Product job |
|---|---|---|---|
| `chat` | Streamed text | Billable | Explain, summarize, or discuss authorized context |
| `plan` | Structured | Billable | Prepare a reviewable plan proposal |
| `planRepair` | Structured | Included repair | Repair a bounded invalid plan |
| `fieldSuggestion` | Structured | Unmetered | Suggest bounded capture fields |
| `topThree` | Structured | Billable when explicit | Select at most three priorities |
| `taskBreakdown` | Structured | Billable | Create bounded, reviewable steps |
| `dailyBrief` | Structured | Billable | Summarize the day and tensions |
| `universalInputClassification` | Structured | Unmetered | Classify submitted universal input |
| `dynamicChips` | Structured | Unmetered | Produce bounded next-prompt chips |
| `journalAnswer` | Structured | Billable | Answer from explicitly granted journal evidence |
| `knowledgeAnswer` | Structured | Billable | Answer from explicitly granted knowledge evidence |
| `shortcutsAnswer` | Structured | Billable | Return a bounded Siri/Shortcuts answer |
| `debugSmoke` | Text | Environment policy | Internal end-to-end qualification |

Every structured route has its own strict schema, bounds, enums, identifier rules, and semantic validator. Identifiers must originate in supplied context; outputs cannot invent mutation authority. One unmetered repair is allowed. Final schema or semantic failure releases reservations.

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

- `/v1` paths and `contractVersion: 1` remain stable for compatible additions.
- New required fields, changed semantics, or incompatible output schemas require a new contract version and dual-read migration period.
- Runtime configuration publishes supported contract versions and minimum client version.
- The client rejects invalid signatures, environment mismatch, unsupported versions/models, future documents, or monotonic rollback.
- Debug points only at staging; Release points only at production. No build may derive the API origin from the marketing domain at runtime.
