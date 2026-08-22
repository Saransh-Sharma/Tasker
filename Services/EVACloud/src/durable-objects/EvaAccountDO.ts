import { DurableObject } from 'cloudflare:workers'
import type { EvaConsentPolicy, EvaCreditState, EvaQuotaStateV1 } from '@lifeboard/eva-contracts'
import type { Env } from '../environment.js'
import type {
  AccountAuthorization,
  CostReservation,
  EvaAccountState,
  EvaDeviceState,
  SpeechTicketState,
  QuotaReservation,
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
    state.identityKind ??= 'apple'
    state.creditReservations ??= {}
    state.attestationChallenges ??= {}
    state.quota ??= {
      limit: 20,
      helperLimit: 100,
      windowMs: dayMilliseconds,
      reservations: {},
    }
    for (const reservation of Object.values(state.creditReservations ?? {})) {
      reservation.expiresAt ??= reservation.createdAt + reservationLifetimeMilliseconds
    }
    for (const device of Object.values(state.devices)) {
      device.trustTier = device.attestationKeyId || device.catalystRisk ? 'high' : 'low'
    }
    this.pruneEphemeralState(state)
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

  private pruneQuota(state: EvaAccountState, now = Date.now()): void {
    for (const [requestId, reservation] of Object.entries(state.quota.reservations)) {
      if (reservation.status === 'committed' && (reservation.committedAt ?? reservation.createdAt) <= now - state.quota.windowMs) {
        delete state.quota.reservations[requestId]
      } else if ((reservation.status === 'released' || reservation.status === 'expired') && reservation.createdAt <= now - state.quota.windowMs) {
        delete state.quota.reservations[requestId]
      }
    }
  }

  private pruneEphemeralState(state: EvaAccountState, now = Date.now()): void {
    this.pruneQuota(state, now)
    for (const [requestId, reservation] of Object.entries(state.creditReservations)) {
      if (
        reservation.expiresAt <= now
        && reservation.status !== 'reserved'
        && reservation.status !== 'running'
      ) delete state.creditReservations[requestId]
    }
    for (const [requestId, reservation] of Object.entries(state.cost.reservations)) {
      const terminal = reservation.status === 'released'
        || reservation.status === 'expired'
        || (reservation.status === 'committed' && reservation.globalSettled === true)
      if (terminal && reservation.createdAt <= now - dayMilliseconds) delete state.cost.reservations[requestId]
    }
    for (const [ticketId, ticket] of Object.entries(state.speechTickets)) {
      if (ticket.expiresAt <= now && ticket.state !== 'generating') delete state.speechTickets[ticketId]
    }
    for (const [familyId, family] of Object.entries(state.refreshFamilies)) {
      if (family.expiresAt <= now) delete state.refreshFamilies[familyId]
    }
    for (const [challenge, value] of Object.entries(state.attestationChallenges)) {
      if (value.expiresAt <= now) delete state.attestationChallenges[challenge]
    }
    this.rollingCost(state, now)
  }

  private quotaState(state: EvaAccountState, kind: QuotaReservation['kind'] = 'billable', now = Date.now()): EvaQuotaStateV1 {
    this.pruneQuota(state, now)
    const limit = kind === 'billable' ? state.quota.limit : state.quota.helperLimit
    const active = Object.values(state.quota.reservations).filter((reservation) =>
      reservation.kind === kind && (
        reservation.status === 'reserved'
        || reservation.status === 'running'
        || (reservation.status === 'committed' && (reservation.committedAt ?? reservation.createdAt) > now - state.quota.windowMs)
      ))
    const committed = active
      .filter((reservation) => reservation.status === 'committed')
      .map((reservation) => (reservation.committedAt ?? reservation.createdAt) + state.quota.windowMs)
      .sort((left, right) => left - right)
    const next = active.length > 0
      ? Math.min(...[
        ...committed,
        ...active.filter((reservation) => reservation.status === 'reserved' || reservation.status === 'running')
          .map((reservation) => reservation.expiresAt),
      ])
      : undefined
    return {
      limit,
      used: Math.min(active.length, limit),
      remaining: Math.max(0, limit - active.length),
      windowSeconds: Math.floor(state.quota.windowMs / 1_000),
      nextAvailableAt: next === undefined ? null : new Date(next).toISOString(),
    }
  }

  private creditState(state: EvaAccountState): EvaCreditState {
    const quota = this.quotaState(state)
    return {
      balance: quota.remaining,
      capacity: quota.limit,
      refillAmount: 1,
      nextRefillAt: quota.nextAvailableAt ?? new Date(Date.now() + state.quota.windowMs).toISOString(),
    }
  }

  private reserveQuota(state: EvaAccountState, requestId: string, kind: QuotaReservation['kind']): {
    reserved: boolean
    status: string
    quota: EvaQuotaStateV1
  } {
    this.pruneQuota(state)
    const existing = state.quota.reservations[requestId]
    if (existing) return { reserved: false, status: existing.status, quota: this.quotaState(state, kind) }
    const quota = this.quotaState(state, kind)
    if (quota.remaining <= 0) return { reserved: false, status: 'exhausted', quota }
    const now = Date.now()
    state.quota.reservations[requestId] = {
      requestId,
      kind,
      createdAt: now,
      expiresAt: now + reservationLifetimeMilliseconds,
      status: 'reserved',
    }
    return { reserved: true, status: 'reserved', quota: this.quotaState(state, kind) }
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
      ...Object.values(state.quota.reservations)
        .filter((value) => value.status === 'reserved' || value.status === 'running')
        .map((value) => value.expiresAt),
      ...Object.values(state.creditReservations)
        .filter((value) => value.status === 'reserved' || value.status === 'running')
        .map((value) => value.expiresAt),
      ...Object.values(state.cost.reservations)
        .filter((value) => value.status === 'reserved' || value.status === 'running' || (value.status === 'committed' && !value.globalSettled))
        .map((value) => value.expiresAt),
      ...Object.values(state.speechTickets)
        .filter((value) => value.state === 'generating' && value.generationExpiresAt)
        .map((value) => value.generationExpiresAt as number),
      ...Object.values(state.attestationChallenges).map((value) => value.expiresAt),
    ]
    if (expiries.length > 0) await this.ctx.storage.setAlarm(Math.min(...expiries))
  }

  async alarm(): Promise<void> {
    const state = await this.load()
    if (!state) return
    const now = Date.now()
    const globalReleases: string[] = []
    const globalCommits: Array<{ requestId: string; actualMicroUsd: number; reservation: CostReservation }> = []
    for (const reservation of Object.values(state.quota.reservations)) {
      if ((reservation.status === 'reserved' || reservation.status === 'running') && reservation.expiresAt <= now) {
        reservation.status = 'expired'
        await this.appendLedger('quota_release', {
          requestId: reservation.requestId,
          kind: reservation.kind,
          reason: 'reservation_expired',
        })
      }
    }
    for (const [challenge, value] of Object.entries(state.attestationChallenges)) {
      if (value.expiresAt <= now) delete state.attestationChallenges[challenge]
    }
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
        const reservation = state.quota.reservations[ticket.paidReservationId]
        if (reservation && (reservation.status === 'reserved' || reservation.status === 'running')) {
          reservation.status = 'expired'
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
        identityKind?: 'guest' | 'apple'
        guestBootstrapId?: string
        grants?: EvaConsentPolicy['grants']
        quotaPolicy?: { billableLimit: number; helperLimit: number; rollingWindowSeconds: number }
        encryptedAppleRefreshToken?: string
        appleClientId?: string
        familyId: string
        refreshTokenHash: string
        refreshGeneration?: number
        installationId: string
        platform: 'ios' | 'catalyst'
        catalystRisk?: EvaDeviceState['catalystRisk']
        deviceCheckRisk?: EvaDeviceState['deviceCheckRisk']
        authenticatedAt: number
        refreshExpiresAt: number
      }>(request)
      let state = await this.load()
      const isNew = !state
      if (!state) {
        const now = Date.now()
        state = {
          accountId: body.accountId,
          status: 'active',
          createdAt: now,
          identityKind: body.identityKind ?? 'apple',
          guestBootstrapId: body.guestBootstrapId,
          encryptedAppleRefreshToken: body.encryptedAppleRefreshToken,
          appleClientId: body.appleClientId,
          credits: {
            balance: 20,
            capacity: 20,
            refillAmount: 1,
            refillPeriodMs: dayMilliseconds,
            refillAnchor: now,
          },
          quota: {
            limit: body.quotaPolicy?.billableLimit ?? 20,
            helperLimit: body.quotaPolicy?.helperLimit ?? 100,
            windowMs: (body.quotaPolicy?.rollingWindowSeconds ?? 86_400) * 1_000,
            reservations: {},
          },
          consent: {
            schemaVersion: 2,
            revision: body.grants === undefined ? 0 : 1,
            grants: [...new Set(body.grants ?? [])].sort() as EvaConsentPolicy['grants'],
            updatedAt: new Date(now).toISOString(),
          },
          devices: {},
          attestationChallenges: {},
          refreshFamilies: {},
          creditReservations: {},
          speechTickets: {},
          cost: { hourlyCommittedMicroUsd: {}, reservations: {} },
        }
        await this.appendLedger('quota_initialized', { limit: 20, helperLimit: 100 })
      }
      if (state.status === 'deleted') return Response.json({ message: 'Account was deleted.' }, { status: 410 })
      if (state.mergeFrozenForAccountId) {
        return Response.json({ message: 'Guest account linking is already in progress.' }, { status: 409 })
      }
      state.encryptedAppleRefreshToken = body.encryptedAppleRefreshToken ?? state.encryptedAppleRefreshToken
      state.appleClientId = body.appleClientId ?? state.appleClientId
      if (body.identityKind === 'apple') state.identityKind = 'apple'
      const existingDevice = state.devices[body.installationId]
      if (existingDevice && existingDevice.platform !== body.platform) {
        return Response.json({ message: 'Device platform binding cannot change.' }, { status: 409 })
      }
      state.devices[body.installationId] ??= {
        installationId: body.installationId,
        platform: body.platform,
        createdAt: Date.now(),
        trustTier: body.catalystRisk ? 'high' : 'low',
      }
      const device = state.devices[body.installationId]
      if (!device) return Response.json({ message: 'Device registration failed.' }, { status: 500 })
      if (body.platform === 'catalyst') {
        device.catalystRisk = body.catalystRisk
        device.trustTier = body.catalystRisk ? 'high' : 'low'
      }
      if (body.deviceCheckRisk) device.deviceCheckRisk = body.deviceCheckRisk
      const familyCreatedAt = Date.now()
      for (const [existingFamilyId, family] of Object.entries(state.refreshFamilies)) {
        if (
          existingFamilyId !== body.familyId
          && family.installationId === body.installationId
          && !family.revokedAt
        ) family.revokedAt = familyCreatedAt
      }
      state.refreshFamilies[body.familyId] = {
        familyId: body.familyId,
        currentTokenHash: body.refreshTokenHash,
        currentGeneration: body.refreshGeneration,
        usedTokenHashes: [],
        installationId: body.installationId,
        authenticatedAt: body.authenticatedAt,
        expiresAt: body.refreshExpiresAt,
        identityKind: state.identityKind,
      }
      const activeFamilies = Object.values(state.refreshFamilies)
        .filter((family) => !family.revokedAt && family.expiresAt > familyCreatedAt)
        .sort((left, right) => right.authenticatedAt - left.authenticatedAt)
      for (const family of activeFamilies.slice(20)) family.revokedAt = familyCreatedAt
      await this.save(state)
      return Response.json({
        created: isNew,
        identityKind: state.identityKind,
        trustTier: device.trustTier ?? 'low',
        quota: this.quotaState(state),
        credits: this.creditState(state),
        consent: state.consent,
      })
    }

    const state = await this.load()
    if (!state || state.status === 'deleted') {
      return Response.json({ message: 'Account is unavailable.' }, { status: 404 })
    }
    if (
      state.mergeFrozenForAccountId
      && path !== '/merge/freeze-export'
      && path !== '/merge/export'
      && path !== '/authorize'
      && path !== '/refresh/rotate'
      && path !== '/session/revoke'
      && !(request.method === 'DELETE' && path === '/account')
    ) {
      return Response.json({ message: 'Guest account linking is already in progress.' }, { status: 409 })
    }

    if (request.method === 'POST' && path === '/refresh/rotate') {
      const body = await jsonRequest<{
        familyId: string
        presentedTokenHash: string
        presentedGeneration?: number
        replacementTokenHash: string
        replacementGeneration: number
        replacementExpiresAt: number
        installationId: string
        platform: 'ios' | 'catalyst'
      }>(request)
      const family = state.refreshFamilies[body.familyId]
      if (state.mergeFrozenForAccountId) {
        return Response.json({ message: 'Guest account linking is already in progress.' }, { status: 401 })
      }
      const device = family ? state.devices[family.installationId] : undefined
      if (
        !family
        || family.revokedAt
        || family.expiresAt <= Date.now()
        || family.installationId !== body.installationId
        || device?.platform !== body.platform
      ) {
        return Response.json({ message: 'Refresh session is invalid.' }, { status: 401 })
      }
      const generationReplay = family.currentGeneration !== undefined
        && body.presentedGeneration !== undefined
        && body.presentedGeneration < family.currentGeneration
      if (family.usedTokenHashes.includes(body.presentedTokenHash) || generationReplay) {
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
      // Legacy unversioned tokens need one retained hash. Versioned tokens use
      // their monotonic generation, avoiding unbounded per-family state.
      if (family.currentGeneration === undefined) {
        family.usedTokenHashes.push(family.currentTokenHash)
        family.usedTokenHashes = [...new Set(family.usedTokenHashes)].slice(-32)
      }
      family.currentTokenHash = body.replacementTokenHash
      family.currentGeneration = body.replacementGeneration
      family.expiresAt = body.replacementExpiresAt
      await this.save(state)
      return Response.json({
        rotated: true,
        family,
        platform: device.platform,
      })
    }

    if (request.method === 'POST' && path === '/session/revoke') {
      const { familyId } = await jsonRequest<{ familyId: string }>(request)
      const family = state.refreshFamilies[familyId]
      if (family) family.revokedAt = Date.now()
      await this.save(state)
      return Response.json({ revoked: true })
    }

    if (request.method === 'POST' && path === '/session/reauthenticate') {
      const body = await jsonRequest<{
        familyId: string
        installationId: string
        authenticatedAt: number
        encryptedAppleRefreshToken?: string
        appleClientId: string
      }>(request)
      const family = state.refreshFamilies[body.familyId]
      if (
        state.identityKind !== 'apple'
        || !family
        || family.revokedAt
        || family.expiresAt <= Date.now()
        || family.installationId !== body.installationId
      ) {
        return Response.json({ message: 'The Apple session is no longer active.' }, { status: 401 })
      }
      family.authenticatedAt = body.authenticatedAt
      family.identityKind = 'apple'
      state.appleClientId = body.appleClientId
      state.encryptedAppleRefreshToken = body.encryptedAppleRefreshToken ?? state.encryptedAppleRefreshToken
      await this.save(state)
      return Response.json({ reauthenticated: true })
    }

    if (request.method === 'POST' && path === '/apple/revoke') {
      for (const family of Object.values(state.refreshFamilies)) family.revokedAt = Date.now()
      state.encryptedAppleRefreshToken = undefined
      await this.save(state)
      return Response.json({ revoked: true })
    }

    if (request.method === 'GET' && path === '/merge/export') {
      return Response.json({ state })
    }

    if (request.method === 'POST' && path === '/merge/freeze-export') {
      const { targetAccountId } = await jsonRequest<{ targetAccountId: string }>(request)
      if (state.identityKind !== 'guest') {
        return Response.json({ message: 'Only a guest account can be merged.' }, { status: 409 })
      }
      if (state.mergeFrozenForAccountId && state.mergeFrozenForAccountId !== targetAccountId) {
        return Response.json({ message: 'Guest account is already reserved for another merge.' }, { status: 409 })
      }
      const hasActiveWork = Object.values(state.quota.reservations).some((value) =>
        value.status === 'reserved' || value.status === 'running')
        || Object.values(state.creditReservations).some((value) =>
          value.status === 'reserved' || value.status === 'running')
        || Object.values(state.cost.reservations).some((value) =>
          value.status === 'reserved' || value.status === 'running')
        || Object.values(state.speechTickets).some((value) => value.state === 'generating')
      if (hasActiveWork) {
        return Response.json({ message: 'Guest requests must settle before linking.' }, { status: 409 })
      }
      state.mergeFrozenForAccountId = targetAccountId
      for (const family of Object.values(state.refreshFamilies)) family.revokedAt = Date.now()
      await this.save(state)
      return Response.json({ state })
    }

    if (request.method === 'POST' && path === '/merge/import') {
      const body = await jsonRequest<{ mergeId: string; source: EvaAccountState }>(request)
      state.completedMergeIds ??= []
      if (state.completedMergeIds.includes(body.mergeId)) {
        return Response.json({
          merged: true,
          alreadyMerged: true,
          consent: state.consent,
          quota: this.quotaState(state),
          credits: this.creditState(state),
        })
      }
      const source = body.source
      const grants = state.consent.grants.filter((grant) => source.consent.grants.includes(grant))
      state.consent = {
        schemaVersion: 2,
        revision: Math.max(state.consent.revision, source.consent.revision) + 1,
        grants,
        reviewRequired: true,
        updatedAt: new Date().toISOString(),
      }
      for (const [requestId, reservation] of Object.entries(source.quota?.reservations ?? {})) {
        const existing = state.quota.reservations[requestId]
        if (!existing) {
          state.quota.reservations[requestId] = reservation
          continue
        }
        // Request IDs are client-generated and therefore cannot be trusted as
        // a cross-account set key. Preserve both successful answers on a
        // collision so linking can never manufacture allowance.
        let mergedRequestId = `merged:${source.accountId}:${requestId}`
        let collision = 1
        while (state.quota.reservations[mergedRequestId]) {
          mergedRequestId = `merged:${source.accountId}:${collision}:${requestId}`
          collision += 1
        }
        state.quota.reservations[mergedRequestId] = { ...reservation, requestId: mergedRequestId }
      }
      for (const [installationId, sourceDevice] of Object.entries(source.devices)) {
        const existing = state.devices[installationId]
        if (!existing) {
          state.devices[installationId] = sourceDevice
          continue
        }
        const selectedKeyId = existing.attestationKeyId ?? sourceDevice.attestationKeyId
        const sameKey = existing.attestationKeyId !== undefined
          && existing.attestationKeyId === sourceDevice.attestationKeyId
        const selectedCounter = sameKey
          ? Math.max(existing.attestationCounter ?? 0, sourceDevice.attestationCounter ?? 0)
          : existing.attestationKeyId
            ? existing.attestationCounter ?? 0
            : sourceDevice.attestationCounter ?? 0
        state.devices[installationId] = {
          ...sourceDevice,
          ...existing,
          attestationKeyId: selectedKeyId,
          attestationPublicKey: existing.attestationKeyId
            ? existing.attestationPublicKey
            : sourceDevice.attestationPublicKey,
          attestationCounter: selectedCounter,
          catalystRisk: existing.catalystRisk ?? sourceDevice.catalystRisk,
          deviceCheckRisk: existing.deviceCheckRisk ?? sourceDevice.deviceCheckRisk,
          trustTier: selectedKeyId || existing.catalystRisk || sourceDevice.catalystRisk ? 'high' : 'low',
        }
      }
      for (const [bucket, amount] of Object.entries(source.cost.hourlyCommittedMicroUsd ?? {})) {
        state.cost.hourlyCommittedMicroUsd[bucket] = (state.cost.hourlyCommittedMicroUsd[bucket] ?? 0) + amount
      }
      for (const [requestId, reservation] of Object.entries(source.cost.reservations ?? {})) {
        if (reservation.status !== 'committed' || reservation.globalSettled === true) continue
        let mergedRequestId = requestId
        if (state.cost.reservations[mergedRequestId]) {
          mergedRequestId = `merged:${source.accountId}:${requestId}`
        }
        state.cost.reservations[mergedRequestId] = { ...reservation, requestId: mergedRequestId }
      }
      state.speechTickets = { ...source.speechTickets, ...state.speechTickets }
      state.completedMergeIds.push(body.mergeId)
      state.completedMergeIds = state.completedMergeIds.slice(-16)
      this.pruneQuota(state)
      this.rollingCost(state)
      await this.appendLedger('guest_merged', { mergeId: body.mergeId, sourceAccountId: source.accountId })
      await this.save(state)
      await this.scheduleReconciliation(state)
      return Response.json({
        merged: true,
        consent: state.consent,
        quota: this.quotaState(state),
        credits: this.creditState(state),
      })
    }

    if (request.method === 'GET' && path === '/apple/credential') {
      return Response.json({
        encryptedRefreshToken: state.encryptedAppleRefreshToken,
        clientId: state.appleClientId,
        guestBootstrapId: state.guestBootstrapId,
      })
    }

    if (request.method === 'POST' && path === '/authorize') {
      const body = await jsonRequest<{
        familyId: string
        installationId: string
        platform: 'ios' | 'catalyst'
        requireAdult: boolean
        requireAttestation: boolean
        allowAgeManagement?: boolean
      }>(request)
      const family = state.refreshFamilies[body.familyId]
      const device = state.devices[body.installationId]
      const now = Date.now()
      let result: AccountAuthorization
      if (
        state.mergeFrozenForAccountId
        || !family
        || family.revokedAt
        || family.expiresAt <= now
        || family.installationId !== body.installationId
      ) {
        result = { authorized: false, reason: 'session' }
      } else if (!device || device.platform !== body.platform) {
        result = { authorized: false, reason: 'attestation' }
      } else if (!body.allowAgeManagement && device.ageLowerBound !== undefined && device.ageLowerBound < 13) {
        result = { authorized: false, reason: 'age' }
      } else if (body.requireAdult && (
        !device.adultEligibleExpiresAt
        || device.adultEligibleExpiresAt <= now
      )) {
        result = { authorized: false, reason: 'age' }
      } else {
        result = {
          authorized: true,
          credits: this.creditState(state),
          quota: this.quotaState(state),
          consent: state.consent,
          identityKind: state.identityKind,
          trustTier: device.attestationKeyId || device.catalystRisk ? 'high' : 'low',
        }
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

    if (request.method === 'POST' && path === '/quota/configure') {
      const body = await jsonRequest<{ billableLimit: number; helperLimit: number; rollingWindowSeconds: number }>(request)
      state.quota.limit = Math.min(Math.max(body.billableLimit, 1), 100)
      state.quota.helperLimit = Math.min(Math.max(body.helperLimit, 1), 1_000)
      state.quota.windowMs = Math.min(Math.max(body.rollingWindowSeconds, 3_600), 604_800) * 1_000
      this.pruneQuota(state)
      await this.save(state)
      return Response.json({ configured: true, quota: this.quotaState(state) })
    }

    if (request.method === 'POST' && path === '/device/age') {
      const body = await jsonRequest<{
        installationId: string
        platform: 'ios' | 'catalyst'
        eligibleAdult: boolean
        lowerBound?: number
        policyRequired?: boolean
        declaration: string
      }>(request)
      const device: EvaDeviceState = state.devices[body.installationId] ?? {
        installationId: body.installationId,
        platform: body.platform,
        createdAt: Date.now(),
      }
      device.platform = body.platform
      device.ageDeclaration = body.declaration
      device.ageLowerBound = body.lowerBound
      device.agePolicyRequired = body.policyRequired ?? false
      device.adultEligibleAt = body.eligibleAdult ? Date.now() : undefined
      device.adultEligibleExpiresAt = body.eligibleAdult ? Date.now() + 24 * 60 * 60 * 1_000 : undefined
      state.devices[body.installationId] = device
      await this.save(state)
      return Response.json({
        eligibleAdult: body.lowerBound === undefined ? body.policyRequired !== true : body.lowerBound >= 13,
        expiresAt: device.adultEligibleExpiresAt ? new Date(device.adultEligibleExpiresAt).toISOString() : undefined,
      })
    }

    if (request.method === 'POST' && path === '/device/risk') {
      const body = await jsonRequest<{
        installationId: string
        deviceCheckRisk: NonNullable<EvaDeviceState['deviceCheckRisk']>
      }>(request)
      const device = state.devices[body.installationId]
      if (!device) return Response.json({ message: 'The installation is not registered.' }, { status: 409 })
      device.deviceCheckRisk = body.deviceCheckRisk
      await this.save(state)
      return Response.json({ recorded: true })
    }

    if (request.method === 'POST' && path === '/device/attestation/challenge') {
      const { installationId } = await jsonRequest<{ installationId: string }>(request)
      const challenge = crypto.randomUUID()
      state.attestationChallenges[challenge] = {
        installationId,
        expiresAt: Date.now() + 5 * 60 * 1_000,
      }
      await this.save(state)
      await this.scheduleReconciliation(state)
      return Response.json({ challenge })
    }

    if (request.method === 'POST' && path === '/device/attestation/register') {
      const body = await jsonRequest<{
        installationId: string
        keyId: string
        publicKey: string
        challenge: string
      }>(request)
      const challengeState = state.attestationChallenges[body.challenge]
      if (
        !challengeState
        || challengeState.expiresAt <= Date.now()
        || challengeState.installationId !== body.installationId
      ) {
        return Response.json({ message: 'Attestation challenge is invalid.' }, { status: 409 })
      }
      const device = state.devices[body.installationId]
      if (!device || device.platform !== 'ios') {
        return Response.json({ message: 'The iOS installation is not registered.' }, { status: 409 })
      }
      device.attestationKeyId = body.keyId
      device.attestationPublicKey = body.publicKey
      device.attestationCounter = 0
      device.trustTier = 'high'
      delete state.attestationChallenges[body.challenge]
      await this.save(state)
      return Response.json({ registered: true })
    }

    if (request.method === 'POST' && path === '/device/assertion/material') {
      const body = await jsonRequest<{ installationId: string; challenge: string }>(request)
      const challengeState = state.attestationChallenges[body.challenge]
      const device = state.devices[body.installationId]
      if (
        !challengeState
        || challengeState.expiresAt <= Date.now()
        || challengeState.installationId !== body.installationId
        || !device?.attestationKeyId
        || !device.attestationPublicKey
      ) {
        return Response.json({ message: 'Assertion challenge is invalid.' }, { status: 409 })
      }
      delete state.attestationChallenges[body.challenge]
      await this.save(state)
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

    if (request.method === 'GET' && path === '/quota') {
      const quota = this.quotaState(state)
      await this.save(state)
      return Response.json(quota)
    }

    if (request.method === 'POST' && (path === '/quota/reserve' || path === '/credits/reserve')) {
      const { requestId, kind = 'billable' } = await jsonRequest<{
        requestId: string
        kind?: QuotaReservation['kind']
      }>(request)
      const reservation = this.reserveQuota(state, requestId, kind)
      if (reservation.reserved) {
        await this.appendLedger('quota_reserve', { requestId, kind })
      }
      await this.save(state)
      await this.scheduleReconciliation(state)
      return Response.json({ ...reservation, credits: this.creditState(state) })
    }

    if (request.method === 'POST' && path === '/request/running') {
      const { requestId } = await jsonRequest<{ requestId: string }>(request)
      const expiresAt = Date.now() + reservationLifetimeMilliseconds
      const credit = state.creditReservations[requestId]
      const quota = state.quota.reservations[requestId]
      const cost = state.cost.reservations[requestId]
      if (quota?.status === 'reserved') quota.status = 'running'
      if (credit?.status === 'reserved') credit.status = 'running'
      if (cost?.status === 'reserved') cost.status = 'running'
      if (quota?.status === 'running') quota.expiresAt = expiresAt
      if (credit?.status === 'running') credit.expiresAt = expiresAt
      if (cost?.status === 'running') cost.expiresAt = expiresAt
      await this.save(state)
      await this.scheduleReconciliation(state)
      return Response.json({ running: Boolean(quota || credit || cost) })
    }

    if (request.method === 'POST' && (path === '/quota/commit' || path === '/credits/commit')) {
      const body = await jsonRequest<{
        requestId: string
        speechTicket?: { ticketId: string; textHash: string; expiresAt: number }
      }>(request)
      const reservation = state.quota.reservations[body.requestId]
      const transitioned = reservation?.status === 'reserved' || reservation?.status === 'running'
      if (transitioned && reservation) {
        reservation.status = 'committed'
        reservation.committedAt = Date.now()
        await this.appendLedger('quota_commit', { requestId: body.requestId, kind: reservation.kind })
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
      return Response.json({ committed: true, quota: this.quotaState(state), credits: this.creditState(state) })
    }

    if (request.method === 'POST' && (path === '/quota/release' || path === '/credits/release')) {
      const { requestId } = await jsonRequest<{ requestId: string }>(request)
      const reservation = state.quota.reservations[requestId]
      if (reservation?.status === 'reserved' || reservation?.status === 'running') {
        reservation.status = 'released'
        await this.appendLedger('quota_release', { requestId, kind: reservation.kind })
      }
      await this.save(state)
      return Response.json({ released: true, quota: this.quotaState(state), credits: this.creditState(state) })
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
        reviewRequired: false,
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
        return Response.json({ claimed: false, requiresCredit: true, quota: this.quotaState(state, 'helper'), credits: this.creditState(state) })
      }
      if (state.quota.reservations[body.paidReservationId]) {
        return Response.json({ message: 'The paid regeneration request ID has already been used.' }, { status: 409 })
      }
      const helperReservation = this.reserveQuota(state, body.paidReservationId, 'helper')
      if (!helperReservation.reserved) {
        return Response.json({ claimed: false, requiresCredit: true, quota: helperReservation.quota, credits: this.creditState(state) })
      }
      const now = Date.now()
      ticket.state = 'generating'
      ticket.generationExpiresAt = now + reservationLifetimeMilliseconds
      ticket.paidReservationId = body.paidReservationId
      await this.appendLedger('quota_reserve', { requestId: body.paidReservationId, kind: 'helper', purpose: 'speech_regeneration' })
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
          const reservation = state.quota.reservations[ticket.paidReservationId]
          if (reservation?.status === 'reserved' || reservation?.status === 'running') {
            reservation.status = 'committed'
            reservation.committedAt = Date.now()
            await this.appendLedger('quota_commit', { requestId: ticket.paidReservationId, kind: 'helper' })
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
          const reservation = state.quota.reservations[ticket.paidReservationId]
          if (reservation?.status === 'reserved' || reservation?.status === 'running') {
            reservation.status = 'released'
            await this.appendLedger('quota_release', { requestId: ticket.paidReservationId, kind: 'helper' })
          }
          ticket.paidReservationId = undefined
        }
      }
      await this.save(state)
      return Response.json({ released: true, credits: this.creditState(state) })
    }

    if (request.method === 'DELETE' && path === '/account') {
      const guestBootstrapId = state.guestBootstrapId
      for (const family of Object.values(state.refreshFamilies)) family.revokedAt = Date.now()
      state.status = 'deleted'
      state.encryptedAppleRefreshToken = undefined
      await this.save(state)
      await this.ctx.storage.deleteAll()
      return Response.json({ deleted: true, guestBootstrapId })
    }

    return Response.json({ message: 'Not found.' }, { status: 404 })
  }
}
