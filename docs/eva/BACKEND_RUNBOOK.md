# EVA Cloud Backend Runbook

## Local verification

Use Node.js 24 or newer. Copy `.dev.vars.example` to the ignored `.dev.vars` only for local integration work and replace placeholders locally. Never paste credentials into source, logs, issues, or commits.

```sh
npm ci
npm run contracts:check
npm run backend:typecheck
npm run backend:test
npm --workspace @lifeboard/eva-cloud run deploy:dry-run
```

The unit suite uses the Cloudflare Workers runtime and SQLite-backed Durable Objects. Live OpenAI and Apple tests are intentionally excluded from pull requests.

## Provisioning an environment

### Provisioning checkpoint — 2026-08-15

Development, staging, and production KV namespaces are provisioned in the Cloudflare account and the corresponding IDs are committed in `Services/EVACloud/wrangler.toml`. The disabled schema-v2 runtime document (`version: 1`, cloud and TTS disabled, unapproved price schedule) has been seeded and read back successfully in all three namespaces. Environment-isolated OpenAI, HMAC, signing, encryption, Apple trust-root, Apple client, Apple team, and App Attest configuration secrets are present in all three Workers.

The Sign in with Apple key for the app's actual Team ID `CJ43UNM3AR` is now uploaded to development, staging, and production. The private key exists only in Cloudflare secret storage; do not paste or commit it. Staging is deployed with cloud and TTS disabled and has passed remote health/config verification. Production is attached to `api.getlifeboard.app`; the marketing apex and `www` remain on the imported GitHub Pages records.

1. Create a KV namespace and replace the matching placeholder ID in `Services/EVACloud/wrangler.toml`.
2. Confirm Durable Object migrations are forward-only. Never remove or rename a deployed class without a new migration tag.
3. Add every secret named in `.dev.vars.example` with `wrangler secret put --env <environment>` (omit `--env` for development).
   `APPLE_ROOT_CERTIFICATES_BASE64` is a comma-separated list of base64-encoded DER certificates
   downloaded from [Apple's PKI root-certificate page](https://www.apple.com/certificateauthority/).
   Include the Apple roots that validate the App Store signing chain (currently G2 and G3); do
   not fetch trust roots from a request JWS. Verification uses
   [Apple's App Store Server Library for Node](https://github.com/apple/app-store-server-library-node).
4. Generate separate Ed25519 JWKs for session and configuration signing plus independent 32-byte
   AES-GCM and HMAC keys. The helper below writes mode-0600 files beneath the ignored
   `.eva-provisioning/<environment>/` directory and never prints private values. Transfer them into
   the approved secret manager and delete the local files afterward. Never reuse generated material
   between environments.

   ```sh
   npm --workspace @lifeboard/eva-cloud run keys:generate -- staging
   npm --workspace @lifeboard/eva-cloud run keys:generate -- production
   ```

   The `EVA_CONFIG_SIGNING_PUBLIC_KEY` value in `public-pins.json` is the raw 32-byte Ed25519 public
   key encoded as base64url; pin the staging value in Debug and the production value in Release.
5. Upload a schema-v2 runtime document to KV key `runtime-config-v2`. Its version must be at least
   `MIN_RUNTIME_CONFIG_VERSION`, its price schedule must be explicitly approved before cloud can be
   enabled, and it must be reissued within seven days. Keep `cloudState`, route switches, and `ttsEnabled`
   independent. Missing or invalid configuration returns a signed, disabled document.
6. For production, attach `api.getlifeboard.app`, configure Apple’s callback to `/v1/auth/apple/events`, and verify TLS/DNS. The zone is active, nameservers are `angela.ns.cloudflare.com` / `jihoon.ns.cloudflare.com`, the custom domain is attached, and the imported GitHub Pages apex/www records have been verified. Apple callback configuration remains a release gate.
7. Run health, signed-config, mocked contract, Luna text/structured/moderation/cancellation, and PCM speech smoke tests.
8. On Catalyst staging and production, confirm a missing, wrong-bundle, wrong-environment, expired,
   or untrusted signed App Transaction fails closed before account bootstrap.

Deployment preflight deliberately fails while KV IDs, client origins, public-key pins, or remote
secrets are missing. Run it before every upload:

```sh
npm run backend:preflight:staging
npm run backend:preflight:production
```

CI adds `--remote-secrets` and verifies the names provisioned on the target Worker without reading
or printing secret values.

Public staging smoke requires only the non-secret configuration public JWK:

```sh
EVA_STAGING_BASE_URL=https://your-staging-worker.workers.dev \
EVA_CONFIG_PUBLIC_JWK='{"kty":"OKP","crv":"Ed25519","x":"..."}' \
npm --workspace @lifeboard/eva-cloud run smoke:staging
```

An authenticated CLI smoke/evaluation uses a short-lived session exported from a qualified signed
Catalyst build. Physical-iOS smoke remains in-app because every request needs a fresh App Attest
challenge and body/path-bound assertion. Live evaluation and load tools require the explicit
`EVA_CONFIRM_LIVE_EVAL=YES` or `EVA_CONFIRM_LIVE_LOAD=YES` acknowledgement so they cannot incur model
cost accidentally. The corpus in `Services/EVACloud/eval/privacy-safe-corpus.json` is synthetic only.

Application secrets live in Cloudflare, while GitHub contains only `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID`. Production workflow approval uploads a version; progressive traffic movement is a separate reviewed action.

## Rollback and kill switches

- Publish a higher configuration version with `cloudState: disabled` to offer Offline EVA without deploying an app or Worker.
- Set `ttsEnabled: false` to disable spoken output independently.
- Use the previous uploaded Worker version for code rollback.
- Do not reduce a signed configuration version already accepted by clients. Publish a higher version that restores the prior values.
- If costs spike, close the global budget and disable cloud in signed config before investigating. Do not weaken auth, age, consent, or attestation gates to restore availability.
