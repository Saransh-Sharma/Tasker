import { DurableObject } from 'cloudflare:workers'
import type { Env } from '../environment.js'
import { recordTelemetry } from '../telemetry/events.js'

const reservationLifetimeMilliseconds = 5 * 60 * 1_000

interface GlobalReservation {
  requestId: string
  amountMicroUsd: number
  actualMicroUsd?: number
  createdAt: number
  expiresAt: number
  status: 'reserved' | 'running' | 'committed' | 'released' | 'expired'
}

interface BudgetState {
  day: string
  committedMicroUsd: number
  reservations: Record<string, GlobalReservation>
  emittedThresholds: number[]
  closed: boolean
}

function currentDay(): string {
  return new Date().toISOString().slice(0, 10)
}

export class GlobalBudgetDO extends DurableObject<Env> {
  private async state(): Promise<BudgetState> {
    const day = currentDay()
    const stored = await this.ctx.storage.get<BudgetState & { reservations: Record<string, GlobalReservation | number> }>('state')
    if (!stored || stored.day !== day) {
      const fresh: BudgetState = {
        day,
        committedMicroUsd: 0,
        reservations: {},
        emittedThresholds: [],
        closed: false,
      }
      await this.ctx.storage.put('state', fresh)
      return fresh
    }
    stored.emittedThresholds ??= []
    for (const [requestId, reservation] of Object.entries(stored.reservations)) {
      if (typeof reservation === 'number') {
        const now = Date.now()
        stored.reservations[requestId] = {
          requestId,
          amountMicroUsd: reservation,
          createdAt: now,
          expiresAt: now + reservationLifetimeMilliseconds,
          status: 'reserved',
        }
      }
    }
    return stored as BudgetState
  }

  private async schedule(state: BudgetState): Promise<void> {
    const expiries = Object.values(state.reservations)
      .filter((value) => value.status === 'reserved' || value.status === 'running')
      .map((value) => value.expiresAt)
    if (expiries.length > 0) await this.ctx.storage.setAlarm(Math.min(...expiries))
  }

  async alarm(): Promise<void> {
    const state = await this.state()
    const now = Date.now()
    for (const reservation of Object.values(state.reservations)) {
      if ((reservation.status === 'reserved' || reservation.status === 'running') && reservation.expiresAt <= now) {
        reservation.status = 'expired'
        recordTelemetry(this.env, {
          event: 'budget.reservation.expired',
          requestId: reservation.requestId,
          actualMicroUsd: reservation.amountMicroUsd,
        })
      }
    }
    await this.ctx.storage.put('state', state)
    await this.schedule(state)
  }

  async fetch(request: Request): Promise<Response> {
    const path = new URL(request.url).pathname
    const state = await this.state()
    const limit = Number(this.env.DAILY_BUDGET_MICRO_USD)

    if (request.method === 'POST' && path === '/reserve') {
      const { requestId, estimatedMicroUsd } = await request.json<{ requestId: string; estimatedMicroUsd: number }>()
      const existing = state.reservations[requestId]
      if (existing) {
        return Response.json({
          allowed: false,
          replayed: true,
          status: existing.status,
        })
      }
      const reserved = Object.values(state.reservations)
        .filter((value) => value.status === 'reserved' || value.status === 'running')
        .reduce((sum, value) => sum + value.amountMicroUsd, 0)
      if (state.closed || state.committedMicroUsd + reserved + estimatedMicroUsd > limit) {
        return Response.json({ allowed: false, committedMicroUsd: state.committedMicroUsd, limit })
      }
      const now = Date.now()
      state.reservations[requestId] = {
        requestId,
        amountMicroUsd: estimatedMicroUsd,
        createdAt: now,
        expiresAt: now + reservationLifetimeMilliseconds,
        status: 'reserved',
      }
      await this.ctx.storage.put('state', state)
      await this.schedule(state)
      recordTelemetry(this.env, { event: 'budget.reserved', requestId, actualMicroUsd: estimatedMicroUsd })
      return Response.json({ allowed: true })
    }

    if (request.method === 'POST' && path === '/running') {
      const { requestId } = await request.json<{ requestId: string }>()
      const reservation = state.reservations[requestId]
      if (reservation?.status === 'reserved') reservation.status = 'running'
      if (reservation?.status === 'running') {
        reservation.expiresAt = Date.now() + reservationLifetimeMilliseconds
      }
      await this.ctx.storage.put('state', state)
      await this.schedule(state)
      return Response.json({ running: reservation?.status === 'running' })
    }

    if (request.method === 'POST' && path === '/commit') {
      const { requestId, actualMicroUsd } = await request.json<{ requestId: string; actualMicroUsd: number }>()
      const reservation = state.reservations[requestId]
      if (!reservation) return Response.json({ message: 'Budget reservation is missing.' }, { status: 409 })
      if (reservation.status === 'committed') {
        return Response.json({ committed: true, alreadyCommitted: true, committedMicroUsd: state.committedMicroUsd, limit })
      }
      if (reservation.status !== 'reserved' && reservation.status !== 'running') {
        return Response.json({ message: 'Budget reservation is no longer active.' }, { status: 409 })
      }
      const actual = Math.max(0, actualMicroUsd)
      if (actual > reservation.amountMicroUsd) {
        return Response.json({ message: 'Actual cost exceeds the hard reservation cap.' }, { status: 409 })
      }
      reservation.status = 'committed'
      reservation.actualMicroUsd = actual
      state.committedMicroUsd += actual
      if (state.committedMicroUsd >= limit) state.closed = true
      const percent = limit > 0 ? state.committedMicroUsd / limit * 100 : 100
      for (const threshold of [50, 75, 90]) {
        if (percent >= threshold && !state.emittedThresholds.includes(threshold)) {
          state.emittedThresholds.push(threshold)
          recordTelemetry(this.env, {
            event: 'budget.threshold', requestId, status: String(threshold), actualMicroUsd: state.committedMicroUsd,
          })
        }
      }
      await this.ctx.storage.put('state', state)
      recordTelemetry(this.env, { event: 'budget.committed', requestId, actualMicroUsd: actual })
      return Response.json({ committed: true, committedMicroUsd: state.committedMicroUsd, limit })
    }

    if (request.method === 'POST' && path === '/release') {
      const { requestId } = await request.json<{ requestId: string }>()
      const reservation = state.reservations[requestId]
      if (reservation?.status === 'reserved' || reservation?.status === 'running') reservation.status = 'released'
      await this.ctx.storage.put('state', state)
      recordTelemetry(this.env, { event: 'budget.released', requestId })
      return Response.json({ released: reservation?.status === 'released' })
    }

    if (request.method === 'GET' && path === '/status') {
      return Response.json({ ...state, limit })
    }

    return Response.json({ message: 'Not found.' }, { status: 404 })
  }
}
