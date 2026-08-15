# EVA Cloud Privacy and Data Flow

Cloud EVA is an explicit, 18+ feature. LifeBoard and optional Offline EVA continue to work when cloud eligibility, consent, connectivity, configuration, or credits are unavailable.

```text
LifeBoard projection DTOs
  -> authenticated + device-bound Cloudflare Worker
  -> input moderation
  -> OpenAI Responses (gpt-5.6-luna, store=false, no tools)
  -> output moderation and schema validation
  -> normalized response to the device

Successful answer + signed ticket
  -> OpenAI speech (tts-1, nova, PCM)
  -> streamed directly to the device
```

The server persists only pseudonymous account/auth state, per-device adult eligibility, consent revision, exact credit/cost ledgers, device trust, and content-free operational metrics. Catalyst sends an Apple-signed App Transaction only during sign-in; the Worker verifies it in memory and stores only a keyed app-transaction-ID hash, receipt environment, original platform, and verification time. It never stores the signed transaction or its device-verification fields. The server does not persist prompts, answers, journal/health/memory content, audio, conversation history, or OpenAI response IDs. Logs and Analytics Engine records must never include request or response content.

Base planning context uses bounded projection DTOs. Journal, health, Life Moments, and personal memory are independently off by default. Revocation increments the authoritative account consent revision; stale devices fail before the next model request. Declared Age Range stores no birthdate—only eligibility, declaration class/policy, device, and timestamp.

`store: false` is used on Responses requests but does not itself grant Zero Data Retention. The privacy policy and in-app disclosure must state the OpenAI project’s actual retention status until ZDR is approved. OpenAI and Cloudflare must appear in the processor list. The app’s privacy manifest remains non-tracking and must be updated only for APIs and collected-data declarations actually used by the shipped client.
