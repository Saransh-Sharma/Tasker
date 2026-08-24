# EVA Cloud Migration TODO

This file is the implementation ledger for the Luna text and spoken-output migration. A task is checked only after the stronger production-readiness gate for that task passes. External console and production rollout tasks remain unchecked until they are actually completed.

**Current baseline:** contract v4, signed runtime-configuration schema v2, guest-first activation, and a 13+ product policy. Earlier dated incident entries are retained as historical evidence and may mention the superseded Apple-first/18+ design that was active when those tests ran; they are not the current product contract. Current behavior is defined by [the product and technical guide](CLOUD_EVA_PRODUCT_AND_TECHNICAL_GUIDE.md).

Portfolio state, consolidated priorities, and exit criteria live in [Eva roadmap status and gap analysis](EVA_ROADMAP_STATUS.md). This ledger retains historical evidence, so several unchecked items describe the same P0 release gate. Count the consolidated status report, not raw unchecked boxes, when reporting roadmap progress.

## Production-readiness correction — 2026-08-14

The first implementation pass established the end-to-end architecture, but its original checkboxes treated a working skeleton as completion. The remaining work below is authoritative. Earlier phase summaries are retained as implementation history and no longer imply production readiness.

### Sign in with Apple UUID contract incident — 2026-08-15

- [x] Identify the pre-authentication failure: TypeBox rejected valid Apple exchange and refresh UUIDs because the Worker used an unregistered JSON Schema `uuid` format.
- [x] Replace ambient UUID formats with the canonical shared pattern and reuse shared Apple exchange/refresh schemas.
- [x] Add content-free contract-rejection telemetry that records only endpoint and field names.
- [x] Add TypeScript Worker/contract regressions and a Swift Apple exchange fixture compatibility test.
- [x] Deploy the UUID contract fix to staging and verify the live HTTP boundary: valid Apple exchange UUIDs reach challenge verification, malformed UUIDs remain `schema_invalid`, and a valid refresh request reaches session lookup. Staging Worker version `be990909-ffb2-4c8c-a07e-36a0f8fdfa71`.
- [x] Superseded this Apple-first/18+ qualification step when activation moved to the guest-first 13+ product contract; current physical-device qualification is tracked in the contract-v4 section below.
- [x] Deploy the same code to production while keeping the production Luna/TTS switches disabled until staging acceptance. Production Worker version `44ebe167-8863-4962-a663-c181a705e285`; `api.getlifeboard.app` health and schema boundaries passed, while the GitHub Pages apex and `www` remained healthy.
- [x] Diagnose the second live-device failure: Swift re-encoded the issued UUID in uppercase and selected a different case-sensitive `AuthChallengeDO` name during exchange.
- [x] Canonicalize challenge Durable Object names and add an HTTP issue→uppercase-exchange regression test.
- [x] Add content-free Apple-exchange stage telemetry for live-device diagnosis without retaining credentials or request content.
- [x] Deploy the challenge-key fix and stage telemetry to staging (`8323796f-6db5-48a6-8a1f-97469da14b26`) and production (`43cd8dfe-f0dd-4c6b-9baa-57ccede62820`). Live issue→uppercase-exchange checks advance to identity-token verification; replay remains rejected.
- [x] Confirm on a physical iPhone that Apple challenge/exchange and App Attest registration/assertion succeed after the UUID fixes; staging advances to the age-registration request.
- [x] Diagnose the next live-device failure: synthesized Swift encoding omitted `lowerBound` when Apple supplied no range, while the strict API requires an explicit nullable field. Add a shared eligibility contract/fixture and explicit Swift `null` encoding.
- [x] Correct Declared Age Range gating: `isEligibleForAgeFeatures` reports whether regional Age Assurance obligations apply, not whether `requestAgeRange` is callable. Always request the 18+ range and fail closed only on Apple decline, unavailable service, or a lower bound below 18.
- [x] Deploy the nullable-age/shared-contract Worker build to staging (`60cd79a2-47a8-40bb-9fcb-6159c9d9bc18`) and pass remote `/health` plus the staging Wrangler binding check.
- [x] Pass physical-device 18+ eligibility registration after the nullable-age fix. The current signed-device smoke advanced through Apple exchange, App Attest, and age registration to signed-configuration verification.
- [ ] Pass physical-device signed configuration, credits, consent, refresh, first Luna response, and spoken output with the corrected route-object decoder.
- [x] Add an opt-in UI-test launch route that stages only EVA navigation, then verify on the iOS 26.5 simulator that the app opens Cloud Setup, taps Continue with Apple, and reaches Apple's native authorization flow. The simulator correctly stops before trust qualification: no Apple Account is signed into Simulator Settings and Apple App Attest is unavailable in Simulator. No authentication, attestation, age, or production-policy bypass was added.
- [x] At the user's explicit request for Debug end-to-end testing, publish higher signed staging configuration version 2 with every Luna route and TTS enabled. Production remains independently disabled.

### Sign-in-adjacent persistence crash — 2026-08-17

- [x] Diagnose the physical-device crash shown during Apple activation: the planning projection fetched three `Project` rows for two domain IDs during a Core Data/CloudKit merge window, then `Dictionary(uniqueKeysWithValues:)` trapped on the duplicated fixed Inbox UUID.
- [x] Replace the trapping projection with deterministic duplicate coalescing. Preserve sequential execution when duplicate rows disagree and emit only a content-free collision count.
- [x] Add an in-memory Core Data regression containing duplicate Inbox rows and verify the planning projection remains usable.
- [x] Pass the complete 43-test `LifeBoardPlanningTrackFoundationTests` suite and a generic iOS device build.
- [x] Re-run the focused planning, activation-default, and age-contract regressions after extraction; pass Xcode target-membership, file-size, no-`print`, and diff guardrails.
- [x] Reset only the dedicated test simulator's stale app container and verify Cloud Setup reaches Apple's native authorization flow without reproducing the persistence crash. App Attest remains intentionally unavailable in Simulator.
- [x] Superseded this Apple-first/18+ rerun by the guest-first 13+ qualification matrix. Optional Apple linking remains a separate recovery/sync test.

### Debug signed-configuration readiness incident — 2026-08-17

- [x] Correlate the generic “Cloud EVA is not available yet” result with the live staging policy. Authentication/account refresh reached a valid signed version-1 policy whose `cloudState`, TTS, price approval, and every route were disabled.
- [x] Replace the generic post-sign-in fallback with a gate-specific readiness result covering authentication, 18+ eligibility, signed configuration, cloud state, route, consent, and credits.
- [x] Force a signed-configuration network refresh after activation so the six-hour cache cannot preserve a disabled policy after staging is enabled.
- [x] Separate durable KV policy age from signed-response freshness. Keep future/rollback/environment/approval checks, but stamp a fresh `issuedAt` when signing so a valid enabled KV policy does not silently expire after seven days.
- [x] Add Swift readiness and Worker persisted-policy regression tests; pass the 41-test Worker suite, backend type-check, focused Swift test, generic physical-device Debug build, file-size/no-`print`/diff guardrails, and staging Wrangler preflight/dry-run.
- [x] Deploy staging Worker version `360709f0-74d6-4eaf-8be4-6ad967fd2fd2`; publish signed policy version 2 with `cloudState: enabled`, `ttsEnabled: true`, approved versioned Luna/TTS pricing, and all semantic routes enabled.
- [x] Verify public staging `/health`, Ed25519-signed configuration, environment, version, price approval, and all route switches. Verify production remains version 1 with cloud and TTS disabled.
- [x] Run the signed physical-device smoke and diagnose the next boundary failure: the Ed25519 signature, pin, environment, and policy were valid, but synthesized Swift dictionary `Codable` expected an array for enum keys while the TypeScript wire contract correctly sends a JSON route object.
- [x] Add explicit route-key wire encoding/decoding to `EvaCloudRuntimeConfiguration` and a regression proving the client accepts and emits the server's JSON object shape. Pass all seven signed-configuration verifier tests.
- [x] Make the opt-in live UI smoke handle both a fresh Apple authorization and a persisted ready account, and require the ready account to advance from Cloud Setup to First Win. Re-run it on the iOS 26.5 simulator: Debug reaches Apple's native authorization boundary and exits with the intentional App-Attest hardware skip.
- [ ] Complete the authenticated physical-device run and record request IDs/stages for Apple, trust, age, credits, consent, refresh, Luna, and TTS. The latest corrected rerun was stopped at Xcode device preflight because the connected iPhone auto-locked; no product or contract failure was observed in that attempt.

### Documentation and product strategy — 2026-08-17

- [x] Expand the Cloud EVA API, backend, privacy/data-flow, and incident runbooks to match the current implementation and environment state.
- [x] Add a combined product/technical guide, scored risk register, and evidence-gated 24-month EVA/Life OS roadmap.
- [x] Reconcile product, onboarding, Universal Input, repository, and EVA provider-architecture documentation with the Cloud Luna / Offline MLX seam and removal of Apple Foundation Models.

### Contract-v4 Life OS intelligence spine — 2026-08-21

- [x] Add required turn context and explicit per-section selection reasons while retaining versions 1–3 for negotiated compatibility.
- [x] Add deny-by-default route manifests, typed/semantic Knowledge retrieval, authorized Journal retrieval, and one whole-turn allocator that drops complete records.
- [x] Add closed navigation targets, durable record references, local resolution/disambiguation, and Swift/TypeScript drift fixtures.
- [x] Add deterministic-first and cloud-assisted capture for body mass, notes, Journal append, hydration, mood, tracker deltas, and life moments.
- [x] Enforce today-only, same-kind, maximum-three direct capture with prohibited-domain escalation, typed persisted receipts, and 30-minute undo.
- [x] Add correctable provenance-rich memory, confirmed candidates, Evidence Lens exclusions across Eva/Insights/Home, the shared Insight model, and the deterministic proactive governor.
- [x] Rewrite the canonical product, API, context/prompt, authority, memory/evidence, evaluation, privacy, backend, incident, risk, provider, and roadmap documentation for the v4 baseline.
- [ ] Run the complete seeded context evaluation: relevance, subtraction, irrelevant-record resistance, sensitive omission, Evidence Lens exclusion, and prompt injection.
- [ ] Run physical-device navigation and every capture family through success, ambiguity/escalation, relaunch, duplicate retry, receipt, and undo.
- [ ] Qualify memory correction/deletion, cross-surface exclusion propagation, and proactive daily/quiet-hour/dormancy behavior in staged product flows.
- [ ] Observe v4 context, authority, quality, latency, cache, and cost dashboards during limited staging traffic before production enablement.

### Context and prompt rebuild for a reasoning model — 2026-08-19

The prompt and context layer was designed for a 0.6B MLX model and shipped
underneath Cloud EVA unchanged. The client was spending a fraction of the
capacity the Worker already authorizes, and three routes were structurally
broken on the cloud path.

- [x] Diagnose the ceiling: `LLMSystemPromptComposer` and `getChatMessages` read
      `ModelConfiguration.tokenBudget`, so a cloud-only account fell back to
      `defaultModel` and capped Luna at 1,536 input tokens / 360 task-context
      tokens / 8 history messages, while `RoutePolicy.inputTokenCap` (16 K chat,
      32 K plan) was decoded from the signed configuration and never read.
- [x] Fix the routing sentinel defect: the legacy
      `generate(modelName:thread:systemPrompt:)` overload required a local
      `ModelConfiguration`, so every caller on it — daily brief, top three, task
      breakdown, field suggestion, planner, plan repair, Shortcuts — returned
      "Failed: model not found" the moment Cloud EVA was selected and silently
      fell back to heuristics without ever reaching the network.
- [x] Fix identifier authorization: `semanticValidationError` scans
      `request.context` only, but `plan`, `planRepair`, and `topThree` inlined
      their rosters into the prompt and sent `context: []`, so any structured
      result naming a real record was rejected. Rosters now travel as context
      sections; regressions cover both directions in TypeScript and Swift.
- [x] Add contract v2: typed per-category context payloads, twelve categories
      (four still consent-gated), optional `userInstructions`, and
      `contractVersions: [1, 2]`. One schema admits both versions.
- [x] Carry the person's own Settings prompt as `userInstructions` — fenced,
      subordinated to policy, capped server-side, moderated, and placed after the
      prompt-cache breakpoint. It had been silently discarded on every cloud
      request since Cloud EVA shipped.
- [x] Chunk input moderation so a 16 K-token envelope cannot exceed the
      moderation input limit; a failing chunk fails the request.
- [x] Add `EvaContextBudget` as the single budget source, reading the published
      route cap for cloud and the per-model table for offline, failing closed to
      offline on every unconfirmed path. Offline budgets are unchanged.
- [x] Add the typed context envelope with `.compact`/`.rich` render modes. The
      offline path is byte-identical to v1 and never consults the rich
      projectors; overflow drops whole records rather than truncating.
- [x] Use the existing embedding index for cloud context selection instead of
      substring matching. Offline keeps substring matching.
- [x] Supersede `EvaMemoryStoreV2` with user-owned v3 memory: 30 confirmed
      240-character statements, inactive proposals, suppression/expiry, and no
      conversation-summary generation or v3 field. V1/V2 decoding remains only
      for migration and wire rollout compatibility.
- [x] Rewrite the server prompts: real persona and doctrine, per-route judgement
      contracts, and no restating of JSON shapes the strict schema already
      enforces. Raise `chat` and `dailyBrief` reasoning effort to `medium`.
- [x] Widen the daily-brief result to carry fixed commitments, the next move, an
      explicit tradeoff, evidence identifiers, and an overcommitment flag.
- [ ] Deploy the Worker to staging and run a physical-device chat, plan, and
      daily brief. Confirm from `response.usage` that `inputTokens` lands in the
      thousands rather than ~1,500, that `cachedInputTokens` is non-trivial on the
      second turn of a thread, and that the larger payload produces no
      `input_rejected` or `output_rejected`.
- [ ] Run the before/after quality evaluation on a seeded workspace: cites a real
      task by name, respects capacity, proposes subtraction when overloaded, and
      gives a reason traceable to a supplied signal. Token counts alone do not
      show the enrichment worked.
- [ ] Reconcile `response.usage` against the price schedule in staging telemetry
      before enabling production.

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
- [x] Fail closed when KV configuration is missing, malformed, tampered, wrong-environment, future-dated, unapproved, or rolled back. Reissue a fresh signed-response timestamp from a valid durable KV policy so intentional policy persistence does not become an outage.
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
- [ ] Complete environment-isolated Cloudflare, OpenAI, and Apple secret provisioning. Existing OpenAI, generated signing/encryption/HMAC material, Apple team/client IDs, Apple trust roots, App Attest environment, and Sign in with Apple key remain remote-only, but the 2026-08-25 preflight found `APPLE_DEVICECHECK_KEY_ID` and `APPLE_DEVICECHECK_PRIVATE_KEY_P8` missing from staging and production.
- [x] Add executable staging smoke, privacy-safe Luna eval, and load-test tools.
- [x] Add deployment preflight and environment-isolated key-generation tooling that never prints private values; npm deployment preflights now always verify the actual remote secret-name set.
- [x] Deploy staging first in fail-closed mode and observe a clean remote workflow; later explicitly enable all staging routes/TTS for Debug qualification through signed policy version 2. `/health`, signature, route policy, and Apple exchange/refresh schema boundaries are verified remotely.
- [ ] Pass real-device iOS, signed Catalyst, Luna, moderation, and TTS staging smoke tests.
- [ ] Meet structured-validity and latency acceptance thresholds at 10× launch load.
- [ ] Complete ZDR, privacy, threat-model, App Store, and TestFlight gates. Cloudflare imported the existing GitHub Pages records, the GoDaddy nameserver cutover completed, the production custom domain is attached, and the marketing apex/www paths were verified through Cloudflare without changing their GitHub Pages targets. The Apple App ID server-notification configuration was submitted for `https://api.getlifeboard.app/v1/auth/apple/events`; Apple portal propagation remains a final console verification.
- [ ] Publish the release-owner-requested direct 100% text/TTS policy only after DeviceCheck provisioning, staging verification, and production fail-closed Worker verification; review after seven days.
- [x] Add validated version-controlled staging v3 and production v2 policy sources, 100% guest rollout, exact supported-route assertions, signed decision-loop runtime controls, and prepared higher-version disabled rollback policies.
- [ ] Provision the dedicated DeviceCheck keys, deploy current Worker to staging, publish v3, and pass route/signed-config smoke.
- [ ] Upload and deploy the tested Worker to production while fail-closed, then publish production v2 at 100% and verify signature, health, routes, TTS, accounting, telemetry, and rollback readiness.

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
- [x] Production-harden per-device age eligibility with 24-hour expiry/revalidation. The current product threshold is 13+; earlier incident notes record the superseded 18+ policy.
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

- [x] Add guest-first cloud activation, 13+ policy gate, context selection, and existing-user notice.
- [x] Add optional Protect & Sync with Apple, just-in-time account recovery, quota, Settings, and account deletion.
- [x] Pass localization, accessibility, and design-system guardrails.

## Phase 9 — Release

- [ ] Finish Cloudflare, OpenAI, and Apple secret/console provisioning. KV, Analytics Engine, Sign in with Apple, and the production custom domain are present, but dedicated DeviceCheck secrets are missing from staging and production; Apple server callback propagation also remains a console verification gate.
- [x] Configure `api.getlifeboard.app`. The Cloudflare zone is active, the production Worker custom domain is attached, and `/health` plus signed `/v1/eva/config` return successfully through the production hostname.
- [ ] Obtain OpenAI Zero Data Retention approval.
- [ ] Complete privacy, security, load, evaluation, and TestFlight gates.
- [ ] Execute the approved direct 100% exception after staging, then perform the seven-day production-enabled/not-graduated review.

## Verification evidence — 2026-08-15

- [x] `npm run check` passes with the marketing app, shared contracts, Worker type-check, and Worker tests.
- [x] `npm audit --audit-level=high` reports zero vulnerabilities; local credential-shape and secret-file scans are clean.
- [x] Worker suite passes 40 tests, including fail-closed configuration, request-body ceilings, fixture-backed App Attest chain/environment/nonce/RP-ID/signature/counter verification, age leases, synthetic Catalyst App Transaction and platform binding, concurrent and one-remaining-credit reservations, crash reconciliation, idempotent release/commit, refresh-token reuse, consent revisioning, speech claim/accounting concurrency, mocked moderation, prompt ownership, versioned cost accounting, Apple exchange/refresh UUID contract regressions, and case-insensitive challenge key resolution.
- [x] `wrangler deploy --dry-run --env staging` packages the Worker and all declared bindings.
- [x] The iOS generic simulator build passes with the EVA Cloud implementation.
- [x] Clean iOS Simulator and universal Mac Catalyst builds pass after reconciling the onboarding and widget package-link changes.
- [x] The last full `LifeBoardTests` run executes 2,274 tests with four skips and zero failures. The focused signed-runtime-configuration suite now passes seven tests for valid pins, tampering, missing/wrong pins, stale/future documents, rollback, environment mismatch, unsupported contracts/models, and the TypeScript server's route-keyed JSON object shape. Shared structured fixtures decode through the Swift wire contract and playback completion is covered independently of AVFoundation scheduling.
- [x] Focused `EvaActivationTests` and `EvaCloudWireContractTests` pass 38 tests with zero failures.
- [x] The opt-in Cloud EVA simulator smoke succeeds with one intentional skip at Apple's physical-hardware App Attest boundary; its UI-test-only state seeding has independent unit coverage.
- [x] EVA's Knowledge provider registry has single ownership in the `KnowledgeFeature` Swift package rather than duplicate app/package compilation.
- [x] The production API origin is consistently `https://api.getlifeboard.app`.
- [x] Production DNS cutover preserves the GitHub Pages marketing site: `getlifeboard.app` returns 200 and `www.getlifeboard.app` redirects to the apex through Cloudflare; apex A/AAAA and www CNAME targets remain the imported GitHub Pages records.
- [x] Production custom domain responds through Cloudflare: `https://api.getlifeboard.app/health` returns the production Worker health response and signed `/v1/eva/config` is reachable.
- [x] Plists, entitlements, privacy manifest, accessibility identifiers, localization (1,066 keys), file-size ratchets, module boundaries, directory structure, documentation, frozen contracts, App Intent descriptions, SwiftLint debt, and no-print logging checks pass.
- [x] Offline-provider regression fixtures explicitly select Offline EVA; automatic/cloud production routing still never silently falls back to MLX.
- [ ] Restore passing staging and production deployment preflight. Local configuration checks pass, but remote secret-name verification on 2026-08-25 found both dedicated DeviceCheck secrets absent in both environments.
- [x] Staging signed configuration version 2 reports `cloudState: enabled`, `ttsEnabled: true`, approved pricing, and no disabled semantic routes; production remains signed version 1 with text and TTS disabled.
- [ ] Install the watchOS 26.5 simulator runtime to complete the final watch target-membership build probe. This is a local Xcode component prerequisite, not a source or EVA failure.
- [ ] `swift test` remains unsuitable for this iOS-only package graph because `LifeBoardTokens` imports UIKit; Xcode iOS/Catalyst builds and the 2,274-test XCTest run are the authoritative Apple-platform verification.
