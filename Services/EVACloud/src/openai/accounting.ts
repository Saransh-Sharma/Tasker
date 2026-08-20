import type { Env } from '../environment.js'
import type { EvaRuntimeConfig } from '../config/runtime-config.js'
import { accountStub } from '../durable-objects/account-client.js'
import { durableJson, durableObjectStub } from '../durable-objects/helpers.js'
import { hmacSha256 } from '../security/crypto.js'
import { recordTelemetry } from '../telemetry/events.js'

export interface UsageBreakdown {
  inputTokens: number
  cachedInputTokens: number
  cacheWriteTokens: number
  outputTokens: number
  reasoningTokens: number
}

type PriceSchedule = EvaRuntimeConfig['priceSchedule']

function perMillion(units: number, microUsdPerMillion: number): number {
  return units * microUsdPerMillion / 1_000_000
}

/** Reserves the worst permitted attempt graph, never a best-case cache outcome. */
export function estimatedLunaCostMicroUsd(
  inputCap: number,
  outputCap: number,
  prices: PriceSchedule,
  maximumAttempts: number,
): number {
  const worstInputPrice = Math.max(
    prices.lunaInputMicroUsdPerMillion,
    prices.lunaCacheWriteMicroUsdPerMillion,
  )
  const oneAttempt = perMillion(inputCap, worstInputPrice)
    + perMillion(outputCap, prices.lunaOutputMicroUsdPerMillion)
    + perMillion(inputCap + outputCap, prices.moderationMicroUsdPerMillion)
  return Math.ceil(oneAttempt * maximumAttempts)
}

export function actualLunaCostMicroUsd(usage: UsageBreakdown, prices: PriceSchedule): number {
  const uncached = Math.max(0, usage.inputTokens - usage.cachedInputTokens - usage.cacheWriteTokens)
  return Math.ceil(
    perMillion(uncached, prices.lunaInputMicroUsdPerMillion)
    + perMillion(usage.cachedInputTokens, prices.lunaCachedInputMicroUsdPerMillion)
    + perMillion(usage.cacheWriteTokens, prices.lunaCacheWriteMicroUsdPerMillion)
    + perMillion(usage.outputTokens, prices.lunaOutputMicroUsdPerMillion),
  )
}

export function speechCostMicroUsd(characterCount: number, prices: PriceSchedule): number {
  return Math.ceil(perMillion(characterCount, prices.ttsMicroUsdPerMillionCharacters))
}

function budgetStub(env: Env): DurableObjectStub {
  return durableObjectStub(env.GLOBAL_BUDGET, 'production-global-v1')
}

async function globalRequestId(env: Env, accountId: string, requestId: string): Promise<string> {
  return hmacSha256(env.ACCOUNT_HMAC_KEY, `${accountId}:${requestId}`)
}

export async function reserveCost(
  env: Env,
  accountId: string,
  requestId: string,
  estimatedMicroUsd: number,
): Promise<'reserved' | 'replayed' | 'budget_exhausted'> {
  const globalId = await globalRequestId(env, accountId, requestId)
  const account = await durableJson<{ allowed: boolean; replayed?: boolean }>(accountStub(env, accountId), '/cost/reserve', {
    method: 'POST', body: JSON.stringify({ requestId, globalRequestId: globalId, estimatedMicroUsd }),
  })
  if (!account.allowed) return account.replayed ? 'replayed' : 'budget_exhausted'
  const global = await durableJson<{ allowed: boolean; replayed?: boolean }>(budgetStub(env), '/reserve', {
    method: 'POST', body: JSON.stringify({ requestId: globalId, estimatedMicroUsd }),
  })
  if (global.allowed) {
    recordTelemetry(env, { event: 'cost.reserved', requestId, accountId, actualMicroUsd: estimatedMicroUsd })
    return 'reserved'
  }
  await releaseCost(env, accountId, requestId)
  return global.replayed ? 'replayed' : 'budget_exhausted'
}

export async function markRequestRunning(env: Env, accountId: string, requestId: string): Promise<void> {
  const globalId = await globalRequestId(env, accountId, requestId)
  await Promise.all([
    durableJson(accountStub(env, accountId), '/request/running', {
      method: 'POST', body: JSON.stringify({ requestId }),
    }),
    durableJson(budgetStub(env), '/running', {
      method: 'POST', body: JSON.stringify({ requestId: globalId }),
    }),
  ])
}

export async function commitCost(
  env: Env,
  accountId: string,
  requestId: string,
  actualMicroUsd: number,
): Promise<void> {
  const globalId = await globalRequestId(env, accountId, requestId)
  await durableJson(accountStub(env, accountId), '/cost/commit', {
    method: 'POST', body: JSON.stringify({ requestId, actualMicroUsd }),
  })
  try {
    await durableJson(budgetStub(env), '/commit', {
      method: 'POST', body: JSON.stringify({ requestId: globalId, actualMicroUsd }),
    })
    await durableJson(accountStub(env, accountId), '/cost/global-settled', {
      method: 'POST', body: JSON.stringify({ requestId }),
    })
  } catch {
    // EvaAccountDO persists a content-free outbox entry and retries from its alarm.
  }
  recordTelemetry(env, { event: 'cost.committed', requestId, accountId, actualMicroUsd })
}

export async function releaseCost(env: Env, accountId: string, requestId: string): Promise<void> {
  const globalId = await globalRequestId(env, accountId, requestId)
  await Promise.allSettled([
    durableJson(accountStub(env, accountId), '/cost/release', {
      method: 'POST', body: JSON.stringify({ requestId }),
    }),
    durableJson(budgetStub(env), '/release', {
      method: 'POST', body: JSON.stringify({ requestId: globalId }),
    }),
  ])
  recordTelemetry(env, { event: 'cost.released', requestId, accountId })
}
