import { env, runDurableObjectAlarm, runInDurableObject, SELF } from 'cloudflare:test'
import { describe, expect, it } from 'vitest'
import { exportJWK, generateKeyPair } from 'jose'
import type { Env } from '../src/environment.js'
import { sentenceChunks } from '../src/routes/speech.js'
import { failClosedRuntimeConfig } from '../src/config/runtime-config.js'
import { guestRolloutBucket } from '../src/auth/guest-rollout.js'

const bindings = env as unknown as Env

async function bootstrappedAccount(identityKind: 'guest' | 'apple' = 'apple') {
  const accountId = `test-${crypto.randomUUID()}`
  const familyId = crypto.randomUUID()
  const installationId = crypto.randomUUID()
  const stub = bindings.EVA_ACCOUNTS.get(bindings.EVA_ACCOUNTS.idFromName(accountId))
  await stub.fetch('https://durable.internal/bootstrap', {
    method: 'POST',
    body: JSON.stringify({
      accountId,
      identityKind,
      familyId,
      refreshTokenHash: 'refresh-original',
      refreshGeneration: 0,
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

  it('assigns guest rollout cohorts with a stable keyed digest', async () => {
    await expect(guestRolloutBucket(
      'rollout-secret',
      '00000000-0000-4000-8000-000000000001',
    )).resolves.toBe(36)
    await expect(guestRolloutBucket(
      'rollout-secret',
      '00000000-0000-4000-8000-000000000002',
    )).resolves.toBe(24)
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

  it('bootstraps a pseudonymous guest with confirmed consent and the full rolling quota', async () => {
    const configuration = failClosedRuntimeConfig(bindings)
    configuration.version = Number(bindings.MIN_RUNTIME_CONFIG_VERSION)
    configuration.cloudState = 'enabled'
    configuration.priceSchedule.approved = true
    configuration.guestAccess = {
      bootstrapEnabled: true,
      inferenceEnabled: true,
      appleLinkingEnabled: true,
      rolloutPercent: 100,
    }
    await bindings.EVA_CONFIG.put('runtime-config-v2', JSON.stringify(configuration))
    const originalSessionKey = bindings.SESSION_SIGNING_PRIVATE_KEY
    const originalAccountHmacKey = bindings.ACCOUNT_HMAC_KEY
    try {
      const { privateKey } = await generateKeyPair('EdDSA', { extractable: true })
      bindings.SESSION_SIGNING_PRIVATE_KEY = JSON.stringify(await exportJWK(privateKey))
      bindings.ACCOUNT_HMAC_KEY = 'test-account-hmac-key-with-enough-entropy'
      const installationId = crypto.randomUUID()
      const bootstrapId = crypto.randomUUID()
      const mappingStub = bindings.AUTH_CHALLENGES.get(bindings.AUTH_CHALLENGES.idFromName(bootstrapId))
      const mappingResponse = await mappingStub.fetch('https://durable.internal/guest-account', { method: 'POST' })
      expect(mappingResponse.status).toBe(200)
      const response = await SELF.fetch('https://eva.test/v1/auth/guest/bootstrap', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          bootstrapId,
          installationId,
          platform: 'ios',
          grants: ['health', 'journal'],
        }),
      })
      const rawBody = await response.text()
      expect(response.status, rawBody).toBe(200)
      const body = JSON.parse(rawBody) as {
        accountId: string
        accessToken: string
        identityKind: string
        trustTier: string
        quota: { limit: number; used: number; remaining: number }
        consent: { revision: number; grants: string[] }
      }
      expect(body.accountId).toMatch(/^guest_[A-Za-z0-9_-]{32,}$/)
      expect(body.accountId).not.toContain(installationId.toLowerCase())
      expect(body).toMatchObject({
        identityKind: 'guest',
        trustTier: 'low',
        quota: { limit: 20, used: 0, remaining: 20 },
        consent: { revision: 1, grants: ['health', 'journal'] },
      })
      const deletion = await SELF.fetch('https://eva.test/v1/account', {
        method: 'DELETE',
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${body.accessToken}` },
        body: JSON.stringify({ confirmation: 'deleteCloudEvaData' }),
      })
      expect(deletion.status).toBe(204)

      const replacement = await SELF.fetch('https://eva.test/v1/auth/guest/bootstrap', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ bootstrapId, installationId, platform: 'ios', grants: [] }),
      })
      expect(replacement.status).toBe(200)
      const replacementBody = await replacement.json<{ accountId: string }>()
      expect(replacementBody.accountId).not.toBe(body.accountId)
    } finally {
      bindings.SESSION_SIGNING_PRIVATE_KEY = originalSessionKey
      bindings.ACCOUNT_HMAC_KEY = originalAccountHmacKey
      await bindings.EVA_CONFIG.delete('runtime-config-v2')
    }
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

  it('keeps rolling quota reservations exact under concurrency', async () => {
    const { stub } = await bootstrappedAccount()
    const responses = await Promise.all(Array.from({ length: 21 }, (_, index) => stub.fetch(
      'https://durable.internal/credits/reserve',
      { method: 'POST', body: JSON.stringify({ requestId: `request-${index}`, amount: 1 }) },
    )))
    const bodies = await Promise.all(responses.map((response) => response.json<{ reserved: boolean }>()))
    expect(bodies.filter((body) => body.reserved)).toHaveLength(20)
    const credits = await (await stub.fetch('https://durable.internal/credits')).json<{ balance: number }>()
    expect(credits.balance).toBe(0)
  })

  it('caps background helper reservations at 100 per rolling window', async () => {
    const { stub } = await bootstrappedAccount()
    const responses = await Promise.all(Array.from({ length: 101 }, (_, index) => stub.fetch(
      'https://durable.internal/quota/reserve',
      { method: 'POST', body: JSON.stringify({ requestId: `helper-${index}`, kind: 'helper' }) },
    )))
    const bodies = await Promise.all(responses.map((response) => response.json<{ reserved: boolean }>()))
    expect(bodies.filter((body) => body.reserved)).toHaveLength(100)
  })

  it('allows exactly one concurrent reservation when one credit remains', async () => {
    const { stub } = await bootstrappedAccount()
    await Promise.all(Array.from({ length: 19 }, async (_, index) => {
      const requestId = `seed-${index}`
      await stub.fetch('https://durable.internal/quota/reserve', {
        method: 'POST', body: JSON.stringify({ requestId, kind: 'billable' }),
      })
      await stub.fetch('https://durable.internal/quota/commit', {
        method: 'POST', body: JSON.stringify({ requestId }),
      })
    }))
    const attempts = await Promise.all([crypto.randomUUID(), crypto.randomUUID()].map((requestId) => stub.fetch(
      'https://durable.internal/credits/reserve',
      { method: 'POST', body: JSON.stringify({ requestId, amount: 1 }) },
    )))
    const bodies = await Promise.all(attempts.map((response) => response.json<{ reserved: boolean; status: string }>()))
    expect(bodies.filter((body) => body.reserved)).toHaveLength(1)
    expect(bodies.filter((body) => body.status === 'exhausted')).toHaveLength(1)
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
    await expect(first.json()).resolves.toMatchObject({ credits: { balance: 20 } })
    await expect(second.json()).resolves.toMatchObject({ credits: { balance: 20 } })
  })

  it('expires successful answers individually after the rolling 24-hour window', async () => {
    const { stub } = await bootstrappedAccount()
    for (const requestId of ['old-answer', 'recent-answer']) {
      await stub.fetch('https://durable.internal/quota/reserve', {
        method: 'POST', body: JSON.stringify({ requestId, kind: 'billable' }),
      })
      await stub.fetch('https://durable.internal/quota/commit', {
        method: 'POST', body: JSON.stringify({ requestId }),
      })
    }
    await runInDurableObject(stub, async (_instance, state) => {
      const account = await state.storage.get<{
        quota: { reservations: Record<string, { committedAt?: number }> }
      }>('account')
      if (!account) throw new Error('Account fixture is missing.')
      account.quota.reservations['old-answer']!.committedAt = Date.now() - 86_400_001
      await state.storage.put('account', account)
    })
    await expect((await stub.fetch('https://durable.internal/quota')).json()).resolves.toMatchObject({
      limit: 20,
      used: 1,
      remaining: 19,
    })
  })

  it('merges guest quota by union and consent by reviewed intersection idempotently', async () => {
    const source = await bootstrappedAccount('guest')
    const target = await bootstrappedAccount()
    await source.stub.fetch('https://durable.internal/consent', {
      method: 'PUT', body: JSON.stringify({ expectedRevision: 0, grants: ['health', 'journal'] }),
    })
    await target.stub.fetch('https://durable.internal/consent', {
      method: 'PUT', body: JSON.stringify({ expectedRevision: 0, grants: ['health', 'lifeMoments'] }),
    })
    for (const [stub, requestId] of [[source.stub, 'guest-answer'], [target.stub, 'apple-answer']] as const) {
      await stub.fetch('https://durable.internal/quota/reserve', {
        method: 'POST', body: JSON.stringify({ requestId, kind: 'billable' }),
      })
      await stub.fetch('https://durable.internal/quota/commit', {
        method: 'POST', body: JSON.stringify({ requestId }),
      })
    }
    const exported = await (await source.stub.fetch('https://durable.internal/merge/export')).json<{ state: unknown }>()
    const mergeId = crypto.randomUUID()
    const merge = () => target.stub.fetch('https://durable.internal/merge/import', {
      method: 'POST', body: JSON.stringify({ mergeId, source: exported.state }),
    })
    await expect((await merge()).json()).resolves.toMatchObject({
      consent: { grants: ['health'], reviewRequired: true },
      quota: { used: 2, remaining: 18 },
    })
    await expect((await merge()).json()).resolves.toMatchObject({
      alreadyMerged: true,
      quota: { used: 2, remaining: 18 },
    })
  })

  it('preserves both quota timestamps when linked accounts reuse a request ID', async () => {
    const source = await bootstrappedAccount()
    const target = await bootstrappedAccount()
    for (const stub of [source.stub, target.stub]) {
      await stub.fetch('https://durable.internal/quota/reserve', {
        method: 'POST', body: JSON.stringify({ requestId: 'same-client-request-id', kind: 'billable' }),
      })
      await stub.fetch('https://durable.internal/quota/commit', {
        method: 'POST', body: JSON.stringify({ requestId: 'same-client-request-id' }),
      })
    }
    const exported = await (await source.stub.fetch('https://durable.internal/merge/export'))
      .json<{ state: unknown }>()
    const merged = await target.stub.fetch('https://durable.internal/merge/import', {
      method: 'POST', body: JSON.stringify({ mergeId: crypto.randomUUID(), source: exported.state }),
    })
    await expect(merged.json()).resolves.toMatchObject({ quota: { used: 2, remaining: 18 } })
  })

  it('waits for guest work to settle and carries account spend through linking', async () => {
    const source = await bootstrappedAccount('guest')
    const target = await bootstrappedAccount()
    await source.stub.fetch('https://durable.internal/quota/reserve', {
      method: 'POST', body: JSON.stringify({ requestId: 'active-answer', kind: 'billable' }),
    })
    const busy = await source.stub.fetch('https://durable.internal/merge/freeze-export', {
      method: 'POST', body: JSON.stringify({ targetAccountId: target.accountId }),
    })
    expect(busy.status).toBe(409)
    await source.stub.fetch('https://durable.internal/quota/release', {
      method: 'POST', body: JSON.stringify({ requestId: 'active-answer' }),
    })

    await source.stub.fetch('https://durable.internal/cost/reserve', {
      method: 'POST',
      body: JSON.stringify({ requestId: 'settled-answer', globalRequestId: 'source-global', estimatedMicroUsd: 100 }),
    })
    await source.stub.fetch('https://durable.internal/cost/commit', {
      method: 'POST', body: JSON.stringify({ requestId: 'settled-answer', actualMicroUsd: 40 }),
    })
    const frozen = await source.stub.fetch('https://durable.internal/merge/freeze-export', {
      method: 'POST', body: JSON.stringify({ targetAccountId: target.accountId }),
    })
    expect(frozen.status).toBe(200)
    const exported = await frozen.json<{ state: unknown }>()
    const merged = await target.stub.fetch('https://durable.internal/merge/import', {
      method: 'POST', body: JSON.stringify({ mergeId: crypto.randomUUID(), source: exported.state }),
    })
    expect(merged.status).toBe(200)
    await runInDurableObject(target.stub, async (_instance, state) => {
      const account = await state.storage.get<{
        cost: { hourlyCommittedMicroUsd: Record<string, number>; reservations: Record<string, { globalSettled?: boolean }> }
      }>('account')
      expect(Object.values(account?.cost.hourlyCommittedMicroUsd ?? {}).reduce((sum, value) => sum + value, 0)).toBe(40)
      expect(Object.values(account?.cost.reservations ?? {}).some((value) => value.globalSettled !== true)).toBe(true)
    })
  })

  it('reconciles an interrupted guest link through the canonical Apple coordinator', async () => {
    const bootstrapId = crypto.randomUUID()
    const mapping = bindings.AUTH_CHALLENGES.get(bindings.AUTH_CHALLENGES.idFromName(bootstrapId))
    const mapped = await (await mapping.fetch('https://durable.internal/guest-account', { method: 'POST' }))
      .json<{ accountId: string }>()
    const source = bindings.EVA_ACCOUNTS.get(bindings.EVA_ACCOUNTS.idFromName(mapped.accountId))
    const sourceFamily = crypto.randomUUID()
    const sourceInstallation = crypto.randomUUID()
    await source.fetch('https://durable.internal/bootstrap', {
      method: 'POST',
      body: JSON.stringify({
        accountId: mapped.accountId,
        identityKind: 'guest',
        guestBootstrapId: bootstrapId,
        grants: ['health'],
        familyId: sourceFamily,
        refreshTokenHash: 'guest-refresh',
        installationId: sourceInstallation,
        platform: 'ios',
        authenticatedAt: Date.now(),
        refreshExpiresAt: Date.now() + 86_400_000,
      }),
    })
    const requestId = crypto.randomUUID()
    await source.fetch('https://durable.internal/quota/reserve', {
      method: 'POST', body: JSON.stringify({ requestId, kind: 'billable' }),
    })
    await source.fetch('https://durable.internal/quota/commit', {
      method: 'POST', body: JSON.stringify({ requestId }),
    })

    const targetAccountId = `apple-${crypto.randomUUID()}`
    const target = bindings.EVA_ACCOUNTS.get(bindings.EVA_ACCOUNTS.idFromName(targetAccountId))
    await target.fetch('https://durable.internal/bootstrap', {
      method: 'POST',
      body: JSON.stringify({
        accountId: targetAccountId,
        identityKind: 'apple',
        familyId: crypto.randomUUID(),
        refreshTokenHash: 'apple-refresh',
        installationId: crypto.randomUUID(),
        platform: 'ios',
        authenticatedAt: Date.now(),
        refreshExpiresAt: Date.now() + 86_400_000,
      }),
    })
    const coordinator = bindings.AUTH_CHALLENGES.get(
      bindings.AUTH_CHALLENGES.idFromName(`apple-link:${targetAccountId}`),
    )
    const mergeId = crypto.randomUUID()
    expect((await coordinator.fetch('https://durable.internal/link-pending', {
      method: 'POST',
      body: JSON.stringify({ mergeId, sourceAccountId: mapped.accountId, targetAccountId }),
    })).status).toBe(200)
    const reconciled = await coordinator.fetch('https://durable.internal/link-pending/reconcile', { method: 'POST' })
    expect(reconciled.status).toBe(200)
    await expect(reconciled.json()).resolves.toMatchObject({
      reconciled: true,
      quota: { used: 1, remaining: 19 },
      consent: { grants: [], reviewRequired: true },
    })
    expect((await source.fetch('https://durable.internal/quota')).status).toBe(404)
    const replacementMapping = await (await mapping.fetch('https://durable.internal/guest-account', { method: 'POST' }))
      .json<{ accountId: string }>()
    expect(replacementMapping.accountId).not.toBe(mapped.accountId)
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
    expect(credits.balance).toBe(19)
  })

  it('reconciles a stranded credit reservation from a Durable Object alarm', async () => {
    const { stub } = await bootstrappedAccount()
    const requestId = crypto.randomUUID()
    await stub.fetch('https://durable.internal/credits/reserve', {
      method: 'POST', body: JSON.stringify({ requestId, amount: 1 }),
    })
    await runInDurableObject(stub, async (_instance, state) => {
      const account = await state.storage.get<{
        quota: { reservations: Record<string, { expiresAt: number }> }
      }>('account')
      if (!account?.quota.reservations[requestId]) throw new Error('Reservation fixture is missing.')
      account.quota.reservations[requestId].expiresAt = 0
      await state.storage.put('account', account)
      await state.storage.setAlarm(Date.now() - 1)
    })
    await runDurableObjectAlarm(stub)
    const credits = await (await stub.fetch('https://durable.internal/credits')).json<{ balance: number }>()
    expect(credits.balance).toBe(20)
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

    await runInDurableObject(stub, async (_instance, state) => {
      const account = await state.storage.get<{
        devices: Record<string, { adultEligibleExpiresAt?: number }>
      }>('account')
      if (!account?.devices[installationId]) throw new Error('Age fixture is missing.')
      account.devices[installationId].adultEligibleExpiresAt = Date.now() - 1
      await state.storage.put('account', account)
    })
    const expired = await stub.fetch('https://durable.internal/authorize', {
      method: 'POST',
      body: JSON.stringify({ familyId, installationId, platform: 'ios', requireAdult: true, requireAttestation: false }),
    })
    await expect(expired.json()).resolves.toMatchObject({ authorized: false, reason: 'age' })
  })

  it('revokes a refresh family when an already-rotated token is reused', async () => {
    const { familyId, installationId, stub } = await bootstrappedAccount()
    const rotate = (
      presentedTokenHash: string,
      presentedGeneration: number,
      replacementTokenHash: string,
      replacementGeneration: number,
    ) => stub.fetch(
      'https://durable.internal/refresh/rotate',
      {
        method: 'POST',
        body: JSON.stringify({
          familyId,
          presentedTokenHash,
          presentedGeneration,
          replacementTokenHash,
          replacementGeneration,
          replacementExpiresAt: Date.now() + 86_400_000,
          installationId,
          platform: 'ios',
        }),
      },
    )
    let currentHash = 'refresh-original'
    for (let generation = 0; generation < 12; generation += 1) {
      const nextHash = `refresh-${generation + 1}`
      expect((await rotate(currentHash, generation, nextHash, generation + 1)).status).toBe(200)
      currentHash = nextHash
    }
    // Detection is generation-based, so it still works long after the former
    // eight-hash replay window would have forgotten this token.
    expect((await rotate('refresh-original', 0, 'refresh-attacker', 13)).status).toBe(401)
    expect((await rotate(currentHash, 12, 'refresh-after-revocation', 13)).status).toBe(401)
  })

  it('checks refresh device binding before rotating the token', async () => {
    const { familyId, installationId, stub } = await bootstrappedAccount()
    const rotate = (candidateInstallationId: string) => stub.fetch('https://durable.internal/refresh/rotate', {
      method: 'POST',
      body: JSON.stringify({
        familyId,
        presentedTokenHash: 'refresh-original',
        presentedGeneration: 0,
        replacementTokenHash: 'refresh-next',
        replacementGeneration: 1,
        replacementExpiresAt: Date.now() + 86_400_000,
        installationId: candidateInstallationId,
        platform: 'ios',
      }),
    })
    expect((await rotate(crypto.randomUUID())).status).toBe(401)
    expect((await rotate(installationId)).status).toBe(200)
  })

  it('allows low-trust Catalyst bootstrap when risk evidence is unavailable', async () => {
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
    expect(response.status).toBe(200)
    await expect(response.json()).resolves.toMatchObject({ trustTier: 'low', credits: { balance: 20 } })
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

  it('blocks known under-13 devices and fails closed when a regional age decision is mandatory', async () => {
    const knownMinor = await bootstrappedAccount()
    await knownMinor.stub.fetch('https://durable.internal/device/age', {
      method: 'POST',
      body: JSON.stringify({
        installationId: knownMinor.installationId,
        platform: 'ios',
        eligibleAdult: false,
        lowerBound: 10,
        policyRequired: false,
        declaration: 'shared:apple-dar-13-v2',
      }),
    })
    await expect((await knownMinor.stub.fetch('https://durable.internal/authorize', {
      method: 'POST',
      body: JSON.stringify({
        familyId: knownMinor.familyId,
        installationId: knownMinor.installationId,
        platform: 'ios',
        requireAdult: false,
        requireAttestation: false,
      }),
    })).json()).resolves.toMatchObject({ authorized: false, reason: 'age' })

    const mandatoryUnknown = await bootstrappedAccount()
    await mandatoryUnknown.stub.fetch('https://durable.internal/device/age', {
      method: 'POST',
      body: JSON.stringify({
        installationId: mandatoryUnknown.installationId,
        platform: 'ios',
        eligibleAdult: false,
        policyRequired: true,
        declaration: 'declined:apple-dar-13-v2',
      }),
    })
    await expect((await mandatoryUnknown.stub.fetch('https://durable.internal/authorize', {
      method: 'POST',
      body: JSON.stringify({
        familyId: mandatoryUnknown.familyId,
        installationId: mandatoryUnknown.installationId,
        platform: 'ios',
        requireAdult: true,
        requireAttestation: false,
      }),
    })).json()).resolves.toMatchObject({ authorized: false, reason: 'age' })
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

  it('keeps overlapping App Attest challenges independently consumable', async () => {
    const { installationId, stub } = await bootstrappedAccount()
    const issue = async () => (await (await stub.fetch('https://durable.internal/device/attestation/challenge', {
      method: 'POST', body: JSON.stringify({ installationId }),
    })).json<{ challenge: string }>()).challenge
    const first = await issue()
    const second = await issue()
    expect(first).not.toBe(second)

    const registration = await stub.fetch('https://durable.internal/device/attestation/register', {
      method: 'POST',
      body: JSON.stringify({ installationId, challenge: first, keyId: 'key-one', publicKey: 'public-key-one' }),
    })
    expect(registration.status).toBe(200)
    const material = await stub.fetch('https://durable.internal/device/assertion/material', {
      method: 'POST', body: JSON.stringify({ installationId, challenge: second }),
    })
    expect(material.status).toBe(200)
    await expect(material.json()).resolves.toMatchObject({ keyId: 'key-one', counter: 0 })
  })

  it('serializes concurrent Apple links by canonical account', async () => {
    const stub = bindings.AUTH_CHALLENGES.get(bindings.AUTH_CHALLENGES.idFromName('apple-link:test-account'))
    const first = await stub.fetch('https://durable.internal/link-lock/acquire', {
      method: 'POST', body: JSON.stringify({ linkId: 'first', ttlSeconds: 120 }),
    })
    const second = await stub.fetch('https://durable.internal/link-lock/acquire', {
      method: 'POST', body: JSON.stringify({ linkId: 'second', ttlSeconds: 120 }),
    })
    expect(first.status).toBe(200)
    expect(second.status).toBe(409)
    await stub.fetch('https://durable.internal/link-lock/release', {
      method: 'POST', body: JSON.stringify({ linkId: 'first' }),
    })
    const retry = await stub.fetch('https://durable.internal/link-lock/acquire', {
      method: 'POST', body: JSON.stringify({ linkId: 'second', ttlSeconds: 120 }),
    })
    expect(retry.status).toBe(200)
  })

  it('persists Apple revocation work without exposing the encrypted credential in status', async () => {
    const stub = bindings.AUTH_CHALLENGES.get(
      bindings.AUTH_CHALLENGES.idFromName(`apple-revoke:${crypto.randomUUID()}`),
    )
    const scheduled = await stub.fetch('https://durable.internal/apple-revocation', {
      method: 'POST',
      body: JSON.stringify({ encryptedRefreshToken: 'sealed-secret-value', clientId: 'com.example.app' }),
    })
    expect(scheduled.status).toBe(200)
    const status = await (await stub.fetch('https://durable.internal/apple-revocation')).text()
    expect(status).toContain('"attempts":0')
    expect(status).not.toContain('sealed-secret-value')
    expect(status).not.toContain('com.example.app')
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
    await expect((await stub.fetch('https://durable.internal/credits')).json()).resolves.toMatchObject({ balance: 19 })
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
    })).json()).resolves.toMatchObject({ claimed: true, included: false, credits: { balance: 19 } })
    await expect((await stub.fetch('https://durable.internal/speech/fail', {
      method: 'POST', body: JSON.stringify({ ticketId }),
    })).json()).resolves.toMatchObject({ credits: { balance: 19 } })

    const committedReservationId = crypto.randomUUID()
    await stub.fetch('https://durable.internal/speech/claim', {
      method: 'POST',
      body: JSON.stringify({
        ticketId, textHash: 'answer-hash', allowPaidRegeneration: true, paidReservationId: committedReservationId,
      }),
    })
    await expect((await stub.fetch('https://durable.internal/speech/complete', {
      method: 'POST', body: JSON.stringify({ ticketId }),
    })).json()).resolves.toMatchObject({ credits: { balance: 19 } })
    await expect((await stub.fetch('https://durable.internal/speech/fail', {
      method: 'POST', body: JSON.stringify({ ticketId }),
    })).json()).resolves.toMatchObject({ credits: { balance: 19 } })
  })

  it('splits speech on sentence boundaries and enforces the hard limit', () => {
    const chunks = sentenceChunks(`${'A'.repeat(3_500)}. ${'B'.repeat(3_500)}.`, 4_000)
    expect(chunks).toHaveLength(2)
    expect(chunks.every((chunk) => chunk.length <= 4_000)).toBe(true)
  })
})
