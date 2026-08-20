import { env, runDurableObjectAlarm, runInDurableObject, SELF } from 'cloudflare:test'
import { describe, expect, it } from 'vitest'
import type { Env } from '../src/environment.js'
import { sentenceChunks } from '../src/routes/speech.js'

const bindings = env as unknown as Env

async function bootstrappedAccount() {
  const accountId = `test-${crypto.randomUUID()}`
  const familyId = crypto.randomUUID()
  const installationId = crypto.randomUUID()
  const stub = bindings.EVA_ACCOUNTS.get(bindings.EVA_ACCOUNTS.idFromName(accountId))
  await stub.fetch('https://durable.internal/bootstrap', {
    method: 'POST',
    body: JSON.stringify({
      accountId,
      familyId,
      refreshTokenHash: 'refresh-original',
      installationId,
      platform: 'ios',
      authenticatedAt: Date.now(),
      refreshExpiresAt: Date.now() + 86_400_000,
    }),
  })
  return { accountId, familyId, installationId, stub }
}

function base64Url(value: string): string {
  return btoa(value).replaceAll('+', '-').replaceAll('/', '_').replaceAll('=', '')
}

function unverifiableIdentityToken(): string {
  const header = base64Url(JSON.stringify({ alg: 'RS256', kid: 'apple-key' }))
  const payload = base64Url(JSON.stringify({ iss: 'https://appleid.apple.com', sub: 'user', aud: 'com.example.app' }))
  return `${header}.${payload}.${base64Url('signature')}`
}

describe('EVA Cloud Worker', () => {
  const validAppleExchangeBody = () => ({
    challengeId: crypto.randomUUID(),
    nonce: 'n'.repeat(20),
    identityToken: 'header.payload.signature',
    authorizationCode: 'apple-authorization-code',
    installationId: crypto.randomUUID(),
    platform: 'ios',
  })

  it('exposes content-free health information and security headers', async () => {
    const response = await SELF.fetch('https://eva.test/health')
    expect(response.status).toBe(200)
    expect(response.headers.get('X-Content-Type-Options')).toBe('nosniff')
    await expect(response.json()).resolves.toMatchObject({ status: 'ok', service: 'eva-cloud' })
  })

  it('rejects browser origins', async () => {
    const response = await SELF.fetch('https://eva.test/health', { headers: { Origin: 'https://example.com' } })
    expect(response.status).toBe(403)
    await expect(response.json()).resolves.toMatchObject({ code: 'input_rejected' })
  })

  it('rejects oversized bodies before route authentication work', async () => {
    const response = await SELF.fetch('https://eva.test/v1/eva/responses', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ padding: 'x'.repeat(256 * 1_024) }),
    })
    expect(response.status).toBe(413)
    await expect(response.json()).resolves.toMatchObject({ code: 'schema_invalid' })
  })

  it('accepts only content-free enumerated product events', async () => {
    const accepted = await SELF.fetch('https://eva.test/v1/product-events', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        schemaVersion: 1,
        installationId: crypto.randomUUID().toUpperCase(),
        events: [{
          name: 'coreFinalized',
          timestamp: new Date().toISOString(),
          flowVersion: 6,
          audience: 'fresh',
          outcome: 'home',
          durationBucket: '1_3s',
        }],
      }),
    })
    expect(accepted.status).toBe(202)
    await expect(accepted.json()).resolves.toEqual({ accepted: 1 })

    const contentBearing = await SELF.fetch('https://eva.test/v1/product-events', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        schemaVersion: 1,
        installationId: crypto.randomUUID(),
        events: [{
          name: 'memoryProposalSaved',
          timestamp: new Date().toISOString(),
          memoryText: 'A private fact must never be accepted.',
        }],
      }),
    })
    expect(contentBearing.status).toBe(400)

    const unknownEvent = await SELF.fetch('https://eva.test/v1/product-events', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        schemaVersion: 1,
        installationId: crypto.randomUUID(),
        events: [{ name: 'messageSent', timestamp: new Date().toISOString() }],
      }),
    })
    expect(unknownEvent.status).toBe(400)
  })

  it('consumes an auth challenge exactly once', async () => {
    const stub = bindings.AUTH_CHALLENGES.get(bindings.AUTH_CHALLENGES.idFromName(crypto.randomUUID()))
    const issued = await stub.fetch('https://durable.internal/issue', {
      method: 'POST', body: JSON.stringify({ purpose: 'signIn', ttlSeconds: 300 }),
    })
    const challenge = await issued.json<{ nonce: string }>()
    const first = await stub.fetch('https://durable.internal/consume', {
      method: 'POST', body: JSON.stringify({ purpose: 'signIn', nonce: challenge.nonce }),
    })
    const replay = await stub.fetch('https://durable.internal/consume', {
      method: 'POST', body: JSON.stringify({ purpose: 'signIn', nonce: challenge.nonce }),
    })
    expect(first.status).toBe(200)
    expect(replay.status).toBe(409)
  })

  it('accepts valid UUIDs at the Apple exchange schema boundary', async () => {
    const response = await SELF.fetch('https://eva.test/v1/auth/apple/exchange', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(validAppleExchangeBody()),
    })
    expect(response.status).toBe(409)
    await expect(response.json()).resolves.toMatchObject({
      code: 'unauthenticated',
      message: 'The sign-in request expired. Try again.',
    })
  })

  it('consumes a freshly issued challenge when Swift re-encodes its UUID in uppercase', async () => {
    const issued = await SELF.fetch('https://eva.test/v1/auth/challenge', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ purpose: 'signIn' }),
    })
    expect(issued.status).toBe(200)
    const challenge = await issued.json<{ challengeId: string; nonce: string }>()

    const exchange = await SELF.fetch('https://eva.test/v1/auth/apple/exchange', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        ...validAppleExchangeBody(),
        challengeId: challenge.challengeId.toUpperCase(),
        nonce: challenge.nonce,
      }),
    })

    expect(exchange.status).toBe(401)
    await expect(exchange.json()).resolves.toMatchObject({
      code: 'unauthenticated',
      message: 'Apple sign-in could not be verified.',
    })
  })

  it('answers an unreachable Apple with a retryable outage instead of a sign-in failure', async () => {
    const issued = await SELF.fetch('https://eva.test/v1/auth/challenge', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ purpose: 'signIn' }),
    })
    const challenge = await issued.json<{ challengeId: string; nonce: string }>()

    const originalClientIds = bindings.APPLE_CLIENT_IDS
    const originalFetch = globalThis.fetch
    // Reaching Apple's key endpoint at all is what fails here. Telling the user
    // their credential could not be verified would send them back through the
    // Apple sheet to fix an outage on our side.
    bindings.APPLE_CLIENT_IDS = 'com.example.app'
    globalThis.fetch = (async (input: RequestInfo | URL, init?: RequestInit) => {
      if (String(input instanceof Request ? input.url : input).includes('appleid.apple.com')) {
        throw new DOMException('The operation was aborted due to timeout', 'TimeoutError')
      }
      return originalFetch(input as RequestInfo, init)
    }) as typeof fetch

    try {
      const exchange = await SELF.fetch('https://eva.test/v1/auth/apple/exchange', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          ...validAppleExchangeBody(),
          challengeId: challenge.challengeId,
          nonce: challenge.nonce,
          // Structurally well-formed so jose reaches key resolution; the
          // signature never matters because the key fetch is what fails.
          identityToken: unverifiableIdentityToken(),
        }),
      })

      expect(exchange.status).toBe(503)
      await expect(exchange.json()).resolves.toMatchObject({
        code: 'provider_unavailable',
        retryable: true,
        recoveryAction: 'wait',
      })
    } finally {
      globalThis.fetch = originalFetch
      bindings.APPLE_CLIENT_IDS = originalClientIds
    }
  })

  it('rejects malformed Apple exchange UUIDs and extra properties', async () => {
    const malformed = await SELF.fetch('https://eva.test/v1/auth/apple/exchange', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ ...validAppleExchangeBody(), challengeId: 'not-a-uuid' }),
    })
    expect(malformed.status).toBe(400)
    await expect(malformed.json()).resolves.toMatchObject({ code: 'schema_invalid' })

    const extra = await SELF.fetch('https://eva.test/v1/auth/apple/exchange', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ ...validAppleExchangeBody(), unexpected: 'must-not-leak' }),
    })
    expect(extra.status).toBe(400)
    const error = await extra.text()
    expect(error).toContain('schema_invalid')
    expect(error).not.toContain('must-not-leak')
  })

  it('accepts valid UUIDs at the refresh schema boundary', async () => {
    const response = await SELF.fetch('https://eva.test/v1/auth/refresh', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        accountId: 'account-identifier-long-enough',
        familyId: crypto.randomUUID(),
        refreshToken: 'r'.repeat(32),
        installationId: crypto.randomUUID(),
        platform: 'ios',
      }),
    })
    expect(response.status).toBe(401)
    await expect(response.json()).resolves.toMatchObject({ code: 'session_expired' })
  })

  it('keeps credit reservations exact under concurrency', async () => {
    const { stub } = await bootstrappedAccount()
    const responses = await Promise.all(Array.from({ length: 101 }, (_, index) => stub.fetch(
      'https://durable.internal/credits/reserve',
      { method: 'POST', body: JSON.stringify({ requestId: `request-${index}`, amount: 1 }) },
    )))
    const bodies = await Promise.all(responses.map((response) => response.json<{ reserved: boolean }>()))
    expect(bodies.filter((body) => body.reserved)).toHaveLength(100)
    const credits = await (await stub.fetch('https://durable.internal/credits')).json<{ balance: number }>()
    expect(credits.balance).toBe(0)
  })

  it('allows exactly one concurrent reservation when one credit remains', async () => {
    const { stub } = await bootstrappedAccount()
    await runInDurableObject(stub, async (_instance, state) => {
      const account = await state.storage.get<{ credits: { balance: number } }>('account')
      if (!account) throw new Error('Account fixture is missing.')
      account.credits.balance = 1
      await state.storage.put('account', account)
    })
    const attempts = await Promise.all([crypto.randomUUID(), crypto.randomUUID()].map((requestId) => stub.fetch(
      'https://durable.internal/credits/reserve',
      { method: 'POST', body: JSON.stringify({ requestId, amount: 1 }) },
    )))
    const bodies = await Promise.all(attempts.map((response) => response.json<{ reserved: boolean; status: string }>()))
    expect(bodies.filter((body) => body.reserved)).toHaveLength(1)
    expect(bodies.filter((body) => body.status === 'insufficient')).toHaveLength(1)
    await expect((await stub.fetch('https://durable.internal/credits')).json()).resolves.toMatchObject({ balance: 0 })
  })

  it('releases a credit reservation idempotently', async () => {
    const { stub } = await bootstrappedAccount()
    const requestId = crypto.randomUUID()
    await stub.fetch('https://durable.internal/credits/reserve', {
      method: 'POST', body: JSON.stringify({ requestId, amount: 1 }),
    })
    const first = await stub.fetch('https://durable.internal/credits/release', {
      method: 'POST', body: JSON.stringify({ requestId }),
    })
    const second = await stub.fetch('https://durable.internal/credits/release', {
      method: 'POST', body: JSON.stringify({ requestId }),
    })
    await expect(first.json()).resolves.toMatchObject({ credits: { balance: 100 } })
    await expect(second.json()).resolves.toMatchObject({ credits: { balance: 100 } })
  })

  it('rejects request ID replay without charging a second credit', async () => {
    const { stub } = await bootstrappedAccount()
    const requestId = crypto.randomUUID()
    const reserve = () => stub.fetch('https://durable.internal/credits/reserve', {
      method: 'POST', body: JSON.stringify({ requestId, amount: 1 }),
    })
    await expect((await reserve()).json()).resolves.toMatchObject({ reserved: true, status: 'reserved' })
    await expect((await reserve()).json()).resolves.toMatchObject({ reserved: false, status: 'reserved' })
    const credits = await (await stub.fetch('https://durable.internal/credits')).json<{ balance: number }>()
    expect(credits.balance).toBe(99)
  })

  it('reconciles a stranded credit reservation from a Durable Object alarm', async () => {
    const { stub } = await bootstrappedAccount()
    const requestId = crypto.randomUUID()
    await stub.fetch('https://durable.internal/credits/reserve', {
      method: 'POST', body: JSON.stringify({ requestId, amount: 1 }),
    })
    await runInDurableObject(stub, async (_instance, state) => {
      const account = await state.storage.get<{
        creditReservations: Record<string, { expiresAt: number }>
      }>('account')
      if (!account?.creditReservations[requestId]) throw new Error('Reservation fixture is missing.')
      account.creditReservations[requestId].expiresAt = 0
      await state.storage.put('account', account)
      await state.storage.setAlarm(Date.now() - 1)
    })
    await runDurableObjectAlarm(stub)
    const credits = await (await stub.fetch('https://durable.internal/credits')).json<{ balance: number }>()
    expect(credits.balance).toBe(100)
    const replay = await stub.fetch('https://durable.internal/credits/reserve', {
      method: 'POST', body: JSON.stringify({ requestId, amount: 1 }),
    })
    await expect(replay.json()).resolves.toMatchObject({ reserved: false, status: 'expired' })
  })

  it('commits cost exactly once and refuses to exceed the reservation cap', async () => {
    const { stub } = await bootstrappedAccount()
    const requestId = crypto.randomUUID()
    const reserve = await stub.fetch('https://durable.internal/cost/reserve', {
      method: 'POST',
      body: JSON.stringify({ requestId, globalRequestId: `global-${requestId}`, estimatedMicroUsd: 100 }),
    })
    expect(reserve.status).toBe(200)
    await stub.fetch('https://durable.internal/request/running', {
      method: 'POST', body: JSON.stringify({ requestId }),
    })
    const overCap = await stub.fetch('https://durable.internal/cost/commit', {
      method: 'POST', body: JSON.stringify({ requestId, actualMicroUsd: 101 }),
    })
    expect(overCap.status).toBe(409)
    const first = await stub.fetch('https://durable.internal/cost/commit', {
      method: 'POST', body: JSON.stringify({ requestId, actualMicroUsd: 40 }),
    })
    await expect(first.json()).resolves.toMatchObject({ committed: true, rolling24HourMicroUsd: 40 })
    const duplicate = await stub.fetch('https://durable.internal/cost/commit', {
      method: 'POST', body: JSON.stringify({ requestId, actualMicroUsd: 40 }),
    })
    await expect(duplicate.json()).resolves.toMatchObject({ committed: true, alreadyCommitted: true, actualMicroUsd: 40 })
  })

  it('expires adult eligibility after the server-defined 24-hour lease', async () => {
    const { familyId, installationId, stub } = await bootstrappedAccount()
    const age = await stub.fetch('https://durable.internal/device/age', {
      method: 'POST',
      body: JSON.stringify({ installationId, platform: 'ios', eligibleAdult: true, declaration: '18+' }),
    })
    const ageBody = await age.json<{ eligibleAdult: boolean; expiresAt: string }>()
    expect(ageBody.eligibleAdult).toBe(true)
    expect(Date.parse(ageBody.expiresAt) - Date.now()).toBeGreaterThan(23 * 60 * 60 * 1_000)
    const authorization = await stub.fetch('https://durable.internal/authorize', {
      method: 'POST',
      body: JSON.stringify({ familyId, installationId, platform: 'ios', requireAdult: true, requireAttestation: false }),
    })
    await expect(authorization.json()).resolves.toMatchObject({ authorized: true })
  })

  it('revokes a refresh family when an already-rotated token is reused', async () => {
    const { familyId, stub } = await bootstrappedAccount()
    const rotate = (presentedTokenHash: string, replacementTokenHash: string) => stub.fetch(
      'https://durable.internal/refresh/rotate',
      {
        method: 'POST',
        body: JSON.stringify({
          familyId,
          presentedTokenHash,
          replacementTokenHash,
          replacementExpiresAt: Date.now() + 86_400_000,
        }),
      },
    )
    expect((await rotate('refresh-original', 'refresh-next')).status).toBe(200)
    expect((await rotate('refresh-original', 'refresh-attacker')).status).toBe(401)
    expect((await rotate('refresh-next', 'refresh-after-revocation')).status).toBe(401)
  })

  it('requires verified risk evidence before bootstrapping Catalyst', async () => {
    const accountId = `test-${crypto.randomUUID()}`
    const stub = bindings.EVA_ACCOUNTS.get(bindings.EVA_ACCOUNTS.idFromName(accountId))
    const response = await stub.fetch('https://durable.internal/bootstrap', {
      method: 'POST',
      body: JSON.stringify({
        accountId,
        familyId: crypto.randomUUID(),
        refreshTokenHash: 'refresh-original',
        installationId: crypto.randomUUID(),
        platform: 'catalyst',
        authenticatedAt: Date.now(),
        refreshExpiresAt: Date.now() + 86_400_000,
      }),
    })
    expect(response.status).toBe(401)
  })

  it('rejects a session whose claimed platform differs from its device binding', async () => {
    const { familyId, installationId, stub } = await bootstrappedAccount()
    const response = await stub.fetch('https://durable.internal/authorize', {
      method: 'POST',
      body: JSON.stringify({
        familyId,
        installationId,
        platform: 'catalyst',
        requireAdult: false,
        requireAttestation: false,
      }),
    })
    await expect(response.json()).resolves.toMatchObject({
      authorized: false,
      reason: 'attestation',
    })
  })

  it('rejects stale assertion challenges and regressing counters', async () => {
    const { installationId, stub } = await bootstrappedAccount()
    const material = await stub.fetch('https://durable.internal/device/assertion/material', {
      method: 'POST', body: JSON.stringify({ installationId, challenge: 'not-issued' }),
    })
    expect(material.status).toBe(409)
    const counter = await stub.fetch('https://durable.internal/device/assertion/commit', {
      method: 'POST', body: JSON.stringify({ installationId, counter: 0 }),
    })
    expect(counter.status).toBe(409)
  })

  it('enforces optimistic consent revisions', async () => {
    const { stub } = await bootstrappedAccount()
    const first = await stub.fetch('https://durable.internal/consent', {
      method: 'PUT', body: JSON.stringify({ expectedRevision: 0, grants: ['journal'] }),
    })
    await expect(first.json()).resolves.toMatchObject({ revision: 1, grants: ['journal'] })
    const stale = await stub.fetch('https://durable.internal/consent', {
      method: 'PUT', body: JSON.stringify({ expectedRevision: 0, grants: [] }),
    })
    expect(stale.status).toBe(409)
    await expect(stale.json()).resolves.toMatchObject({ consent: { revision: 1, grants: ['journal'] } })
  })

  it('allows only one concurrent first speech render and does not charge it again', async () => {
    const { stub } = await bootstrappedAccount()
    const requestId = crypto.randomUUID()
    const ticketId = crypto.randomUUID()
    await stub.fetch('https://durable.internal/credits/reserve', {
      method: 'POST', body: JSON.stringify({ requestId, amount: 1 }),
    })
    await stub.fetch('https://durable.internal/credits/commit', {
      method: 'POST',
      body: JSON.stringify({
        requestId,
        speechTicket: { ticketId, textHash: 'answer-hash', expiresAt: Date.now() + 60_000 },
      }),
    })
    const claim = () => stub.fetch('https://durable.internal/speech/claim', {
      method: 'POST',
      body: JSON.stringify({
        ticketId,
        textHash: 'answer-hash',
        allowPaidRegeneration: false,
        paidReservationId: crypto.randomUUID(),
      }),
    })
    const attempts = await Promise.all([claim(), claim()])
    expect(attempts.filter((response) => response.status === 200)).toHaveLength(1)
    expect(attempts.filter((response) => response.status === 409)).toHaveLength(1)
    await stub.fetch('https://durable.internal/speech/complete', {
      method: 'POST', body: JSON.stringify({ ticketId }),
    })
    await expect((await stub.fetch('https://durable.internal/credits')).json()).resolves.toMatchObject({ balance: 99 })
  })

  it('releases a paid speech regeneration credit after failure and commits it after success', async () => {
    const { stub } = await bootstrappedAccount()
    const requestId = crypto.randomUUID()
    const ticketId = crypto.randomUUID()
    await stub.fetch('https://durable.internal/credits/reserve', {
      method: 'POST', body: JSON.stringify({ requestId, amount: 1 }),
    })
    await stub.fetch('https://durable.internal/credits/commit', {
      method: 'POST',
      body: JSON.stringify({
        requestId,
        speechTicket: { ticketId, textHash: 'answer-hash', expiresAt: Date.now() + 60_000 },
      }),
    })
    await stub.fetch('https://durable.internal/speech/claim', {
      method: 'POST',
      body: JSON.stringify({
        ticketId, textHash: 'answer-hash', allowPaidRegeneration: false, paidReservationId: crypto.randomUUID(),
      }),
    })
    await stub.fetch('https://durable.internal/speech/complete', {
      method: 'POST', body: JSON.stringify({ ticketId }),
    })

    const failedReservationId = crypto.randomUUID()
    await expect((await stub.fetch('https://durable.internal/speech/claim', {
      method: 'POST',
      body: JSON.stringify({
        ticketId, textHash: 'answer-hash', allowPaidRegeneration: true, paidReservationId: failedReservationId,
      }),
    })).json()).resolves.toMatchObject({ claimed: true, included: false, credits: { balance: 98 } })
    await expect((await stub.fetch('https://durable.internal/speech/fail', {
      method: 'POST', body: JSON.stringify({ ticketId }),
    })).json()).resolves.toMatchObject({ credits: { balance: 99 } })

    const committedReservationId = crypto.randomUUID()
    await stub.fetch('https://durable.internal/speech/claim', {
      method: 'POST',
      body: JSON.stringify({
        ticketId, textHash: 'answer-hash', allowPaidRegeneration: true, paidReservationId: committedReservationId,
      }),
    })
    await expect((await stub.fetch('https://durable.internal/speech/complete', {
      method: 'POST', body: JSON.stringify({ ticketId }),
    })).json()).resolves.toMatchObject({ credits: { balance: 98 } })
    await expect((await stub.fetch('https://durable.internal/speech/fail', {
      method: 'POST', body: JSON.stringify({ ticketId }),
    })).json()).resolves.toMatchObject({ credits: { balance: 98 } })
  })

  it('splits speech on sentence boundaries and enforces the hard limit', () => {
    const chunks = sentenceChunks(`${'A'.repeat(3_500)}. ${'B'.repeat(3_500)}.`, 4_000)
    expect(chunks).toHaveLength(2)
    expect(chunks.every((chunk) => chunk.length <= 4_000)).toBe(true)
  })
})
