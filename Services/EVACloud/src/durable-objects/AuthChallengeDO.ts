import { DurableObject } from 'cloudflare:workers'
import type { Env } from '../environment.js'
import { randomToken, sha256 } from '../security/crypto.js'

interface ChallengeState {
  purpose: string
  nonceHash: string
  expiresAt: number
  consumedAt?: number
}

export class AuthChallengeDO extends DurableObject<Env> {
  async fetch(request: Request): Promise<Response> {
    const path = new URL(request.url).pathname
    if (request.method === 'POST' && path === '/mark-once') {
      const existing = await this.ctx.storage.get<boolean>('consumed-event')
      if (existing) return Response.json({ message: 'Event was already consumed.' }, { status: 409 })
      await this.ctx.storage.put('consumed-event', true)
      return Response.json({ consumed: true })
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
      await this.ctx.storage.setAlarm(state.expiresAt)
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
    await this.ctx.storage.deleteAll()
  }
}
