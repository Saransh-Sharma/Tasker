# EVA Cloud Migration TODO

This file is the implementation ledger for the Luna text and spoken-output migration. A task is checked only after the stronger production-readiness gate for that task passes. External console and production rollout tasks remain unchecked until they are actually completed.

## Production-readiness correction — 2026-08-14

The first implementation pass established the end-to-end architecture, but its original checkboxes treated a working skeleton as completion. The remaining work below is authoritative. Earlier phase summaries are retained as implementation history and no longer imply production readiness.

### A — Reproducible source tree

- [x] Pin Node 24 for local and CI Worker tooling.
- [x] Remove stale deleted onboarding source references while preserving the replacement Life Map implementation.
- [x] Repair the widget target's in-repository `LifeBoardTokens` package-link contract.
- [x] Refactor all file-size ratchet violations without raising limits.
- [x] Review EVA cloud localization and intentionally refresh localization snapshots.
- [x] Pass clean iOS and Catalyst builds plus every repository guardrail that is runnable with installed platform components. The target-membership probe passes iOS, then stops only because this machine does not have the watchOS 26.5 simulator runtime installed.

### B — Contracts and fail-closed runtime configuration

- [x] Add strict route-specific schemas and TypeScript/Swift compatibility fixtures.
- [x] Add server semantic validators for identifiers, dates, commands, list bounds, and mutation authority.
- [x] Replace the generic structured payload envelope with each route's actual schema.
- [x] Add exact `speechSource` completion data for structured spoken output.
- [x] Add signed runtime configuration v2 with cloud state, route switches, maintenance, offline recovery, and monotonic versioning.
- [x] Fail closed when KV configuration is missing, malformed, tampered, stale, or rolled back.
- [x] Supply real distinct staging and production origins/config public keys through Xcode build configuration. Staging uses the provisioned `workers.dev` origin and production is pinned to `https://api.getlifeboard.app`; each build has its own Ed25519 verification pin.

### C — Security, identity, age, and abuse controls

- [x] Apply the 256 KiB body limit before authentication and attestation work.
- [x] Add endpoint-specific edge rate-limit bindings and half-rate Catalyst account limits.
- [x] Declare required Worker secrets in deployment configuration.
- [x] Cross-check Apple's token-exchange identity against the verified identity token.
- [x] Observe Sign in with Apple credential revocation and clear the local cloud session.
- [x] Use build-specific development/production App Attest entitlements.
- [x] Pass fixture-backed adversarial App Attest tests for certificate chain/validity, RP ID, environment, key ID, nonce, signature, request binding, and counter replay.
- [x] Pass synthetic Catalyst risk-evidence tests for missing proof, bundle/environment mismatch, malformed device evidence, and absent trust roots.
- [ ] Pass real Sandbox and Production Catalyst App Transaction JWS-chain tests with Apple-issued evidence.
- [x] Revalidate Declared Age Range at activation and within each 24-hour cloud-use period; expire stale server eligibility.

### D — Exact, crash-safe accounting

- [x] Add an alarm-reconciled request lifecycle: reserved, running, committed, released, expired.
- [x] Make every credit and cost transition idempotent, including completed-request replay.
- [x] Scope global budget reservation keys by account and request.
- [x] Reserve the full allowed attempt graph before upstream work.
- [x] Replace the account fixed cost window with rolling hourly buckets over 24 hours.
- [x] Move model/moderation/speech prices to a versioned, environment-approved schedule.
- [x] Emit content-free reservation, cost, cache, and budget-threshold telemetry.
- [x] Pass concurrency, cancellation/release, replay, expiry, one-credit, concurrent-speech, and alarm-driven simulated-interruption accounting tests.

### E — Luna safety and spoken-output completion

- [x] Treat projected context as delimited untrusted input and include it in moderation.
- [x] Detect explicit refusals and incomplete Responses results.
- [x] Retry only transient pre-delta transport, timeout, 429, and 5xx failures.
- [x] Record privacy-safe TTFT, completion latency, usage, cache, repair, refusal, and cost telemetry.
- [x] Persist speech tickets and exact hashes in protected client storage for their lifetime.
- [x] Remove speech-ticket state with chat deletion and LRU eviction.
- [x] Release the audio session and transition playback to idle after the final buffer.
- [x] Pass text/speech failure, cancellation, accounting, and playback-completion state tests. Physical audio-route and interruption qualification remains a staging/TestFlight gate.

### F — Staging, evaluation, and release

- [x] Provision real KV namespaces and replace placeholder IDs for development, staging, and production.
- [x] Provision environment-isolated Cloudflare, OpenAI, and Apple secrets/keys. OpenAI, generated signing/encryption/HMAC material, Apple team/client IDs, Apple trust roots, App Attest environment, and the Sign in with Apple key for Team ID `CJ43UNM3AR` are uploaded in development, staging, and production. Private values remain only in Cloudflare secret storage.
- [x] Add executable staging smoke, privacy-safe Luna eval, and load-test tools.
- [x] Add deployment preflight and environment-isolated key-generation tooling that never prints private values.
- [x] Deploy staging with cloud and TTS disabled and observe a clean remote workflow. Staging Worker version `34a172bc-97e5-4fe6-a4c5-c4a23c802dca` is deployed; `/health` and signed disabled configuration were verified remotely.
- [ ] Pass real-device iOS, signed Catalyst, Luna, moderation, and TTS staging smoke tests.
- [ ] Meet structured-validity and latency acceptance thresholds at 10× launch load.
- [ ] Complete ZDR, privacy, threat-model, App Store, and TestFlight gates. Cloudflare imported the existing GitHub Pages records, the GoDaddy nameserver cutover completed, the production custom domain is attached, and the marketing apex/www paths were verified through Cloudflare without changing their GitHub Pages targets. The Apple App ID server-notification configuration was submitted for `https://api.getlifeboard.app/v1/auth/apple/events`; Apple portal propagation remains a final console verification.
- [ ] Roll out text internal → 5% → 25% → 100%, then roll out TTS independently.

## Phase 0 — Repository and contracts

- [x] Inventory and preserve existing uncommitted onboarding work.
- [x] Rename the root npm package and add npm workspaces.
- [x] Add the backend and shared-contract workspaces.
- [x] Extend ignore rules for Worker secrets and generated state.
- [x] Define the v1 routes, requests, errors, events, consent, credits, and speech contracts.
- [x] Add TypeScript and Swift contract compatibility tests and pass them locally.
- [x] Add backend CI with JavaScript, Worker, iOS build, guardrail, staging, and production-upload jobs.
- [ ] Observe the first clean remote CI run on GitHub.
- [x] Complete backend, privacy, API, and incident runbooks.

## Phase 1 — Backend foundation

- [x] Add the Worker entry point, validation, request IDs, and security headers.
- [x] Add development, staging, and production Wrangler environments.
- [x] Add AuthChallengeDO, EvaAccountDO, and GlobalBudgetDO with migrations.
- [x] Add KV, edge rate-limit, and analytics bindings.
- [x] Production-harden signed runtime configuration and health endpoints with fail-closed v2 behavior.
- [x] Add content-free telemetry and Worker integration tests.

## Phase 2 — Identity, age, and device trust

- [x] Production-harden Sign in with Apple challenge and exchange, including identity cross-check and revocation observation.
- [x] Implement account identifiers, sessions, rotation, logout, and Apple events.
- [x] Production-harden App Attest registration and assertions for iOS, including release entitlement, exact environment matching, certificate validity, and adversarial fixture verification.
- [x] Implement the stricter Catalyst risk policy.
- [x] Production-harden per-device adult eligibility with 24-hour expiry/revalidation.
- [x] Implement recent-authenticated cloud-account deletion.

## Phase 3 — Credits, consent, and budgets

- [x] Implement exact credit ledger and 24-hour refill rules.
- [x] Make reservation, commitment, release, and idempotency crash-safe with expiry reconciliation.
- [x] Implement account-wide consent revisions.
- [x] Complete global and rolling per-account cost fuses with threshold telemetry.

## Phase 4 — OpenAI text

- [x] Add Luna route profiles and prompt registry.
- [x] Complete route-specific Responses structured outputs and semantic validation.
- [x] Production-harden moderation, repair, cancellation, caching, telemetry, and cost accounting.
- [x] Pass mocked OpenAI policy and accounting tests.
- [ ] Pass live staging smoke tests.

## Phase 5 — Apple client foundation

- [x] Add Swift cloud DTOs and SSE decoder.
- [x] Add Keychain sessions and Sign in with Apple.
- [x] Add Declared Age Range and App Attest services.
- [x] Add configuration, credits, and consent clients.
- [x] Add provider seam, cloud provider, MLX provider, and router.
- [x] Preserve LLMEvaluator observable behavior and cancellation.

## Phase 6 — Route migration

- [x] Migrate every documented semantic route.
- [x] Preserve deterministic universal-input preview.
- [x] Remove Apple Foundation Models.
- [x] Keep MLX as permanent optional Offline EVA.

## Phase 7 — Spoken output

- [x] Add speech tickets and included-first-render accounting.
- [x] Add `tts-1` PCM streaming.
- [x] Complete audio-session termination, persistent speech tickets, protected cache integration, disclosure, and playback-completion state tests. Physical audio-route qualification remains in Phase F.
- [x] Add independent TTS capability and kill switch.

## Phase 8 — Product experience

- [x] Add cloud activation, 18+ gate, context selection, and existing-user notice.
- [x] Add just-in-time sign-in, credits, Settings, and account deletion.
- [x] Pass localization, accessibility, and design-system guardrails.

## Phase 9 — Release

- [x] Provision Cloudflare, OpenAI, and Apple secrets and console configuration. Environment secrets, KV, Analytics Engine datasets, and the Apple Sign in with Apple key are provisioned; production DNS/custom-domain attachment and Apple server callback configuration remain outstanding.
- [x] Configure `api.getlifeboard.app`. The Cloudflare zone is active, the production Worker custom domain is attached, and `/health` plus signed `/v1/eva/config` return successfully through the production hostname.
- [ ] Obtain OpenAI Zero Data Retention approval.
- [ ] Complete privacy, security, load, evaluation, and TestFlight gates.
- [ ] Roll out internal, 5%, 25%, and 100% stages.

## Verification evidence — 2026-08-15

- [x] `npm run check` passes with the marketing app, shared contracts, Worker type-check, and Worker tests.
- [x] `npm audit --audit-level=high` reports zero vulnerabilities; local credential-shape and secret-file scans are clean.
- [x] Worker suite passes 36 tests, including fail-closed configuration, request-body ceilings, fixture-backed App Attest chain/environment/nonce/RP-ID/signature/counter verification, age leases, synthetic Catalyst App Transaction and platform binding, concurrent and one-remaining-credit reservations, crash reconciliation, idempotent release/commit, refresh-token reuse, consent revisioning, speech claim/accounting concurrency, mocked moderation, prompt ownership, and versioned cost accounting.
- [x] `wrangler deploy --dry-run --env staging` packages the Worker and all declared bindings.
- [x] The iOS generic simulator build passes with the EVA Cloud implementation.
- [x] Clean iOS Simulator and universal Mac Catalyst builds pass after reconciling the onboarding and widget package-link changes.
- [x] The full `LifeBoardTests` run executes 2,274 tests with four skips and zero failures; this includes six adversarial signed-runtime-configuration tests for valid pins, tampering, missing/wrong pins, stale/future documents, rollback, environment mismatch, and unsupported contracts/models. The shared structured fixtures decode through the Swift wire contract and playback completion is covered independently of AVFoundation scheduling.
- [x] Focused `EvaActivationTests` and `EvaCloudWireContractTests` pass 38 tests with zero failures.
- [x] EVA's Knowledge provider registry has single ownership in the `KnowledgeFeature` Swift package rather than duplicate app/package compilation.
- [x] The production API origin is consistently `https://api.getlifeboard.app`.
- [x] Production DNS cutover preserves the GitHub Pages marketing site: `getlifeboard.app` returns 200 and `www.getlifeboard.app` redirects to the apex through Cloudflare; apex A/AAAA and www CNAME targets remain the imported GitHub Pages records.
- [x] Production custom domain responds through Cloudflare: `https://api.getlifeboard.app/health` returns the production Worker health response and signed `/v1/eva/config` is reachable.
- [x] Plists, entitlements, privacy manifest, accessibility identifiers, localization (1,066 keys), file-size ratchets, module boundaries, directory structure, documentation, frozen contracts, App Intent descriptions, SwiftLint debt, and no-print logging checks pass.
- [x] Offline-provider regression fixtures explicitly select Offline EVA; automatic/cloud production routing still never silently falls back to MLX.
- [x] Staging and production deployment preflight passes local configuration checks and verifies the required remote secret names without reading secret values.
- [ ] Install the watchOS 26.5 simulator runtime to complete the final watch target-membership build probe. This is a local Xcode component prerequisite, not a source or EVA failure.
- [ ] `swift test` remains unsuitable for this iOS-only package graph because `LifeBoardTokens` imports UIKit; Xcode iOS/Catalyst builds and the 2,274-test XCTest run are the authoritative Apple-platform verification.
