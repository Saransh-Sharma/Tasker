# EVA Cloud API Contract

Production origin: `https://api.getlifeboard.app`. Development and staging use their environment-specific `workers.dev` origins. The native clients do not send browser CORS requests.

## Transport rules

- API version is `/v1`; inference payloads declare `contractVersion: 1`.
- Request bodies are JSON and capped at 256 KiB. Speech responses are raw 24 kHz, mono, signed 16-bit little-endian PCM.
- Clients supply a UUID `X-Request-ID`; the Worker generates one when absent and returns it on every response.
- Authenticated calls use `Authorization: Bearer <access-token>`.
- Sensitive iOS calls add `X-EVA-Attest-Challenge` and `X-EVA-Attest-Assertion`. The assertion signs `METHOD`, URL path, challenge, and the base64url SHA-256 of the exact body, joined with newlines.
- Catalyst does not claim App Attest support. At Apple credential exchange it must send the
  locally verified `AppTransaction.shared.jwsRepresentation`; the Worker validates Apple's
  certificate chain, bundle, App Store environment, and production app ID, persists only a
  keyed transaction-ID hash plus content-free verification metadata, and applies half the
  normal account rate limits. This is a risk signal, not account authentication.
  Apple documents the JWS transport on
  [`AppTransaction.jsonRepresentation`](https://developer.apple.com/documentation/storekit/apptransaction/jsonrepresentation).
- Error bodies use the stable `EvaErrorEnvelopeV1` schema from `Shared/EVACloudContracts`.

## Endpoint lifecycle

1. `POST /v1/auth/challenge`
2. Native Sign in with Apple using the returned nonce.
3. `POST /v1/auth/apple/exchange`
4. On iOS, `POST /v1/attestation/challenge` then `POST /v1/attestation/register`.
5. Request a fresh attestation challenge, create an assertion, then `POST /v1/age/eligibility` with the Declared Age Range result.
6. Read/update `/v1/eva/consent`, then submit `/v1/eva/responses`.
7. If a completed response has `speechTicket`, submit the exact answer to `/v1/eva/speech`.

Inference returns normalized server-sent events: `response.accepted`, text deltas or one structured value, usage, and `response.completed`. Sequence numbers are monotonic within a request. Client-selected model IDs, prompts, tools, reasoning settings, budgets, or credit charges are rejected by the request schema.

The executable TypeScript schemas and fixtures are in `Shared/EVACloudContracts`. They are the canonical wire definition; this document explains their use.
