# EVA Cloud Backend Runbook

**Service:** Cloudflare Worker in `Services/EVACloud`
**Contract:** `Shared/EVACloudContracts`
**Production API:** `https://api.getlifeboard.app`
**Last verified:** 2026-08-17

## Current environment state

| Environment | Client | Policy | Text routes | TTS | Notes |
|---|---|---|---|---|---|
| Development | Local Worker/manual clients | Fail closed unless explicitly seeded | Operator controlled | Operator controlled | Local secrets only in ignored `.dev.vars` |
| Staging | Debug iOS/Catalyst | Signed v2, version 2 | **All enabled** | **Enabled** | Explicit Debug end-to-end qualification policy; Worker version `360709f0-74d6-4eaf-8be4-6ad967fd2fd2` |
| Production | Release iOS/Catalyst | Signed v2-compatible disabled policy, version 1 | Disabled | Disabled | Custom domain live; no production model traffic |

Staging is intentionally fully enabled so Debug builds can exercise authentication, age, trust, Luna, and spoken output end to end. Production remains disabled until the release gates pass. Do not copy staging policy to production as a convenience.

The production zone also serves the GitHub Pages marketing site. EVA changes may touch only `api.getlifeboard.app` and the Worker/custom-domain configuration. Never alter or proxy the apex `getlifeboard.app` or `www.getlifeboard.app` records during an EVA deploy or rollback.

## Architecture and state ownership

- Hono owns routing, request IDs, headers, body ceilings, authentication middleware, and stable error envelopes.
- `AuthChallengeDO` owns one-time, expiring nonce/challenge records and atomic replay rejection.
- `EvaAccountDO` owns pseudonymous account status, encrypted Apple refresh credentials, session families, device trust, age leases, consent revisions, credits, request/speech lifecycles, rolling account cost, and deletion state.
- `GlobalBudgetDO` owns account-scoped maximum-cost reservations, actual commitments/releases, daily budget, threshold signals, and the emergency gate.
- `EVA_CONFIG` KV owns a durable signed-policy source. It does not own secrets or account data.
- Analytics Engine receives content-free operational and cost events.
- OpenAI receives moderated, bounded requests with `store: false`; no tools, web/file search, or server conversation chain is enabled.

There is no D1, R2, Queues, Redis, or server conversation/audio persistence in v1.

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
- credit policy and versioned price schedule.

Enabled/degraded cloud requires `priceSchedule.approved: true`. TTS cannot be enabled while cloud is disabled. Missing, malformed, wrong-environment, future-dated, rolled-back, unapproved, or otherwise invalid policy returns a signed disabled fallback.

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

1. Apple challenge/sheet/code exchange and session persistence.
2. App Attest key registration and fresh assertion.
3. Declared Age Range 18+ lease.
4. Credits and authoritative consent load.
5. Token refresh rotation.
6. Chat plus every structured route, refusal/moderation, cancellation, replay, and credit reconciliation.
7. TTS ticket, PCM first audio, cancellation, playback completion, and accounting.

Simulator may validate UI navigation and request construction but cannot satisfy production-like App Attest. Do not add a bypass to make simulator smoke appear complete.

Production deployment uploads a Worker version from the protected branch with environment approval. Runtime policy remains disabled until staging, privacy, security, evaluation, load, and TestFlight gates pass. Application secrets remain in Cloudflare; GitHub Actions needs only scoped Cloudflare deployment credentials.

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

## Operational signals

Monitor by environment and route:

- challenge/exchange/refresh stage and stable error;
- App Attest/App Transaction/age lease outcomes;
- consent conflicts and cloud readiness reason;
- accepted, completed, refused, rejected, cancelled, repaired, and failed requests;
- TTFT, total latency, token/cache use, output size, and TTS first-audio latency;
- credit reserves/commits/releases/expirations and speech ticket transitions;
- account/global estimated and actual cost plus 50/75/90% thresholds;
- Offline EVA recovery offers and explicit selections.

Never add payload sampling to improve observability. Use request IDs and content-free stages.

## Rollback and kill switches

- Speech incident: publish a higher policy with `ttsEnabled: false`.
- Route incident: disable only the affected route.
- Partial outage: use `cloudState: degraded` with a localized maintenance message.
- Privacy, auth, accounting, or broad safety incident: publish `cloudState: disabled` immediately.
- Code regression: keep the higher disabled policy, then restore the prior Worker version.
- Cost spike: close the global budget, disable cloud, and reconcile before re-enable.

Never reduce a configuration version already accepted by clients. Never weaken authentication, adult eligibility, consent, attestation, credit, or budget gates to restore availability. Follow `INCIDENT_RUNBOOK.md` for severity, containment, and recovery.
