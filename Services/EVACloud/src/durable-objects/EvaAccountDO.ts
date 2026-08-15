import { DurableObject } from 'cloudflare:workers'
import type { EvaConsentPolicy, EvaCreditState } from '@lifeboard/eva-contracts'
import type { Env } from '../environment.js'
import type {
  AccountAuthorization,
  CostReservation,
  CreditReservation,
  EvaAccountState,
  EvaDeviceState,
  SpeechTicketState,
} from './account-model.js'

const dayMilliseconds = 24 * 60 * 60 * 1_000
const hourMilliseconds = 60 * 60 * 1_000
const reservationLifetimeMilliseconds = 5 * 60 * 1_000

function jsonRequest<T>(request: Request): Promise<T> {
  return request.json<T>()
}

export class EvaAccountDO extends DurableObject<Env> {
  private operationQueue: Promise<void> = Promise.resolve()

  private async load(): Promise<EvaAccountState | undefined> {
    const state = await this.ctx.storage.get<EvaAccountState>('account')
    if (!state) return undefined
    const legacyCost = state.cost as EvaAccountState['cost'] & {
      windowStartedAt?: number
      committedMicroUsd?: number
      reservations?: Record<string, number | CostReservation>
    }
    if (!legacyCost.hourlyCommittedMicroUsd) {
      const bucket = String(Math.floor((legacyCost.windowStartedAt ?? state.createdAt) / hourMilliseconds))
      legacyCost.hourlyCommittedMicroUsd = legacyCost.committedMicroUsd ? { [bucket]: legacyCost.committedMicroUsd } : {}
    }
    const normalizedReservations: Record<string, CostReservation> = {}
    for (const [requestId, value] of Object.entries(legacyCost.reservations ?? {})) {
      normalizedReservations[requestId] = typeof value === 'number'
        ? {
          requestId,
          globalRequestId: requestId,
          amountMicroUsd: value,
          createdAt: Date.now(),
          expiresAt: Date.now() + reservationLifetimeMilliseconds,
          status: 'reserved',
        }
        : value
    }
    state.cost = { hourlyCommittedMicroUsd: legacyCost.hourlyCommittedMicroUsd, reservations: normalizedReservations }
    for (const reservation of Object.values(state.creditReservations)) {
      reservation.expiresAt ??= reservation.createdAt + reservationLifetimeMilliseconds
    }
    return state
  }

  private async save(state: EvaAccountState): Promise<void> {
    await this.ctx.storage.put('account', state)
  }

  private async appendLedger(type: string, fields: Record<string, unknown>): Promise<void> {
    const timestamp = Date.now()
    const key = `ledger:${String(timestamp).padStart(16, '0')}:${crypto.randomUUID()}`
    await this.ctx.storage.put(key, { type, timestamp, ...fields })
  }

  private applyRefill(state: EvaAccountState, now = Date.now()): void {
    const elapsedPeriods = Math.floor((now - state.credits.refillAnchor) / state.credits.refillPeriodMs)
    if (elapsedPeriods <= 0) return
    const previousBalance = state.credits.balance
    state.credits.balance = Math.min(
      state.credits.capacity,
      state.credits.balance + elapsedPeriods * state.credits.refillAmount,
    )
    state.credits.refillAnchor += elapsedPeriods * state.credits.refillPeriodMs
    if (state.credits.balance !== previousBalance) {
      this.ctx.waitUntil(this.appendLedger('periodic_grant', {
        periods: elapsedPeriods,
        amount: state.credits.balance - previousBalance,
        balance: state.credits.balance,
      }))
    }
  }

  private creditState(state: EvaAccountState): EvaCreditState {
    this.applyRefill(state)
    return {
      balance: state.credits.balance,
      capacity: state.credits.capacity,
      refillAmount: state.credits.refillAmount,
      nextRefillAt: new Date(state.credits.refillAnchor + state.credits.refillPeriodMs).toISOString(),
    }
  }

  private rollingCost(state: EvaAccountState, now = Date.now()): number {
    const oldestBucket = Math.floor((now - dayMilliseconds) / hourMilliseconds)
    for (const bucket of Object.keys(state.cost.hourlyCommittedMicroUsd)) {
      if (Number(bucket) <= oldestBucket) delete state.cost.hourlyCommittedMicroUsd[bucket]
    }
    return Object.values(state.cost.hourlyCommittedMicroUsd).reduce((sum, amount) => sum + amount, 0)
  }

  private async scheduleReconciliation(state: EvaAccountState): Promise<void> {
    const expiries = [
      ...Object.values(state.creditReservations)
        .filter((value) => value.status === 'reserved' || value.status === 'running')
        .map((value) => value.expiresAt),
      ...Object.values(state.cost.reservations)
        .filter((value) => value.status === 'reserved' || value.status === 'running' || (value.status === 'committed' && !value.globalSettled))
        .map((value) => value.expiresAt),
      ...Object.values(state.speechTickets)
        .filter((value) => value.state === 'generating' && value.generationExpiresAt)
        .map((value) => value.generationExpiresAt as number),
    ]
    if (expiries.length > 0) await this.ctx.storage.setAlarm(Math.min(...expiries))
  }

  async alarm(): Promise<void> {
    const state = await this.load()
    if (!state) return
    const now = Date.now()
    const globalReleases: string[] = []
    const globalCommits: Array<{ requestId: string; actualMicroUsd: number; reservation: CostReservation }> = []
    for (const reservation of Object.values(state.creditReservations)) {
      if ((reservation.status === 'reserved' || reservation.status === 'running') && reservation.expiresAt <= now) {
        reservation.status = 'expired'
        state.credits.balance = Math.min(state.credits.capacity, state.credits.balance + reservation.amount)
        await this.appendLedger('release', {
          requestId: reservation.requestId,
          amount: reservation.amount,
          reason: 'reservation_expired',
          balance: state.credits.balance,
        })
      }
    }
    for (const reservation of Object.values(state.cost.reservations)) {
      if ((reservation.status === 'reserved' || reservation.status === 'running') && reservation.expiresAt <= now) {
        reservation.status = 'expired'
        globalReleases.push(reservation.globalRequestId)
      } else if (reservation.status === 'committed' && !reservation.globalSettled && reservation.actualMicroUsd !== undefined) {
        globalCommits.push({
          requestId: reservation.globalRequestId,
          actualMicroUsd: reservation.actualMicroUsd,
          reservation,
        })
      }
    }
    for (const ticket of Object.values(state.speechTickets)) {
      if (ticket.state !== 'generating' || !ticket.generationExpiresAt || ticket.generationExpiresAt > now) continue
      ticket.state = ticket.paidReservationId ? 'consumed' : 'unused'
      ticket.generationExpiresAt = undefined
      if (ticket.paidReservationId) {
        const reservation = state.creditReservations[ticket.paidReservationId]
        if (reservation && (reservation.status === 'reserved' || reservation.status === 'running')) {
          reservation.status = 'expired'
          state.credits.balance = Math.min(state.credits.capacity, state.credits.balance + reservation.amount)
        }
        ticket.paidReservationId = undefined
      }
    }
    await this.save(state)
    const global = this.env.GLOBAL_BUDGET.get(this.env.GLOBAL_BUDGET.idFromName('production-global-v1'))
    await Promise.allSettled(globalReleases.map((requestId) => global.fetch('https://durable.internal/release', {
      method: 'POST', body: JSON.stringify({ requestId }),
    })))
    for (const commit of globalCommits) {
      try {
        const response = await global.fetch('https://durable.internal/commit', {
          method: 'POST', body: JSON.stringify({ requestId: commit.requestId, actualMicroUsd: commit.actualMicroUsd }),
        })
        if (response.ok) commit.reservation.globalSettled = true
        else commit.reservation.expiresAt = Date.now() + reservationLifetimeMilliseconds
      } catch {
        commit.reservation.expiresAt = Date.now() + reservationLifetimeMilliseconds
      }
    }
    await this.save(state)
    await this.scheduleReconciliation(state)
  }

  fetch(request: Request): Promise<Response> {
    const operation = this.operationQueue.then(() => this.handle(request))
    this.operationQueue = operation.then(() => undefined, () => undefined)
    return operation
  }

  private async handle(request: Request): Promise<Response> {
    const url = new URL(request.url)
    const path = url.pathname

    if (request.method === 'POST' && path === '/bootstrap') {
      const body = await jsonRequest<{
        accountId: string
        encryptedAppleRefreshToken?: string
        appleClientId?: string
        familyId: string
        refreshTokenHash: string
        installationId: string
        platform: 'ios' | 'catalyst'
        catalystRisk?: EvaDeviceState['catalystRisk']
        authenticatedAt: number
        refreshExpiresAt: number
      }>(request)
      if (body.platform === 'catalyst' && !body.catalystRisk) {
        return Response.json({ message: 'Catalyst risk evidence is required.' }, { status: 401 })
      }
      let state = await this.load()
      const isNew = !state
      if (!state) {
        const now = Date.now()
        state = {
          accountId: body.accountId,
          status: 'active',
          createdAt: now,
          encryptedAppleRefreshToken: body.encryptedAppleRefreshToken,
          appleClientId: body.appleClientId,
          credits: {
            balance: 100,
            capacity: 100,
            refillAmount: 20,
            refillPeriodMs: dayMilliseconds,
            refillAnchor: now,
          },
          consent: {
            schemaVersion: 2,
            revision: 0,
            grants: [],
            updatedAt: new Date(now).toISOString(),
          },
          devices: {},
          refreshFamilies: {},
          creditReservations: {},
          speechTickets: {},
          cost: { hourlyCommittedMicroUsd: {}, reservations: {} },
        }
        await this.appendLedger('initial_grant', { amount: 100, balance: 100 })
      }
      if (state.status === 'deleted') return Response.json({ message: 'Account was deleted.' }, { status: 410 })
      state.encryptedAppleRefreshToken = body.encryptedAppleRefreshToken ?? state.encryptedAppleRefreshToken
      state.appleClientId = body.appleClientId ?? state.appleClientId
      const existingDevice = state.devices[body.installationId]
      if (existingDevice && existingDevice.platform !== body.platform) {
        return Response.json({ message: 'Device platform binding cannot change.' }, { status: 409 })
      }
      state.devices[body.installationId] ??= {
        installationId: body.installationId,
        platform: body.platform,
        createdAt: Date.now(),
      }
      const device = state.devices[body.installationId]
      if (!device) return Response.json({ message: 'Device registration failed.' }, { status: 500 })
      if (body.platform === 'catalyst') {
        device.catalystRisk = body.catalystRisk
      }
      state.refreshFamilies[body.familyId] = {
        familyId: body.familyId,
        currentTokenHash: body.refreshTokenHash,
        usedTokenHashes: [],
        installationId: body.installationId,
        authenticatedAt: body.authenticatedAt,
        expiresAt: body.refreshExpiresAt,
      }
      await this.save(state)
      return Response.json({ created: isNew, credits: this.creditState(state), consent: state.consent })
    }

    const state = await this.load()
    if (!state || state.status === 'deleted') {
      return Response.json({ message: 'Account is unavailable.' }, { status: 404 })
    }

    if (request.method === 'POST' && path === '/refresh/rotate') {
      const body = await jsonRequest<{
        familyId: string
        presentedTokenHash: string
        replacementTokenHash: string
        replacementExpiresAt: number
      }>(request)
      const family = state.refreshFamilies[body.familyId]
      if (!family || family.revokedAt || family.expiresAt <= Date.now()) {
        return Response.json({ message: 'Refresh session is invalid.' }, { status: 401 })
      }
      if (family.usedTokenHashes.includes(body.presentedTokenHash)) {
        family.revokedAt = Date.now()
        await this.save(state)
        return Response.json({ message: 'Refresh token reuse detected.' }, { status: 401 })
      }
      if (family.currentTokenHash !== body.presentedTokenHash) {
        return Response.json({ message: 'Refresh session is invalid.' }, { status: 401 })
      }
      const refreshMinute = Math.floor(Date.now() / 60_000)
      const refreshKey = `rate:refresh:${body.familyId}`
      const refreshRecord = await this.ctx.storage.get<{ minute: number; count: number }>(refreshKey)
      const refreshCurrent = refreshRecord?.minute === refreshMinute ? refreshRecord : { minute: refreshMinute, count: 0 }
      if (refreshCurrent.count >= 20) {
        return Response.json({ message: 'Refresh rate limit exceeded.' }, { status: 429 })
      }
      refreshCurrent.count += 1
      await this.ctx.storage.put(refreshKey, refreshCurrent)
      family.usedTokenHashes.push(family.currentTokenHash)
      family.usedTokenHashes = family.usedTokenHashes.slice(-8)
      family.currentTokenHash = body.replacementTokenHash
      family.expiresAt = body.replacementExpiresAt
      await this.save(state)
      return Response.json({
        rotated: true,
        family,
        platform: state.devices[family.installationId]?.platform,
      })
    }

    if (request.method === 'POST' && path === '/session/revoke') {
      const { familyId } = await jsonRequest<{ familyId: string }>(request)
      const family = state.refreshFamilies[familyId]
      if (family) family.revokedAt = Date.now()
      await this.save(state)
      return Response.json({ revoked: true })
    }

    if (request.method === 'POST' && path === '/apple/revoke') {
      for (const family of Object.values(state.refreshFamilies)) family.revokedAt = Date.now()
      state.encryptedAppleRefreshToken = undefined
      await this.save(state)
      return Response.json({ revoked: true })
    }

    if (request.method === 'GET' && path === '/apple/credential') {
      return Response.json({
        encryptedRefreshToken: state.encryptedAppleRefreshToken,
        clientId: state.appleClientId,
      })
    }

    if (request.method === 'POST' && path === '/authorize') {
      const body = await jsonRequest<{
        familyId: string
        installationId: string
        platform: 'ios' | 'catalyst'
        requireAdult: boolean
        requireAttestation: boolean
      }>(request)
      const family = state.refreshFamilies[body.familyId]
      const device = state.devices[body.installationId]
      let result: AccountAuthorization
      if (!family || family.revokedAt || family.expiresAt <= Date.now()) {
        result = { authorized: false, reason: 'session' }
      } else if (!device || device.platform !== body.platform) {
        result = { authorized: false, reason: 'attestation' }
      } else if (!device || (body.requireAdult && (
        !device.adultEligibleAt || !device.adultEligibleExpiresAt || device.adultEligibleExpiresAt <= Date.now()
      ))) {
        if (device?.adultEligibleExpiresAt && device.adultEligibleExpiresAt <= Date.now()) {
          device.adultEligibleAt = undefined
          device.adultEligibleExpiresAt = undefined
        }
        result = { authorized: false, reason: 'age' }
      } else if (device.platform === 'catalyst' && !device.catalystRisk) {
        result = { authorized: false, reason: 'attestation' }
      } else if (body.requireAttestation && device.platform === 'ios' && !device.attestationKeyId) {
        result = { authorized: false, reason: 'attestation' }
      } else {
        result = { authorized: true, credits: this.creditState(state), consent: state.consent }
      }
      await this.save(state)
      return Response.json(result)
    }

    if (request.method === 'POST' && path === '/rate/consume') {
      const { bucket, limit } = await jsonRequest<{ bucket: string; limit: number }>(request)
      const key = `rate:${bucket}`
      const minute = Math.floor(Date.now() / 60_000)
      const record = await this.ctx.storage.get<{ minute: number; count: number }>(key)
      const current = record?.minute === minute ? record : { minute, count: 0 }
      if (current.count >= limit) {
        return Response.json({ allowed: false, retryAfter: 60 - Math.floor((Date.now() % 60_000) / 1_000) })
      }
      current.count += 1
      await this.ctx.storage.put(key, current)
      return Response.json({ allowed: true, remaining: limit - current.count })
    }

    if (request.method === 'POST' && path === '/device/age') {
      const body = await jsonRequest<{
        installationId: string
        platform: 'ios' | 'catalyst'
        eligibleAdult: boolean
        declaration: string
      }>(request)
      const device: EvaDeviceState = state.devices[body.installationId] ?? {
        installationId: body.installationId,
        platform: body.platform,
        createdAt: Date.now(),
      }
      device.platform = body.platform
      device.ageDeclaration = body.declaration
      device.adultEligibleAt = body.eligibleAdult ? Date.now() : undefined
      device.adultEligibleExpiresAt = body.eligibleAdult ? Date.now() + 24 * 60 * 60 * 1_000 : undefined
      state.devices[body.installationId] = device
      await this.save(state)
      return Response.json({
        eligibleAdult: Boolean(device.adultEligibleAt),
        expiresAt: device.adultEligibleExpiresAt ? new Date(device.adultEligibleExpiresAt).toISOString() : undefined,
      })
    }

    if (request.method === 'POST' && path === '/device/attestation/challenge') {
      const { installationId } = await jsonRequest<{ installationId: string }>(request)
      const challenge = crypto.randomUUID()
      await this.ctx.storage.put(`attestation-challenge:${installationId}`, {
        challenge,
        expiresAt: Date.now() + 5 * 60 * 1_000,
      })
      return Response.json({ challenge })
    }

    if (request.method === 'POST' && path === '/device/attestation/register') {
      const body = await jsonRequest<{
        installationId: string
        keyId: string
        publicKey: string
        challenge: string
      }>(request)
      const challengeState = await this.ctx.storage.get<{ challenge: string; expiresAt: number }>(
        `attestation-challenge:${body.installationId}`,
      )
      if (!challengeState || challengeState.expiresAt <= Date.now() || challengeState.challenge !== body.challenge) {
        return Response.json({ message: 'Attestation challenge is invalid.' }, { status: 409 })
      }
      const device = state.devices[body.installationId]
      if (!device || device.platform !== 'ios') {
        return Response.json({ message: 'The iOS installation is not registered.' }, { status: 409 })
      }
      device.attestationKeyId = body.keyId
      device.attestationPublicKey = body.publicKey
      device.attestationCounter = 0
      await this.ctx.storage.delete(`attestation-challenge:${body.installationId}`)
      await this.save(state)
      return Response.json({ registered: true })
    }

    if (request.method === 'POST' && path === '/device/assertion/material') {
      const body = await jsonRequest<{ installationId: string; challenge: string }>(request)
      const challengeKey = `attestation-challenge:${body.installationId}`
      const challengeState = await this.ctx.storage.get<{ challenge: string; expiresAt: number }>(challengeKey)
      const device = state.devices[body.installationId]
      if (
        !challengeState
        || challengeState.expiresAt <= Date.now()
        || challengeState.challenge !== body.challenge
        || !device?.attestationKeyId
        || !device.attestationPublicKey
      ) {
        return Response.json({ message: 'Assertion challenge is invalid.' }, { status: 409 })
      }
      await this.ctx.storage.delete(challengeKey)
      return Response.json({
        keyId: device.attestationKeyId,
        publicKey: device.attestationPublicKey,
        counter: device.attestationCounter ?? 0,
      })
    }

    if (request.method === 'POST' && path === '/device/assertion/commit') {
      const { installationId, counter } = await jsonRequest<{ installationId: string; counter: number }>(request)
      const device = state.devices[installationId]
      if (!device?.attestationKeyId || counter <= (device.attestationCounter ?? 0)) {
        return Response.json({ message: 'Assertion counter is invalid.' }, { status: 409 })
      }
      device.attestationCounter = counter
      await this.save(state)
      return Response.json({ committed: true })
    }

    if (request.method === 'GET' && path === '/credits') {
      const credits = this.creditState(state)
      await this.save(state)
      return Response.json(credits)
    }

    if (request.method === 'POST' && path === '/credits/reserve') {
      const { requestId, amount = 1 } = await jsonRequest<{ requestId: string; amount?: number }>(request)
      this.applyRefill(state)
      const existing = state.creditReservations[requestId]
      if (existing) {
        return Response.json({
          reserved: false,
          status: existing.status,
          credits: this.creditState(state),
        })
      }
      if (state.credits.balance < amount) {
        await this.save(state)
        return Response.json({ reserved: false, status: 'insufficient', credits: this.creditState(state) })
      }
      state.credits.balance -= amount
      const now = Date.now()
      const reservation: CreditReservation = {
        requestId,
        amount,
        createdAt: now,
        expiresAt: now + reservationLifetimeMilliseconds,
        status: 'reserved',
      }
      state.creditReservations[requestId] = reservation
      await this.appendLedger('reserve', { requestId, amount, balance: state.credits.balance })
      await this.save(state)
      await this.scheduleReconciliation(state)
      return Response.json({ reserved: true, status: 'reserved', credits: this.creditState(state) })
    }

    if (request.method === 'POST' && path === '/request/running') {
      const { requestId } = await jsonRequest<{ requestId: string }>(request)
      const expiresAt = Date.now() + reservationLifetimeMilliseconds
      const credit = state.creditReservations[requestId]
      const cost = state.cost.reservations[requestId]
      if (credit?.status === 'reserved') credit.status = 'running'
      if (cost?.status === 'reserved') cost.status = 'running'
      if (credit?.status === 'running') credit.expiresAt = expiresAt
      if (cost?.status === 'running') cost.expiresAt = expiresAt
      await this.save(state)
      await this.scheduleReconciliation(state)
      return Response.json({ running: Boolean(credit || cost) })
    }

    if (request.method === 'POST' && path === '/credits/commit') {
      const body = await jsonRequest<{
        requestId: string
        speechTicket?: { ticketId: string; textHash: string; expiresAt: number }
      }>(request)
      const reservation = state.creditReservations[body.requestId]
      const transitioned = reservation?.status === 'reserved' || reservation?.status === 'running'
      if (transitioned && reservation) {
        reservation.status = 'committed'
        await this.appendLedger('commit', { requestId: body.requestId, amount: reservation.amount })
      }
      if (transitioned && body.speechTicket) {
        const ticket: SpeechTicketState = {
          ticketId: body.speechTicket.ticketId,
          responseRequestId: body.requestId,
          textHash: body.speechTicket.textHash,
          expiresAt: body.speechTicket.expiresAt,
          state: 'unused',
        }
        state.speechTickets[ticket.ticketId] = ticket
      }
      await this.save(state)
      return Response.json({ committed: true, credits: this.creditState(state) })
    }

    if (request.method === 'POST' && path === '/credits/release') {
      const { requestId } = await jsonRequest<{ requestId: string }>(request)
      const reservation = state.creditReservations[requestId]
      if (reservation?.status === 'reserved' || reservation?.status === 'running') {
        reservation.status = 'released'
        state.credits.balance = Math.min(state.credits.capacity, state.credits.balance + reservation.amount)
        await this.appendLedger('release', { requestId, amount: reservation.amount, balance: state.credits.balance })
      }
      await this.save(state)
      return Response.json({ released: true, credits: this.creditState(state) })
    }

    if (request.method === 'GET' && path === '/consent') {
      return Response.json(state.consent)
    }

    if (request.method === 'PUT' && path === '/consent') {
      const { expectedRevision, grants } = await jsonRequest<{
        expectedRevision: number
        grants: EvaConsentPolicy['grants']
      }>(request)
      if (expectedRevision !== state.consent.revision) {
        return Response.json({ message: 'Consent revision conflict.', consent: state.consent }, { status: 409 })
      }
      state.consent = {
        schemaVersion: 2,
        revision: state.consent.revision + 1,
        grants: [...new Set(grants)].sort() as EvaConsentPolicy['grants'],
        updatedAt: new Date().toISOString(),
      }
      await this.save(state)
      return Response.json(state.consent)
    }

    if (request.method === 'POST' && path === '/cost/reserve') {
      const { requestId, globalRequestId, estimatedMicroUsd } = await jsonRequest<{
        requestId: string
        globalRequestId: string
        estimatedMicroUsd: number
      }>(request)
      const fuse = Number(this.env.ACCOUNT_COST_FUSE_MICRO_USD)
      const existing = state.cost.reservations[requestId]
      if (existing) {
        return Response.json({
          allowed: false,
          replayed: true,
          status: existing.status,
        })
      }
      const reserved = Object.values(state.cost.reservations)
        .filter((value) => value.status === 'reserved' || value.status === 'running')
        .reduce((sum, value) => sum + value.amountMicroUsd, 0)
      if (this.rollingCost(state) + reserved + estimatedMicroUsd > fuse) {
        return Response.json({ allowed: false, fuse })
      }
      const now = Date.now()
      state.cost.reservations[requestId] = {
        requestId,
        globalRequestId,
        amountMicroUsd: estimatedMicroUsd,
        createdAt: now,
        expiresAt: now + reservationLifetimeMilliseconds,
        status: 'reserved',
      }
      await this.save(state)
      await this.scheduleReconciliation(state)
      return Response.json({ allowed: true })
    }

    if (request.method === 'POST' && path === '/cost/commit') {
      const { requestId, actualMicroUsd } = await jsonRequest<{ requestId: string; actualMicroUsd: number }>(request)
      const reservation = state.cost.reservations[requestId]
      if (!reservation) return Response.json({ message: 'Cost reservation is missing.' }, { status: 409 })
      if (reservation.status === 'committed') {
        return Response.json({ committed: true, alreadyCommitted: true, actualMicroUsd: reservation.actualMicroUsd })
      }
      if (reservation.status !== 'reserved' && reservation.status !== 'running') {
        return Response.json({ message: 'Cost reservation is no longer active.' }, { status: 409 })
      }
      const actual = Math.max(0, actualMicroUsd)
      if (actual > reservation.amountMicroUsd) {
        return Response.json({ message: 'Actual cost exceeds the hard reservation cap.' }, { status: 409 })
      }
      reservation.status = 'committed'
      reservation.actualMicroUsd = actual
      reservation.globalSettled = false
      reservation.expiresAt = Date.now() + reservationLifetimeMilliseconds
      const bucket = String(Math.floor(Date.now() / hourMilliseconds))
      state.cost.hourlyCommittedMicroUsd[bucket] = (state.cost.hourlyCommittedMicroUsd[bucket] ?? 0) + actual
      await this.save(state)
      await this.scheduleReconciliation(state)
      return Response.json({ committed: true, actualMicroUsd: actual, rolling24HourMicroUsd: this.rollingCost(state) })
    }

    if (request.method === 'POST' && path === '/cost/global-settled') {
      const { requestId } = await jsonRequest<{ requestId: string }>(request)
      const reservation = state.cost.reservations[requestId]
      if (reservation?.status === 'committed') reservation.globalSettled = true
      await this.save(state)
      return Response.json({ settled: reservation?.globalSettled === true })
    }

    if (request.method === 'POST' && path === '/cost/release') {
      const { requestId } = await jsonRequest<{ requestId: string }>(request)
      const reservation = state.cost.reservations[requestId]
      if (reservation?.status === 'reserved' || reservation?.status === 'running') reservation.status = 'released'
      await this.save(state)
      return Response.json({ released: reservation?.status === 'released' })
    }

    if (request.method === 'POST' && path === '/speech/claim') {
      const body = await jsonRequest<{
        ticketId: string
        textHash: string
        allowPaidRegeneration: boolean
        paidReservationId: string
      }>(request)
      const ticket = state.speechTickets[body.ticketId]
      if (!ticket || ticket.expiresAt <= Date.now() || ticket.textHash !== body.textHash) {
        return Response.json({ message: 'Speech ticket is invalid or expired.' }, { status: 409 })
      }
      if (ticket.state === 'generating') {
        return Response.json({ message: 'Speech is already being generated.' }, { status: 409 })
      }
      if (ticket.state === 'unused') {
        ticket.state = 'generating'
        ticket.generationExpiresAt = Date.now() + reservationLifetimeMilliseconds
        await this.save(state)
        await this.scheduleReconciliation(state)
        return Response.json({ claimed: true, included: true })
      }
      if (!body.allowPaidRegeneration) {
        return Response.json({ claimed: false, requiresCredit: true, credits: this.creditState(state) })
      }
      this.applyRefill(state)
      if (state.credits.balance < 1) {
        return Response.json({ claimed: false, requiresCredit: true, credits: this.creditState(state) })
      }
      if (state.creditReservations[body.paidReservationId]) {
        return Response.json({ message: 'The paid regeneration request ID has already been used.' }, { status: 409 })
      }
      state.credits.balance -= 1
      const now = Date.now()
      state.creditReservations[body.paidReservationId] = {
        requestId: body.paidReservationId,
        amount: 1,
        createdAt: now,
        expiresAt: now + reservationLifetimeMilliseconds,
        status: 'reserved',
      }
      ticket.state = 'generating'
      ticket.generationExpiresAt = now + reservationLifetimeMilliseconds
      ticket.paidReservationId = body.paidReservationId
      await this.appendLedger('reserve', { requestId: body.paidReservationId, amount: 1, purpose: 'speech_regeneration' })
      await this.save(state)
      await this.scheduleReconciliation(state)
      return Response.json({ claimed: true, included: false, credits: this.creditState(state) })
    }

    if (request.method === 'POST' && path === '/speech/complete') {
      const { ticketId } = await jsonRequest<{ ticketId: string }>(request)
      const ticket = state.speechTickets[ticketId]
      if (ticket) {
        ticket.state = 'consumed'
        ticket.generationExpiresAt = undefined
        if (ticket.paidReservationId) {
          const reservation = state.creditReservations[ticket.paidReservationId]
          if (reservation?.status === 'reserved' || reservation?.status === 'running') {
            reservation.status = 'committed'
            await this.appendLedger('commit', { requestId: ticket.paidReservationId, amount: 1 })
          }
          ticket.paidReservationId = undefined
        }
      }
      await this.save(state)
      return Response.json({ completed: true, credits: this.creditState(state) })
    }

    if (request.method === 'POST' && path === '/speech/fail') {
      const { ticketId } = await jsonRequest<{ ticketId: string }>(request)
      const ticket = state.speechTickets[ticketId]
      if (ticket?.state === 'generating') {
        ticket.state = ticket.paidReservationId ? 'consumed' : 'unused'
        ticket.generationExpiresAt = undefined
        if (ticket.paidReservationId) {
          const reservation = state.creditReservations[ticket.paidReservationId]
          if (reservation?.status === 'reserved' || reservation?.status === 'running') {
            reservation.status = 'released'
            state.credits.balance = Math.min(state.credits.capacity, state.credits.balance + 1)
            await this.appendLedger('release', { requestId: ticket.paidReservationId, amount: 1 })
          }
          ticket.paidReservationId = undefined
        }
      }
      await this.save(state)
      return Response.json({ released: true, credits: this.creditState(state) })
    }

    if (request.method === 'DELETE' && path === '/account') {
      for (const family of Object.values(state.refreshFamilies)) family.revokedAt = Date.now()
      state.status = 'deleted'
      state.encryptedAppleRefreshToken = undefined
      await this.save(state)
      await this.ctx.storage.deleteAll()
      return Response.json({ deleted: true })
    }

    return Response.json({ message: 'Not found.' }, { status: 404 })
  }
}
