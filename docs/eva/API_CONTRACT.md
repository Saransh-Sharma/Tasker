# Cloud EVA API Contract

**Status:** Contract v4 implemented; production qualification remains configuration-gated
**Production origin:** `https://api.getlifeboard.app`
**Contract authority:** `Shared/EVACloudContracts`
**Last verified:** 2026-08-21

This document explains the public boundary between LifeBoard and the EVA Cloud Worker. TypeBox schemas and fixtures in `Shared/EVACloudContracts` are canonical; this document is the human-readable operating contract.

## Contract principles

- The client selects a semantic route, never an OpenAI model, system prompt, tool, token budget, price, or safety identifier.
- Every request is authenticated, device-bound where the platform permits, age-eligible, consent-revision checked, rate limited, and budgeted before model work.
- Stored LifeBoard objects never cross the boundary. The client sends bounded projection DTOs containing only categories the person enabled.
- A provider is selected once per run. A failed cloud run offers Offline EVA; it never silently changes provider mid-answer.
- The API cannot write LifeBoard state. It returns text, navigation intent, direct-capture commands, or reviewable proposals. The device independently validates and executes only locally authorized commands.
- Request and response bodies are not retained by the Worker. Operational events are content-free.

## Endpoint surface

| Method and path | Authentication | Additional proof | Purpose |
|---|---|---|---|
| `GET /health` | None | None | Liveness, environment, deployment version |
| `GET /v1/eva/config` | None | Ed25519 response signature | Fail-closed runtime policy |
| `POST /v1/auth/challenge` | None | Rate limit | Single-use Apple/auth challenge |
| `POST /v1/auth/guest/bootstrap` | Confirmed activation | Network/device risk signals | Create or resume a pseudonymous guest session |
| `POST /v1/auth/apple/exchange` | Apple credential | Challenge and nonce | Create or resume a cloud account |
| `POST /v1/auth/apple/link` | Guest access token + Apple credential | Link challenge and nonce | Merge guest state into one canonical Apple account |
| `POST /v1/auth/apple/reauthenticate` | Apple-linked access token + Apple credential | Reauthentication challenge and matching Apple subject | Renew recent authentication without changing accounts or refresh families |
| `POST /v1/auth/refresh` | Refresh token | Session-family binding | Rotate access and refresh tokens |
| `POST /v1/auth/logout` | Access token | Device session | Revoke the current session |
| `POST /v1/auth/apple/events` | Apple-signed event | Apple chain/signature | Revocation and account events |
| `POST /v1/attestation/challenge` | Access token | None | Issue single-use App Attest challenge |
| `POST /v1/attestation/register` | Access token | App Attest attestation | Register an iOS device key |
| `POST /v1/attestation/verify` | Access token | App Attest assertion | Prove a persisted device key still exists before retaining high trust |
| `POST /v1/age/eligibility` | Access token | Assertion when available | Register optional 13+ evidence or a mandatory regional decision |
| `GET /v1/eva/quota` | Access token | Session binding | Rolling answer quota |
| `GET /v1/eva/credits` | Access token | Session binding | Temporary one-client-version quota projection |
| `GET /v1/eva/consent` | Access token | Device trust | Authoritative remote-context policy |
| `PUT /v1/eva/consent` | Access token | Device trust and revision | Update context grants atomically |
| `POST /v1/eva/responses` | Access token | Trust, age, consent, credits/budget | Luna response stream |
| `POST /v1/eva/speech` | Access token | Trust and signed speech ticket | `tts-1` PCM stream |
| `DELETE /v1/account` | Active guest session or recent Apple reauthentication | Assertion when available | Delete Cloud EVA data |

All JSON request objects reject unknown properties. The Worker applies a 256 KiB body ceiling before JWT or attestation work. UUID fields use the shared canonical UUID pattern rather than an ambient JSON Schema format registry.

## Authentication and trust lifecycle

1. The activation screen confirms cloud processing and the exact sensitive grants, then sends one idempotent guest bootstrap request.
2. A server-owned mapping assigns a random guest account ID unrelated to network or installation identifiers and issues a 15-minute access token plus rotating opaque refresh token. Rollout cohorts use a secret-keyed digest of the retry-stable bootstrap ID; clients cannot calculate eligible IDs offline.
3. App Attest registration follows bootstrap. Challenges are independently single-use, so concurrent account operations cannot overwrite one another. App Attest, DeviceCheck, and App Transaction results assign risk tiers but do not reduce the 20-answer allowance.
4. Protect & Sync obtains a nonce-bound Apple link credential. A canonical-account lock serializes links. A durable reconciliation record freezes the guest session, unions rolling usage, intersects consent, merges device trust, tombstones the guest, and retries after cross-object interruption before a canonical session is returned.
5. The linked consent revision remains review-required until explicitly confirmed again.
6. Refresh-token reuse, Apple credential revocation, or account deletion revokes the affected session. The iOS transport single-flights refresh so concurrent calls never present the same rotating token twice. A Durable Object outage remains retryable and does not falsely erase local credentials.
7. Apple-linked deletion uses the dedicated reauthentication endpoint. The server requires the presented Apple subject to derive the already-active account ID; choosing another Apple account cannot switch or delete that account.

The signed runtime policy—not the request body—decides whether a current regional age decision is mandatory. Known lower bounds below 13 are always denied. When the mandatory policy is active, the server also checks the 24-hour eligibility lease on every model and account-read admission.

## Inference request

`EvaInferenceRequest` contains:

- `requestId`: canonical UUID and idempotency key.
- `route`: one semantic route listed below.
- `contractVersion`: **negotiated, not hardcoded.** The client sends the highest version present in both its own ceiling and the `contractVersions` array of the verified signed configuration. A cloud turn fails closed when there is no verified compatible policy; version 1 remains only for legacy compatibility.
- `locale`, `timeZone`, `clientVersion`, `platform`, and `installationId`.
- `turnContext` *(required in v4)*: `requestedAt`, local calendar date, calendar identifier, first weekday, and the originating surface.
- `messages`: bounded conversation history, at most 64 turns.
- `context`: the typed projection envelope, at most 13 sections and never more than one section per category.
- `userInstructions` *(v2+, optional)*: the person's own standing instruction from Settings. Version 1 requests omit the property.
- `consentRevision`: the account policy revision used by the projection.
- `providerCapabilities`: client decoding/playback capabilities, not provider controls.

The server owns model selection, stable prompts, schemas, reasoning effort, caching boundaries, output caps, moderation, repairs, safety identifiers, attempt graph, and credit/cost charging.

### Context envelope (v4, with v1–v3 compatibility)

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
| `personalMemory` | `personalMemory` | Up to 30 confirmed, correctable statements with provenance |
| `knowledge` | — | Query-selected Knowledge records with matched excerpts and match reasons |

Only the last four are consent-gated (`sensitiveContextCategories`). The rest
project records the person already sees inside LifeBoard and ride on the
request's own authorization, so widening the list does not widen what a grant
means.

Two conventions hold across every schema:

- **V3+ sections carry availability metadata.** `complete`, `partial`, or
  `unavailable`, optional known counts, bounded partial reasons, and stable
  source identifiers power honest receipts and exclusions. Conversation
  summaries are rejected in v3 and later.

- **V4 requires turn context and selection provenance.** Every section has one
  or more reasons from the closed set `routeBaseline`, `explicitReference`,
  `semanticMatch`, `linkedRecord`, and `operationalRisk`.

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

### User instructions (v2+)

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
| `capture` | Structured | Billable | Interpret one to three bounded capture commands; local policy retains execution authority |
| `navigation` | Structured | Unmetered | Return a closed navigation target and optional query for local resolution |
| `plan` | Structured | Billable | Prepare a reviewable plan proposal |
| `planRepair` | Structured | Included repair | Repair a bounded invalid plan |
| `fieldSuggestion` | Structured | Unmetered | Suggest bounded capture fields |
| `memoryCandidate` | Structured | Unmetered | Normalize a possible durable memory for local user confirmation |
| `topThree` | Structured | Billable when explicit | Select at most three priorities |
| `taskBreakdown` | Structured | Billable | Create bounded, reviewable steps |
| `dailyBrief` | Structured | Billable | Name what is fixed, what fits, and the tradeoff |
| `universalInputClassification` | Structured | Unmetered | Classify submitted universal input |
| `dynamicChips` | Structured | Unmetered | Produce bounded next-prompt chips |
| `journalAnswer` | Text | Billable | Answer from explicitly granted journal evidence |
| `knowledgeAnswer` | Text | Billable | Answer from route-selected, eligible Knowledge evidence |
| `shortcutsAnswer` | Text | Billable | Return a bounded Siri/Shortcuts answer |
| `debugSmoke` | Text | Environment policy | Internal end-to-end qualification |

Every structured route has its own strict schema, bounds, enums, identifier rules, and semantic validator. Identifiers must originate in supplied context; outputs cannot invent mutation authority. One unmetered repair is allowed only for routes whose policy permits repair. Final schema or semantic failure releases reservations.

`navigation` returns only a member of the closed `EvaNavigationTarget` set and an optional bounded query. It never returns an arbitrary deep link or authoritative record ID. The device maps a general target to a known surface or resolves the query against eligible local records, including protection and disambiguation checks.

`capture` returns one to three commands from a strict discriminated union. Current families cover body mass, note capture, journal append, hydration, mood, tracker delta, and life-moment append. Server validation checks shape and bounds; local authority policy independently checks today-only scope, batch limits, prohibited domains, idempotency, persistence, receipt creation, and undo. Medication/dose, nutrition/calories/fasting, destructive, historical, future, or mixed high-risk operations never enter direct execution.

`memoryCandidate` creates no durable memory. The response is a concise candidate that the app may show for confirmation, editing, or rejection. Only the local memory store can persist it.

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
| `adult_eligibility_required` | Known under-13 denial, or complete a legally required regional age decision |
| `attestation_required` | Re-register device trust; simulator cannot qualify |
| `consent_required`, `consent_revision_conflict` | Review or reload context permissions |
| `daily_quota_exhausted` | Show rolling quota and next availability; do not retry automatically |
| `rate_limited` | Retry only after the supplied delay |
| `budget_exhausted` | Offer explicit Offline EVA |
| `input_rejected`, `output_rejected` | Explain safe limitation; do not log content |
| `schema_invalid` | Correct the client body or server result; no charge |
| `provider_unavailable`, `configuration_unavailable` | Retry or offer explicit Offline EVA |
| `request_cancelled` | Preserve settled client text; allow a new run |
| `client_upgrade_required` | Require a compatible app version |

Replaying a completed billable `requestId` never charges again. Because v1 deliberately stores no answer content, it returns a stable no-charge replay error and requires a new request ID for regeneration.

## Rolling quota and speech

Accounts receive 20 successful billable answers during the preceding rolling 24 hours. Active reservations plus committed timestamps count atomically, so the 21st concurrent request is rejected before provider work. A timestamp commits only for a nonempty, nonrefusal, moderated, valid result and expires individually after 24 hours; failures, refusals, cancellations, moderation responses, and internal repairs release their reservation. Background helpers have a separate 100-success rolling limit and 10/minute burst limit. `/credits` projects the rolling quota for one supported legacy client version.

The first successful speech rendering is included through a single-use signed ticket. Local replay is free; paid regeneration after cache loss uses the helper quota and requires explicit confirmation.

Speech accepts at most 12,000 source characters, validates the exact SHA-256-bound ticket, splits sentence-aware chunks at 4,000 characters, and streams PCM without server persistence. Spoken output is independent of text availability. Cloud speech-to-text and full-duplex conversation are outside this contract.

## Versioning

- `/v1` paths remain stable for compatible additions. Contract versions 1, 2, 3, and 4 are admitted; signed runtime configuration schema v2 publishes `contractVersions: [1, 2, 3, 4]`.
- v2 introduced typed context and optional user instructions while keeping legacy omission behavior.
- v3 requires section availability metadata and rejects the legacy `conversationSummary` category.
- v4 requires `turnContext` and at least one valid `selectionReason` on every included section.
- **Deploy order is not load-bearing, by design.** Version negotiation lets a newer app select the highest mutually supported contract. Hardcoding the client ceiling can turn an otherwise compatible rollout into `schema_invalid` failures.
- **One payload shape per category, regardless of how the projection went.** A degraded projection emits the same planning object with an empty `tasks` array and the rendered text in `renderedOverview` — never a differently-shaped object. `contractVersion` is decided per request while payloads are built in several places, so if fallback paths emitted their own shapes, any turn that took one would be rejected. `EvaContextSectionFactory` is the only sanctioned constructor; nothing may bypass it.
- New required fields, changed semantics, or incompatible output schemas require a new contract version and dual-read migration period.
- Runtime configuration publishes supported contract versions and minimum client version.
- The client rejects invalid signatures, environment mismatch, unsupported versions/models, future documents, or monotonic rollback.
- Debug points only at staging; Release points only at production. No build may derive the API origin from the marketing domain at runtime.

## Route and context relationship

The route manifest is enforced client-side during projection and server-side through schema and consent validation. A route's eligible categories are a maximum; the request includes only relevant records that pass local protection, exclusion, consent, and whole-turn budget checks. `navigation`, `universalInputClassification`, and `debugSmoke` require no stored-life context. See [Context and prompt architecture](CONTEXT_AND_PROMPT_ARCHITECTURE.md) for the exact manifest, selection reasons, and route caps.

## Mutation and navigation boundary

The network response is never proof that a change occurred. Completed state exists only after the local resolver or executor returns a result and, for direct capture, persists an assistant-action run with a receipt and 30-minute undo descriptor. See [Navigation and capture authority](NAVIGATION_AND_CAPTURE_AUTHORITY.md) for the complete authority matrix and recovery behavior.
