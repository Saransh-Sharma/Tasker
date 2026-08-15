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

describe('EVA Cloud Worker', () => {
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
