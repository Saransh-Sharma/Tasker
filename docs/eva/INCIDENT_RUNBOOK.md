# Cloud EVA Incident Runbook

**Scope:** EVA Cloud Worker, identity/device trust, runtime configuration, Luna, spoken output, credits, privacy, and safety
**Production origin:** `https://api.getlifeboard.app`
**Last verified:** 2026-08-17

The first objective is to protect people and data; the second is to stop financial or availability damage; the third is to restore a verified service. Runtime configuration is the fastest reversible control. Production DNS for `getlifeboard.app` and `www.getlifeboard.app` is outside the EVA incident boundary and must never be changed during an EVA rollback.

## Severity

| Severity | Examples | Initial response |
|---|---|---|
| SEV-0 | Private content in logs/storage, token/key compromise, cross-account data or credit access | Disable cloud immediately; revoke affected secrets; privacy/security lead owns response |
| SEV-1 | Auth bypass, age/trust bypass, widespread unsafe output, runaway spend, destructive account bug | Disable affected route or cloud; page engineering/product/security |
| SEV-2 | Major sign-in failure, credit/accounting drift, Luna outage, high error/latency, TTS-wide failure | Disable narrow capability; preserve text or Offline EVA where safe |
| SEV-3 | Degraded route, localized client issue, non-sensitive telemetry gap | Contain, investigate, and ship through normal expedited review |

## Control order

Use the narrowest safe control, publishing a **higher-version** signed configuration:

1. Set `ttsEnabled: false` for speech-only incidents.
2. Disable one semantic route for route/schema/safety incidents.
3. Set `cloudState: degraded` with a clear maintenance message when partial service is safe.
4. Set `cloudState: disabled` when identity, privacy, global safety, or accounting integrity is uncertain.
5. Roll back to the previous Worker version when configuration cannot contain the defect.
6. Revoke/rotate environment secrets for suspected compromise.

Never lower the configuration version, edit the client verification pin to bypass validation, enable an unapproved price schedule, or point production at staging. Keep TTS and text independently controllable.

## First 15 minutes

1. Declare severity, incident owner, scribe, and affected environment.
2. Record UTC start time, deployment version, runtime-config version, first known request ID, affected routes/platforms, and user-visible symptom.
3. Check `/health` and fetch `/v1/eva/config`; verify signature, environment, `cloudState`, `ttsEnabled`, route flags, price approval, and minimum client version.
4. Inspect content-free Analytics Engine signals: auth stages, trust/age denials, error codes, TTFT, completion latency, refusals, schema repairs, reservations/commits/releases/expirations, cost, and budget thresholds.
5. Apply the narrowest kill switch. For privacy/auth/accounting uncertainty, disable cloud first and investigate second.
6. Confirm Offline EVA and ordinary LifeBoard remain usable. Confirm the marketing apex and `www` were not modified.

## Diagnosis by symptom

### Sign in or activation fails

- Correlate `/auth/challenge`, Apple exchange stage, App Attest register/assert, age lease, consent, credits, and signed-config status by request ID—never by token value.
- A generic unavailable message can mask signed-policy denial. Confirm the client fetched the intended environment and current configuration version.
- Check Apple audience/team/key/client IDs, challenge expiry/replay, identity-token vs authorization-code subject, device clock, refresh-family reuse, and credential-revocation state.
- Simulator can reach Apple's UI but cannot qualify App Attest. A production-like trust test requires physical iOS hardware.
- If Core Data/CloudKit warnings accompany activation, distinguish local app crashes from auth failures. Duplicate domain identities must be coalesced or repaired, never passed to a trapping dictionary initializer.

### Configuration fails or unexpectedly disables

- Missing, malformed, wrong-environment, future, rolled-back, unapproved enabled, or invalidly signed policies fail closed.
- KV contains a durable policy revision. The Worker refreshes `issuedAt` on each signed response; clients cache verified responses for six hours and allow the last verified response for seven days.
- During activation, the client forces a configuration refresh so a previously cached disabled policy cannot block a newly enabled staging service.
- Verify Xcode build settings: Debug must use staging origin/pin; Release must use production origin/pin.

### Credits or cost drift

- Disable billable routes if committed credits, account cost, or global cost cannot be reconciled.
- Compare request lifecycle states (`reserved`, `running`, `committed`, `released`, `expired`) with global account-scoped reservations.
- Trigger/observe Durable Object alarm reconciliation for stale work. Never repair balances by editing state without an append-only `admin_adjustment` record and approval.
- Check price-schedule version against actual OpenAI billing before re-enable. A model price change is an incident if hard caps use stale economics.

### Luna or moderation incident

- Disable the affected route first; disable all cloud if prompt ownership, context isolation, or moderation is compromised.
- Inspect refusal, incomplete, moderation category, repair outcome, retry class, token/cache, TTFT, and status metadata. Do not inspect or request private payloads unless the user explicitly supplies a redacted reproduction through the approved support path.
- Confirm tools, web search, file search, `previous_response_id`, and server storage remain disabled.

### Spoken-output incident

- Set `ttsEnabled: false`; text must continue.
- Check ticket issuance/use, text hash, chunk size, PCM content type, cancellation, first-audio latency, audio-session transition, and cache/ticket cleanup.
- For stuck audio, stop playback, release the audio session, and verify recording/dictation arbitration and headphone-disconnect behavior.

### Privacy or secret incident

- Disable cloud; stop any pipeline that may emit content.
- Preserve access-controlled evidence without copying payloads into chat, tickets, or broad logs.
- Rotate the affected Cloudflare/OpenAI/Apple/session/config/encryption/HMAC material in the affected environment. A config-signing-key rotation also requires an app pin migration; do not improvise it during containment.
- Determine data classes, users, processors, retention, exposure window, and notification obligations with privacy/legal owners.

### Safety incident

- Disable the affected route or cloud. Preserve only content-free safety category and request metadata.
- Do not contact emergency services or third parties. The product may present supportive, actionable crisis guidance according to policy, but it must not claim monitoring or intervention.
- Re-run the privacy-safe evaluation corpus and adversarial prompts before re-enable.

## Recovery gates

Service may be re-enabled only when:

- the root cause and affected versions are known;
- the fix has automated regression coverage;
- credits and global/account cost reconcile;
- no prohibited content appears in retained storage or logs;
- staging passes health, signed-config, auth/trust/age, Luna, moderation, cancellation, and relevant TTS smoke;
- the incident owner and the relevant security/privacy/product owner approve the higher-version policy;
- production begins at internal/limited exposure and its leading indicators remain within threshold.

## Communications

User messaging should state the affected capability, whether local data is safe, whether Offline EVA remains available, and the next update time. Do not blame Apple, Cloudflare, or OpenAI before evidence establishes the dependency. Do not expose security mechanics, request content, account identifiers, or speculative timelines.

## Post-incident

Within five working days, document timeline, detection gap, technical and product root cause, blast radius, user impact, accounting impact, privacy/safety assessment, why controls did or did not contain it, corrective owners/dates, and new tests/alerts. Update `RISK_REGISTER.md`, this runbook, the migration ledger, and acceptance thresholds when the incident changes what is known.
