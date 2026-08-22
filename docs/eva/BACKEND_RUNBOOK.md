# EVA Cloud Backend Runbook

**Service:** Cloudflare Worker in `Services/EVACloud`
**Contract:** `Shared/EVACloudContracts`
**Production API:** `https://api.getlifeboard.app`
**Last verified:** 2026-08-21

## Current environment state

| Environment | Client | Policy | Text routes | TTS | Notes |
|---|---|---|---|---|---|
| Development | Local Worker/manual clients | Fail closed unless explicitly seeded | Operator controlled | Operator controlled | Local secrets only in ignored `.dev.vars` |
| Staging | Debug iOS/Catalyst | Signed schema v2; contract versions 1–4 | **All enabled** | **Enabled** | Explicit Debug end-to-end qualification policy |
| Production | Release iOS/Catalyst | Signed schema v2 disabled policy; contract versions 1–4 | Disabled | Disabled | Custom domain live; no production model traffic |

Staging is intentionally fully enabled so Debug builds can exercise authentication, age, trust, Luna, and spoken output end to end. Production remains disabled until the release gates pass. Do not copy staging policy to production as a convenience.

The production zone also serves the GitHub Pages marketing site. EVA changes may touch only `api.getlifeboard.app` and the Worker/custom-domain configuration. Never alter or proxy the apex `getlifeboard.app` or `www.getlifeboard.app` records during an EVA deploy or rollback.

## Architecture and state ownership

- Hono owns routing, request IDs, headers, body ceilings, authentication middleware, and stable error envelopes.
- `AuthChallengeDO` owns one-time nonce/challenge records, atomic replay rejection, the server-random idempotent guest-ID mapping, canonical Apple-link locks, and durable cross-object guest-link reconciliation.
- `EvaAccountDO` owns guest/Apple identity state, encrypted Apple refresh credentials, session families, device risk/trust, optional age evidence, consent revisions/review state, rolling quota reservations, request/speech lifecycles, rolling account cost, and deletion state.
- `GlobalBudgetDO` owns account-scoped maximum-cost reservations, actual commitments/releases, daily budget, threshold signals, and the emergency gate.
- `EVA_CONFIG` KV owns a durable signed-policy source. It does not own secrets or account data.
- Analytics Engine receives content-free operational and cost events.
- OpenAI receives moderated, bounded requests with `store: false`; no tools, web/file search, or server conversation chain is enabled.

There is no D1, R2, Queues, Redis, or server conversation/audio persistence in the current architecture.

## Local verification

Use the repository-pinned Node 24 runtime. If a shell resolves an older Node, load the pinned toolchain before invoking Wrangler. Copy `.dev.vars.example` to ignored `.dev.vars` only for local integration work; never paste credentials into source, output, issues, documentation, or commits.

```sh
npm ci
npm run contracts:check
npm run backend:typecheck
npm run backend:test
npm --workspace @lifeboard/eva-cloud run deploy:dry-run
npm run check
```

The Worker suite runs in Cloudflare's runtime with SQLite-backed Durable Objects. Pull requests mock OpenAI and Apple. Live smoke is conditional, explicit, and staging-only.

## Provisioning

Development, staging, and production KV namespaces, Analytics Engine datasets, Durable Object bindings, environment-specific keys, OpenAI credentials, and Apple credentials are provisioned. Cloudflare stores private values. The Sign in with Apple key belongs to Team ID `CJ43UNM3AR`; its private value must never leave secret storage.

Required secret names are declared in Wrangler and mirrored by `.dev.vars.example`:

- `OPENAI_API_KEY`
- `APPLE_TEAM_ID`, `APPLE_KEY_ID`, `APPLE_PRIVATE_KEY_P8`, `APPLE_CLIENT_IDS`
  for Sign in with Apple
- `APPLE_DEVICECHECK_KEY_ID`, `APPLE_DEVICECHECK_PRIVATE_KEY_P8` from a
  separate Apple private key with DeviceCheck enabled
- `APPLE_ROOT_CERTIFICATES_BASE64`
- `ACCOUNT_HMAC_KEY`
- `SESSION_SIGNING_PRIVATE_KEY`
- `TOKEN_ENCRYPTION_KEY`
- `CONFIG_SIGNING_PRIVATE_KEY`
- `APP_ATTEST_ENVIRONMENT`

Provision a new environment as follows:

1. Create its KV namespace and Analytics Engine dataset; commit only public binding IDs/names in `wrangler.toml`.
2. Generate independent session/config Ed25519 keys plus AES-GCM and HMAC material. Never reuse between environments.

   ```sh
   npm --workspace @lifeboard/eva-cloud run keys:generate -- staging
   npm --workspace @lifeboard/eva-cloud run keys:generate -- production
   ```

   The helper writes mode-0600 files under ignored `.eva-provisioning/<environment>/` and does not print private material. Transfer secrets, pin the raw base64url Ed25519 configuration public key in the matching Xcode configuration, then securely remove local provisioning artifacts.
3. Upload secrets with `wrangler secret put --env <environment>`. Use Apple PKI roots appropriate to App Store transaction verification; never trust a root supplied by the request JWS.
4. Confirm every Durable Object migration is forward-only. Never remove or rename a deployed class without an explicit migration tag.
5. Seed a disabled schema-v2 policy, validate it remotely, then enable capabilities only through a higher-version approved policy.
6. For production, attach only `api.getlifeboard.app`, validate TLS, and register Apple's server-notification endpoint at `/v1/auth/apple/events`.

Deployment preflight checks public bindings, origins, pins, price policy, and—when requested—remote secret names without reading values:

```sh
npm run backend:preflight:staging
npm run backend:preflight:production
```

## Runtime configuration

KV key `runtime-config-v2` contains the durable policy revision:

- monotonic `version`, environment, and policy source timestamp;
- `cloudState: enabled | degraded | disabled`;
- independent `ttsEnabled` and per-route switches;
- Luna/TTS model and voice;
- route budgets, structured/billable flags, supported contract versions, and minimum client version;
- maintenance and Offline EVA recovery policy;
- independent guest bootstrap, guest inference, Apple linking, rollout percentage, 20-answer quota, 100-helper quota, age-policy mode, and versioned price schedule.

Enabled/degraded cloud requires `priceSchedule.approved: true`. TTS cannot be enabled while cloud is disabled. Missing, malformed, wrong-environment, future-dated, rolled-back, unapproved, or otherwise invalid policy returns a signed disabled fallback.

The current model identifiers are `gpt-5.6-luna` for text and `tts-1` with `nova` for speech. The worker's fail-closed route ceilings are documented in [Context and prompt architecture](CONTEXT_AND_PROMPT_ARCHITECTURE.md). Runtime policy may reduce those caps but may not increase them beyond code. `capture` and `navigation` are independent switches and should be disabled independently when only the authority surface is affected.

KV policy persistence and client signed-document freshness are intentionally distinct. The Worker accepts an old but otherwise valid monotonic KV policy and stamps a fresh `issuedAt` whenever it signs a response. Clients cache a verified response for six hours and may use the last verified response for seven days. Activation forces a network configuration refresh, so an earlier cached disabled response cannot mask a newly enabled staging policy.

Before any enablement, compare the price schedule with the OpenAI project's actual billing view and the official [Luna](https://developers.openai.com/api/docs/models/gpt-5.6-luna) and [`tts-1`](https://developers.openai.com/api/docs/models/tts-1) model pages. The schedule approved for staging on 2026-08-17 is:

- Luna uncached input: $0.20 per million tokens.
- Luna cached input: $0.02 per million tokens.
- Luna cache write: $0.25 per million tokens (1.25× uncached input).
- Luna output: $1.20 per million tokens.
- `tts-1`: $15.00 per million characters.

Treat these as versioned observations, not permanent constants. A pricing mismatch invalidates cost qualification even if requests technically work.

## Deploy and smoke

Deploy staging first:

```sh
npm run backend:preflight:staging
npm run backend:deploy:staging
```

Then verify health and the signed policy with the non-secret public JWK:

```sh
EVA_STAGING_BASE_URL=https://eva-cloud-staging.saransh1337.workers.dev \
EVA_CONFIG_PUBLIC_JWK='{"kty":"OKP","crv":"Ed25519","x":"..."}' \
npm --workspace @lifeboard/eva-cloud run smoke:staging
```

Authenticated CLI smoke/evaluation may use a short-lived session exported from a qualified signed Catalyst build. Physical iOS smoke remains in-app because each sensitive request requires a fresh App Attest challenge and exact body/path-bound assertion. The privacy-safe evaluation corpus is synthetic. Live evaluation/load requires `EVA_CONFIRM_LIVE_EVAL=YES` or `EVA_CONFIRM_LIVE_LOAD=YES` to prevent accidental spend.

Physical iOS qualification must prove, in order:

1. One-action guest activation with confirmed context and no Apple sheet.
2. Low-trust and high-trust App Attest/DeviceCheck paths with the same 20-answer allowance.
3. Optional Apple link, usage union, consent intersection/re-review, guest-session revocation, and reinstall recovery.
4. Known-under-13 denial, ordinary unknown-age access, and mandatory-region fail-closed behavior.
5. Token refresh rotation and guest/Apple deletion.
6. Exactly 20 rolling successful answers, 100 rolling helper successes, 10/minute helper burst, plus refusal/moderation/cancellation/replay reconciliation.
7. TTS ticket, PCM first audio, cancellation, playback completion, and accounting.
8. Navigation general target, named resolution, ambiguity, protected/no-match behavior, and schema drift fixtures.
9. Deterministic and cloud capture across every allowlisted family, prohibited-domain rejection, duplicate retry, persisted receipt, and 30-minute undo.
10. Contract-v4 route manifest, turn context, selection reasons, whole-record budget drops, and sensitive/excluded-data subtraction cases.

`ACCOUNT_HMAC_KEY` is also the secret guest-rollout cohort key. An empty key must fail provisioning; never replace it with an unkeyed hash or a client-visible salt. Cohorts must remain stable for the same bootstrap ID and unpredictable before a request reaches the Worker.

DeviceCheck bit ownership is developer-team-wide: Cloud EVA reserves bit 0 for “this Apple device has previously bootstrapped a guest account” and preserves bit 1. The query and update run after bootstrap through `waitUntil`, never on the activation critical path. A query failure must not update either bit and never changes the selected rolling allowance.

DeviceCheck uses its dedicated capability-enabled private key. Development and
staging App Attest environments call Apple's development DeviceCheck host;
production calls the production host. The deployment preflight requires both
DeviceCheck secrets so a silently misconfigured abuse signal cannot ship.

Apple-link qualification must inject a failure after each of: pending-record creation, guest freeze, canonical bootstrap, quota/consent import, guest tombstone, and guest-mapping deletion. A normal Apple exchange must finish the pending reconciliation without granting a second allowance. Also verify that Apple deletion reauthentication rejects a different Apple subject while preserving the original session.

Simulator may validate UI navigation and request construction but cannot satisfy production-like App Attest. Do not add a bypass to make simulator smoke appear complete.

Production deployment uploads a Worker version from the protected branch with environment approval. Runtime policy remains disabled until staging, privacy, security, evaluation, load, and TestFlight gates pass. Application secrets remain in Cloudflare; GitHub Actions needs only scoped Cloudflare deployment credentials.

These requirements are the operational part of roadmap P0. [Eva roadmap status and gap analysis](EVA_ROADMAP_STATUS.md) owns the consolidated exit criteria; this runbook owns the executable deployment and rollback procedure.

Guest rollout is server-compatible first: deploy the Worker with `guestAccess.bootstrapEnabled: false`, then ship the client. Enable bootstrap and inference at 1%, 10%, 50%, and 100% using monotonic signed-policy versions. At each stage hold on activation-review-to-first-answer conversion, bootstrap failures, cost per successful completion, accounts per network/device signal, quota rejection, moderation, and deletion success. Bootstrap and guest inference are separate switches so acquisition can stop without stranding existing guest sessions.

## Context envelope and budgets

Route `inputTokenCap` in the signed runtime configuration is not advisory — it is
what the client reads to size its context envelope. Lowering it is therefore a
live lever on payload size, moderation latency, and cost per turn, and takes
effect on the next request without an app release.

- `chat` and `dailyBrief` run at `medium` reasoning effort. Both weigh capacity
  against ambition, which is reasoning work rather than retrieval; `low` was
  chosen when the client could only send ~1,500 tokens and there was nothing to
  reason over. Lower it first if latency regresses.
- A client that cannot verify the signed configuration falls back to the offline
  budget, which is roughly a tenth the size. A sudden drop in `inputTokens`
  across accounts usually means configuration verification is failing, not that
  people are asking shorter questions.
- Watch `cachedInputTokens` on the second turn of a thread. It should be
  substantial; near-zero means the cacheable prefix is being invalidated, which
  raises cost without failing anything.
- Input moderation chunks oversized envelopes and evaluates chunks concurrently.
  A flagged chunk fails the whole request, so `input_rejected` can rise from
  projected content rather than from what the person typed.
- Version 4 requests must contain valid turn context and at least one valid
  selection reason on every section. A rise in `schema_invalid` immediately after
  a client rollout should be split by contract version and the missing-field path.
- The route manifest is a privacy boundary. Unexpected category/route pairs,
  sensitive grant mismatch, or excluded-record influence require privacy-incident
  handling even when provider output appears benign.

## Operational signals

Monitor by environment and route:

- activation review, guest bootstrap, Apple link, refresh stage, trust tier, and stable error;
- App Attest/DeviceCheck/App Transaction/age-policy outcomes;
- consent conflicts and cloud readiness reason;
- accepted, completed, refused, rejected, cancelled, repaired, and failed requests;
- contract/prompt/config versions, section counts, category counts, selection reasons, and budget-drop counts;
- navigation resolution outcome and capture policy/execution/receipt/undo outcome, without queries or command bodies;
- TTFT, total latency, token/cache use, output size, and TTS first-audio latency;
- quota reserves/commits/releases/individual expirations and speech ticket transitions;
- account/global estimated and actual cost plus 50/75/90% thresholds;
- Offline EVA recovery offers and explicit selections.

Never add payload sampling to improve observability. Correlate a network `requestID`, logical `runID`, and conversation `threadID` using content-free stages. See [Evaluation and observability](EVALUATION_AND_OBSERVABILITY.md) for event definitions and release gates.

## Rollback and kill switches

- Speech incident: publish a higher policy with `ttsEnabled: false`.
- Guest acquisition incident: set `guestAccess.bootstrapEnabled: false` while existing guest inference remains available.
- Guest inference incident: set `guestAccess.inferenceEnabled: false`; Apple-linked Cloud EVA and Offline EVA remain available.
- Apple-link incident: set `guestAccess.appleLinkingEnabled: false` without disabling guest answers.
- Route incident: disable only the affected route.
- Context incident: disable the affected route and, where available, remove the implicated category from eligibility through a higher signed policy; do not rely on prompt wording as containment.
- Capture/navigation incident: disable the affected route. Deterministic local behavior remains governed by the app's local feature and authority policy and may require a client-side kill switch or release if it is the source.
- Partial outage: use `cloudState: degraded` with a localized maintenance message.
- Privacy, auth, accounting, or broad safety incident: publish `cloudState: disabled` immediately.
- Code regression: keep the higher disabled policy, then restore the prior Worker version.
- Cost spike: close the global budget, disable cloud, and reconcile before re-enable.

Never reduce a configuration version already accepted by clients. Never weaken session binding, age policy, consent, quota, or budget gates to restore availability. Low-trust access is an intentional policy tier, not a bypass. Follow `INCIDENT_RUNBOOK.md` for severity, containment, and recovery.
