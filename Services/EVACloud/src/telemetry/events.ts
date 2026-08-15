import type { Env } from '../environment.js'

export interface EvaTelemetryEvent {
  event: string
  requestId: string
  accountId?: string
  route?: string
  status?: string
  durationMs?: number
  ttftMs?: number
  inputTokens?: number
  outputTokens?: number
  cachedInputTokens?: number
  cacheWriteTokens?: number
  reasoningTokens?: number
  actualMicroUsd?: number
}

export function recordTelemetry(env: Env, event: EvaTelemetryEvent): void {
  env.EVA_ANALYTICS.writeDataPoint({
    blobs: [
      event.event,
      event.requestId,
      event.accountId ?? '',
      event.route ?? '',
      event.status ?? '',
      env.ENVIRONMENT,
    ],
    doubles: [
      event.durationMs ?? 0,
      event.ttftMs ?? 0,
      event.inputTokens ?? 0,
      event.outputTokens ?? 0,
      event.cachedInputTokens ?? 0,
      event.cacheWriteTokens ?? 0,
      event.reasoningTokens ?? 0,
      event.actualMicroUsd ?? 0,
    ],
    indexes: [event.accountId ?? event.requestId],
  })
}
