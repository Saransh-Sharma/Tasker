# EVA Cloud Incident Runbook

## First response

1. Classify the incident: privacy/content exposure, compromised credential, auth bypass, cost spike, unsafe output, or availability.
2. Disable `cloudEnabled` or only `ttsEnabled` through a new higher-version signed configuration. For a suspected signing-key compromise, deploy a Worker that rejects the compromised key before publishing replacement configuration.
3. Preserve content-free request IDs, deployment version, timing, status codes, account HMACs, and usage totals. Do not copy prompts or answers into incident systems.
4. Revoke and rotate the affected Cloudflare/OpenAI/Apple/signing/encryption secrets. A leaked encryption key requires assessing stored Apple refresh credentials and forcing reauthentication.
5. Roll back to the prior Worker version when the fault is code-related; keep feature flags closed until smoke tests pass.

## Required checks

- Auth: replay Apple challenges and refresh tokens; confirm reuse revokes the session family.
- Device trust: reject expired challenges, stale App Attest counters, simulator/debug attestations in production, mismatched installations/platforms, and Catalyst App Transactions with absent/untrusted chains or incorrect bundle, environment, or app ID.
- Privacy: query logs/Analytics fields for unexpected high-cardinality or content-shaped values without reproducing private content.
- Credits/cost: reconcile reserve/commit/release totals and identify stranded reservations by request ID.
- Safety: reproduce only with synthetic fixtures, then validate input moderation, output moderation, refusal, and structured repair paths.

## Recovery gates

Restore internal traffic first, then 5%, 25%, and 100%. At each stage verify auth failures, moderation rates, schema validity, p95 latency, OpenAI errors, credit reconciliation, and daily/account fuse usage. Document the timeline and preventive changes without recording private user content.
