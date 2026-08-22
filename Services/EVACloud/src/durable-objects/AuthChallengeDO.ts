import { DurableObject } from 'cloudflare:workers'
import type { Env } from '../environment.js'
import { decryptString, randomToken, sha256 } from '../security/crypto.js'
import { revokeAppleRefreshToken } from '../auth/apple.js'
import type { EvaAccountState } from './account-model.js'

interface ChallengeState {
  purpose: string
  nonceHash: string
  expiresAt: number
  consumedAt?: number
}

interface LinkLockState {
  linkId: string
  expiresAt: number
}

interface PendingGuestLinkState {
  mergeId: string
  sourceAccountId: string
  targetAccountId: string
  sourceBootstrapId?: string
  createdAt: number
  retryAt: number
  attempts: number
}

interface PendingAppleRevocationState {
  encryptedRefreshToken: string
  clientId: string
  createdAt: number
  retryAt: number
  attempts: number
}

const pendingLinkRetryDelay = (attempts: number): number => (
  Math.min(3_600, 5 * (2 ** Math.min(Math.max(attempts - 1, 0), 10))) * 1_000
)

export class AuthChallengeDO extends DurableObject<Env> {
  async fetch(request: Request): Promise<Response> {
    const path = new URL(request.url).pathname
    if (request.method === 'POST' && path === '/mark-once') {
      const existing = await this.ctx.storage.get<boolean>('consumed-event')
      if (existing) return Response.json({ message: 'Event was already consumed.' }, { status: 409 })
      await this.ctx.storage.put('consumed-event', true)
      return Response.json({ consumed: true })
    }
    if (request.method === 'POST' && path === '/guest-account') {
      const existing = await this.ctx.storage.get<string>('guest-account-id')
      if (existing) return Response.json({ accountId: existing, created: false })
      // Generated inside the server-owned Durable Object and persisted before
      // returning, so retries reuse one identity without deriving it from an
      // IP address, installation UUID, or other device identifier.
      const accountId = `guest_${randomToken()}`
      await this.ctx.storage.put('guest-account-id', accountId)
      return Response.json({ accountId, created: true })
    }
    if (request.method === 'DELETE' && path === '/guest-account') {
      await this.ctx.storage.delete('guest-account-id')
      return Response.json({ deleted: true })
    }
    if (request.method === 'POST' && path === '/link-lock/acquire') {
      const { linkId, ttlSeconds = 120 } = await request.json<{ linkId: string; ttlSeconds?: number }>()
      const existing = await this.ctx.storage.get<LinkLockState>('link-lock')
      if (existing && existing.expiresAt > Date.now() && existing.linkId !== linkId) {
        return Response.json({ message: 'This Apple account is already being linked.' }, { status: 409 })
      }
      const lock: LinkLockState = {
        linkId,
        expiresAt: Date.now() + Math.min(Math.max(ttlSeconds, 30), 300) * 1_000,
      }
      await this.ctx.storage.put('link-lock', lock)
      await this.scheduleAlarm()
      return Response.json({ acquired: true })
    }
    if (request.method === 'POST' && path === '/link-lock/release') {
      const { linkId } = await request.json<{ linkId: string }>()
      const existing = await this.ctx.storage.get<LinkLockState>('link-lock')
      if (existing?.linkId === linkId) await this.ctx.storage.delete('link-lock')
      await this.scheduleAlarm()
      return Response.json({ released: existing?.linkId === linkId })
    }
    if (request.method === 'POST' && path === '/link-pending') {
      const body = await request.json<{
        mergeId: string
        sourceAccountId: string
        targetAccountId: string
      }>()
      const existing = await this.ctx.storage.get<PendingGuestLinkState>('pending-guest-link')
      if (existing && (
        existing.mergeId !== body.mergeId
        || existing.sourceAccountId !== body.sourceAccountId
        || existing.targetAccountId !== body.targetAccountId
      )) {
        return Response.json({ message: 'A different guest merge is already pending.' }, { status: 409 })
      }
      const pending: PendingGuestLinkState = existing ?? {
        ...body,
        createdAt: Date.now(),
        retryAt: Date.now() + 1_000,
        attempts: 0,
      }
      await this.ctx.storage.put('pending-guest-link', pending)
      await this.scheduleAlarm()
      return Response.json({ scheduled: true })
    }
    if (request.method === 'GET' && path === '/link-pending') {
      return Response.json({ pending: await this.ctx.storage.get<PendingGuestLinkState>('pending-guest-link') ?? null })
    }
    if (request.method === 'POST' && path === '/apple-revocation') {
      const body = await request.json<{ encryptedRefreshToken: string; clientId: string }>()
      const existing = await this.ctx.storage.get<PendingAppleRevocationState>('pending-apple-revocation')
      const pending: PendingAppleRevocationState = existing ?? {
        ...body,
        createdAt: Date.now(),
        retryAt: Date.now() + 1_000,
        attempts: 0,
      }
      await this.ctx.storage.put('pending-apple-revocation', pending)
      await this.scheduleAlarm()
      return Response.json({ scheduled: true })
    }
    if (request.method === 'GET' && path === '/apple-revocation') {
      const pending = await this.ctx.storage.get<PendingAppleRevocationState>('pending-apple-revocation')
      return Response.json({ pending: pending ? { createdAt: pending.createdAt, attempts: pending.attempts } : null })
    }
    if (request.method === 'POST' && path === '/apple-revocation/reconcile') {
      try {
        await this.reconcileAppleRevocation()
        await this.scheduleAlarm()
        return Response.json({ reconciled: true })
      } catch {
        const pending = await this.ctx.storage.get<PendingAppleRevocationState>('pending-apple-revocation')
        if (pending) {
          pending.attempts = (pending.attempts ?? 0) + 1
          pending.retryAt = Date.now() + pendingLinkRetryDelay(pending.attempts)
          await this.ctx.storage.put('pending-apple-revocation', pending)
        }
        await this.scheduleAlarm()
        return Response.json({ message: 'Apple credential revocation is pending.' }, { status: 503 })
      }
    }
    if (request.method === 'POST' && path === '/link-pending/reconcile') {
      try {
        const merged = await this.reconcilePendingGuestLink()
        await this.scheduleAlarm()
        return Response.json({ reconciled: true, ...merged })
      } catch {
        const pending = await this.ctx.storage.get<PendingGuestLinkState>('pending-guest-link')
        if (pending) {
          pending.attempts = (pending.attempts ?? 0) + 1
          pending.retryAt = Date.now() + pendingLinkRetryDelay(pending.attempts)
          await this.ctx.storage.put('pending-guest-link', pending)
        }
        await this.scheduleAlarm()
        return Response.json({ message: 'The guest merge is pending reconciliation.' }, { status: 503 })
      }
    }
    if (request.method === 'POST' && path === '/issue') {
      const { purpose, ttlSeconds = 300 } = await request.json<{ purpose: string; ttlSeconds?: number }>()
      const nonce = randomToken()
      const state: ChallengeState = {
        purpose,
        nonceHash: await sha256(nonce),
        expiresAt: Date.now() + Math.min(Math.max(ttlSeconds, 30), 600) * 1_000,
      }
      await this.ctx.storage.put('challenge', state)
      await this.scheduleAlarm()
      return Response.json({ nonce, expiresAt: new Date(state.expiresAt).toISOString() })
    }
    if (request.method === 'POST' && path === '/consume') {
      const { purpose, nonce } = await request.json<{ purpose: string; nonce: string }>()
      const state = await this.ctx.storage.get<ChallengeState>('challenge')
      const valid = state
        && !state.consumedAt
        && state.expiresAt > Date.now()
        && state.purpose === purpose
        && state.nonceHash === await sha256(nonce)
      if (!valid || !state) return Response.json({ message: 'Challenge is invalid or expired.' }, { status: 409 })
      state.consumedAt = Date.now()
      await this.ctx.storage.put('challenge', state)
      return Response.json({ consumed: true })
    }
    return Response.json({ message: 'Not found.' }, { status: 404 })
  }

  async alarm(): Promise<void> {
    const now = Date.now()
    const challenge = await this.ctx.storage.get<ChallengeState>('challenge')
    if (challenge && challenge.expiresAt <= now) await this.ctx.storage.delete('challenge')
    const lock = await this.ctx.storage.get<LinkLockState>('link-lock')
    if (lock && lock.expiresAt <= now) await this.ctx.storage.delete('link-lock')
    const pending = await this.ctx.storage.get<PendingGuestLinkState>('pending-guest-link')
    if (pending && pending.retryAt <= now) {
      try {
        await this.reconcilePendingGuestLink()
      } catch {
        const current = await this.ctx.storage.get<PendingGuestLinkState>('pending-guest-link')
        if (current) {
          current.attempts = (current.attempts ?? 0) + 1
          current.retryAt = Date.now() + pendingLinkRetryDelay(current.attempts)
          await this.ctx.storage.put('pending-guest-link', current)
        }
      }
    }
    const revocation = await this.ctx.storage.get<PendingAppleRevocationState>('pending-apple-revocation')
    if (revocation && revocation.retryAt <= now) {
      try {
        await this.reconcileAppleRevocation()
      } catch {
        const current = await this.ctx.storage.get<PendingAppleRevocationState>('pending-apple-revocation')
        if (current) {
          current.attempts = (current.attempts ?? 0) + 1
          current.retryAt = Date.now() + pendingLinkRetryDelay(current.attempts)
          await this.ctx.storage.put('pending-apple-revocation', current)
        }
      }
    }
    await this.scheduleAlarm()
  }

  private async reconcilePendingGuestLink(): Promise<{ quota?: unknown; credits?: unknown; consent?: unknown }> {
    const pending = await this.ctx.storage.get<PendingGuestLinkState>('pending-guest-link')
    if (!pending) return {}
    const source = this.env.EVA_ACCOUNTS.get(this.env.EVA_ACCOUNTS.idFromName(pending.sourceAccountId))
    const frozen = await source.fetch('https://durable.internal/merge/freeze-export', {
      method: 'POST', body: JSON.stringify({ targetAccountId: pending.targetAccountId }),
    })
    if (frozen.status === 404) {
      await this.deleteGuestMapping(pending.sourceBootstrapId)
      await this.ctx.storage.delete('pending-guest-link')
      return {}
    }
    if (!frozen.ok) throw new Error('Guest account could not be frozen for merge.')
    const exported = await frozen.json<{ state: EvaAccountState }>()
    pending.sourceBootstrapId = exported.state.guestBootstrapId ?? pending.sourceBootstrapId
    await this.ctx.storage.put('pending-guest-link', pending)

    const target = this.env.EVA_ACCOUNTS.get(this.env.EVA_ACCOUNTS.idFromName(pending.targetAccountId))
    const imported = await target.fetch('https://durable.internal/merge/import', {
      method: 'POST', body: JSON.stringify({ mergeId: pending.mergeId, source: exported.state }),
    })
    if (!imported.ok) throw new Error('Canonical account could not import the guest account.')
    const merged = await imported.json<{ quota?: unknown; credits?: unknown; consent?: unknown }>()
    const deleted = await source.fetch('https://durable.internal/account', { method: 'DELETE' })
    if (!deleted.ok && deleted.status !== 404) throw new Error('Guest account could not be tombstoned.')
    await this.deleteGuestMapping(pending.sourceBootstrapId)
    await this.ctx.storage.delete('pending-guest-link')
    return { quota: merged.quota, credits: merged.credits, consent: merged.consent }
  }

  private async deleteGuestMapping(bootstrapId?: string): Promise<void> {
    if (!bootstrapId) return
    const mapping = this.env.AUTH_CHALLENGES.get(this.env.AUTH_CHALLENGES.idFromName(bootstrapId.toLowerCase()))
    const response = await mapping.fetch('https://durable.internal/guest-account', { method: 'DELETE' })
    if (!response.ok) throw new Error('Guest mapping could not be deleted.')
  }

  private async reconcileAppleRevocation(): Promise<void> {
    const pending = await this.ctx.storage.get<PendingAppleRevocationState>('pending-apple-revocation')
    if (!pending) return
    const refreshToken = await decryptString(this.env.TOKEN_ENCRYPTION_KEY, pending.encryptedRefreshToken)
    await revokeAppleRefreshToken(this.env, refreshToken, pending.clientId)
    await this.ctx.storage.delete('pending-apple-revocation')
  }

  private async scheduleAlarm(): Promise<void> {
    const now = Date.now()
    const [challenge, lock, pending, revocation] = await Promise.all([
      this.ctx.storage.get<ChallengeState>('challenge'),
      this.ctx.storage.get<LinkLockState>('link-lock'),
      this.ctx.storage.get<PendingGuestLinkState>('pending-guest-link'),
      this.ctx.storage.get<PendingAppleRevocationState>('pending-apple-revocation'),
    ])
    const next = [challenge?.expiresAt, lock?.expiresAt, pending?.retryAt, revocation?.retryAt]
      .filter((value): value is number => value !== undefined)
      .map((value) => Math.max(value, now + 1_000))
      .sort((left, right) => left - right)[0]
    if (next === undefined) await this.ctx.storage.deleteAlarm()
    else await this.ctx.storage.setAlarm(next)
  }
}
