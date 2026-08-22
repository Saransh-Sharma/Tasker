import { Hono } from 'hono'
import type { EvaCreditState, EvaInferenceRequestV1, EvaQuotaStateV1, EvaStreamEvent } from '@lifeboard/eva-contracts'
import {
  EvaInferenceRequestSchema,
  contextPayloadError,
  semanticValidationError,
  sensitiveContextCategories,
  structuredSchemaForRoute,
} from '@lifeboard/eva-contracts'
import { Value } from '@sinclair/typebox/value'
import type { Responses } from 'openai/resources/responses/responses'
import type { AppVariables, Env, SessionPrincipal } from '../environment.js'
import { requireSession } from '../auth/middleware.js'
import { issueSpeechTicket } from '../auth/speech-ticket.js'
import { verifyRequestAttestation } from '../attestation/app-attest.js'
import { accountStub, authorizeAccount } from '../durable-objects/account-client.js'
import { durableJson } from '../durable-objects/helpers.js'
import { readJson } from '../http/body.js'
import { EvaHttpError } from '../http/errors.js'
import {
  actualLunaCostMicroUsd,
  estimatedLunaCostMicroUsd,
  releaseCost,
  reserveCost,
  type UsageBreakdown,
  commitCost,
  markRequestRunning,
} from '../openai/accounting.js'
import { openAIClient } from '../openai/client.js'
import { modelInput, structuredTextFormat } from '../openai/prompts.js'
import { moderateText, supportiveSafetyResponse } from '../safety/moderation.js'
import { requiresAgeDecision, runtimeConfig, type EvaRoutePolicy, type EvaRuntimeConfig } from '../config/runtime-config.js'
import { sha256 } from '../security/crypto.js'
import { recordTelemetry } from '../telemetry/events.js'

const encoder = new TextEncoder()

export const responseRoutes = new Hono<{ Bindings: Env; Variables: AppVariables }>()
responseRoutes.use('*', requireSession)

responseRoutes.post('/responses', async (context) => {
  const startedAt = Date.now()
  const principal = context.get('principal')
  if (principal.platform === 'ios' && context.req.header('X-EVA-Attest-Assertion')) {
    await verifyRequestAttestation(context.env, principal, context.req.raw)
  }
  const request = await readJson<EvaInferenceRequestV1>(context.req.raw, EvaInferenceRequestSchema)
  validatePrincipal(request, principal)
  const payloadError = contextPayloadError(request.contractVersion, request.context, request.turnContext)
  if (payloadError) throw new EvaHttpError(400, 'schema_invalid', payloadError)

  const config = await runtimeConfig(context.env)
  if (config.cloudState === 'disabled') {
    throw new EvaHttpError(503, 'configuration_unavailable', 'Cloud EVA is temporarily unavailable.', {
      recoveryAction: 'tryOffline',
    })
  }
  if (principal.identityKind === 'guest' && !config.guestAccess?.inferenceEnabled) {
    throw new EvaHttpError(503, 'configuration_unavailable', 'Guest Cloud EVA is temporarily unavailable.', {
      recoveryAction: 'tryOffline',
    })
  }
  if (compareVersions(request.clientVersion, config.minimumClientVersion) < 0) {
    throw new EvaHttpError(426, 'client_upgrade_required', 'Update LifeBoard to use Cloud EVA.', {
      recoveryAction: 'upgrade',
    })
  }
  const policy = config.routes[request.route]
  if (!policy || !policy.enabled) {
    throw new EvaHttpError(503, 'configuration_unavailable', 'This Cloud EVA capability is temporarily unavailable.', {
      recoveryAction: 'tryOffline',
    })
  }
  enforceInputBudget(request, policy)
  if (config.usagePolicy) {
    await durableJson(accountStub(context.env, principal.accountId), '/quota/configure', {
      method: 'POST', body: JSON.stringify(config.usagePolicy),
    })
  }
  const authorization = await authorizeAccount(context.env, principal, {
    requireAdult: requiresAgeDecision(config),
  })
  if (!authorization.authorized) throw authorizationError(authorization.reason)
  if (!authorization.consent || authorization.consent.revision !== request.consentRevision) {
    throw new EvaHttpError(409, 'consent_revision_conflict', 'Cloud context consent changed. Review it and try again.', {
      recoveryAction: 'reviewConsent',
    })
  }
  if (authorization.consent.reviewRequired === true) {
    throw new EvaHttpError(409, 'consent_required', 'Review Cloud EVA context again after protecting this account.', {
      recoveryAction: 'reviewConsent',
    })
  }
  for (const section of request.context) {
    if (sensitiveContextCategories.has(section.category) && !authorization.consent.grants.includes(section.category as never)) {
      throw new EvaHttpError(403, 'consent_required', `Permission to share ${section.category} context is off.`, {
        recoveryAction: 'reviewConsent',
      })
    }
  }

  const client = openAIClient(context.env)
  const inputText = JSON.stringify(modelInput(request))
  const inputDecision = await moderateText(client, inputText)
  if (!inputDecision.allowed) {
    recordTelemetry(context.env, {
      event: 'model.input_rejected', requestId: request.requestId, accountId: principal.accountId,
      route: request.route, status: inputDecision.selfHarm ? 'self_harm' : 'moderation',
    })
    if (inputDecision.selfHarm) {
      return sseResponse(eventsForSafeResponse(request.requestId, supportiveSafetyResponse, authorization.credits))
    }
    throw new EvaHttpError(400, 'input_rejected', 'I can’t help with that request, but I can help with a safer alternative.')
  }

  const accountLimit = !policy.billable
    ? 10
    : principal.identityKind === 'guest'
      ? 10
      : principal.platform === 'catalyst' ? 15 : 30
  const rate = await durableJson<{ allowed: boolean; retryAfter?: number }>(
    accountStub(context.env, principal.accountId),
    '/rate/consume',
    { method: 'POST', body: JSON.stringify({ bucket: policy.billable ? 'billable' : 'internal', limit: accountLimit }) },
  )
  if (!rate.allowed) {
    throw new EvaHttpError(429, 'rate_limited', 'Cloud EVA is receiving too many requests.', {
      retryable: true, retryAfter: rate.retryAfter ?? 60, recoveryAction: 'wait',
    })
  }

  let quotaReserved = false
  let costReserved = false
  try {
    const reservation = await durableJson<{
      reserved: boolean
      status: string
      quota: EvaQuotaStateV1
      credits: EvaCreditState
    }>(accountStub(context.env, principal.accountId), '/quota/reserve', {
      method: 'POST',
      body: JSON.stringify({ requestId: request.requestId, kind: policy.billable ? 'billable' : 'helper' }),
    })
    if (!reservation.reserved) {
      if (reservation.status !== 'exhausted') {
        throw new EvaHttpError(409, 'request_replayed', 'This request ID has already been used. Start a new request to regenerate.', {
          credits: reservation.credits, quota: reservation.quota,
        })
      }
      const hours = Math.max(1, Math.round(reservation.quota.windowSeconds / 3_600))
      const message = policy.billable
        ? `You have used ${reservation.quota.limit} Cloud EVA answers in the last ${hours} hours.`
        : 'Cloud EVA background assistance has reached its current limit.'
      throw new EvaHttpError(429, 'daily_quota_exhausted', message, {
        credits: reservation.credits, quota: reservation.quota, recoveryAction: 'tryOffline',
      })
    }
    quotaReserved = true

    const estimate = estimatedLunaCostMicroUsd(
      policy.inputTokenCap,
      policy.outputTokenCap,
      config.priceSchedule,
      policy.structured ? 3 : 2,
    )
    const costReservation = await reserveCost(context.env, principal.accountId, request.requestId, estimate)
    if (costReservation === 'replayed') {
      throw new EvaHttpError(409, 'request_replayed', 'This request ID has already been used. Start a new request to regenerate.')
    }
    costReserved = costReservation === 'reserved'
    if (!costReserved) {
      throw new EvaHttpError(503, 'budget_exhausted', 'Cloud EVA has reached its current usage budget.', {
        recoveryAction: 'tryOffline',
      })
    }
    await markRequestRunning(context.env, principal.accountId, request.requestId)

    if (!policy.structured) {
      const response = streamingTextResponse({
        env: context.env,
        principal,
        request,
        policy,
        initialCredits: authorization.credits,
        initialQuota: authorization.quota,
        quotaReserved,
        clientSignal: context.req.raw.signal,
        priceSchedule: config.priceSchedule,
      })
      quotaReserved = false
      costReserved = false
      return response
    }

    const result = await generateResponse(context.env, principal, request, policy)
    if (!result.billableSuccess) {
      if (quotaReserved) await releaseQuota(context.env, principal.accountId, request.requestId)
      await releaseCost(context.env, principal.accountId, request.requestId)
      return sseResponse(eventsForSafeResponse(request.requestId, result.text, authorization.credits, authorization.quota))
    }

    const actualCost = actualLunaCostMicroUsd(result.usage, config.priceSchedule)
    recordModelCompletion(context.env, principal, request, result.usage, actualCost, startedAt, result.repaired ? 'repaired' : 'valid')
    await commitCost(context.env, principal.accountId, request.requestId, actualCost)
    costReserved = false
    let credits = authorization.credits
    let quota = authorization.quota
    let ticket: string | undefined
    if (quotaReserved) {
      const ticketId = policy.billable ? crypto.randomUUID() : undefined
      const textHash = ticketId ? await sha256(result.text) : undefined
      const expiresAt = ticketId ? Date.now() + 30 * 24 * 60 * 60 * 1_000 : undefined
      const commit = await durableJson<{ credits: EvaCreditState; quota: EvaQuotaStateV1 }>(accountStub(context.env, principal.accountId), '/quota/commit', {
        method: 'POST',
        body: JSON.stringify({
          requestId: request.requestId,
          ...(ticketId && textHash && expiresAt ? { speechTicket: { ticketId, textHash, expiresAt } } : {}),
        }),
      })
      quotaReserved = false
      credits = commit.credits
      quota = commit.quota
      if (ticketId && textHash && expiresAt) {
        ticket = await issueSpeechTicket(context.env, {
          accountId: principal.accountId,
          ticketId,
          responseRequestId: request.requestId,
          textHash,
          expiresAt,
        })
      }
    }
    return sseResponse(eventsForResult(request, result, credits, ticket, quota))
  } catch (error) {
    if (quotaReserved) await releaseQuota(context.env, principal.accountId, request.requestId)
    if (costReserved) await releaseCost(context.env, principal.accountId, request.requestId)
    recordTelemetry(context.env, {
      event: 'model.failed', requestId: request.requestId, accountId: principal.accountId, route: request.route,
      status: error instanceof EvaHttpError ? error.code : 'unexpected', durationMs: Date.now() - startedAt,
    })
    throw error
  }
})

interface GeneratedResult {
  text: string
  structured?: unknown
  usage: UsageBreakdown
  billableSuccess: boolean
  repaired: boolean
}

interface StreamingTextArguments {
  env: Env
  principal: SessionPrincipal
  request: EvaInferenceRequestV1
  policy: EvaRoutePolicy
  initialCredits: EvaCreditState | undefined
  initialQuota: EvaQuotaStateV1 | undefined
  quotaReserved: boolean
  clientSignal: AbortSignal
  priceSchedule: EvaRuntimeConfig['priceSchedule']
}

function streamingTextResponse(arguments_: StreamingTextArguments): Response {
  const { env, principal, request, policy, initialCredits, initialQuota, clientSignal, priceSchedule } = arguments_
  const client = openAIClient(env)
  const startedAt = Date.now()
  const abortController = new AbortController()
  let quotaActive = arguments_.quotaReserved
  let costActive = true
  let settled = false

  const cleanup = async (): Promise<void> => {
    if (settled) return
    settled = true
    if (quotaActive) await releaseQuota(env, principal.accountId, request.requestId)
    if (costActive) await releaseCost(env, principal.accountId, request.requestId)
    quotaActive = false
    costActive = false
  }

  clientSignal.addEventListener('abort', () => {
    abortController.abort()
    void cleanup()
  }, { once: true })

  const body = new ReadableStream<Uint8Array>({
    async start(controller) {
      let sequence = 0
      let visibleDeltaSent = false
      let pendingText = ''
      let fullText = ''
      let moderationCarry = ''
      let firstDeltaAt: number | undefined
      const enqueue = (event: EvaStreamEvent): void => {
        controller.enqueue(encoder.encode(`data: ${JSON.stringify(event)}\n\n`))
      }
      const flushModerated = async (force: boolean): Promise<void> => {
        const holdback = 48
        while (pendingText.length > (force ? 0 : holdback + 48)) {
          const target = force ? pendingText.length : pendingText.length - holdback
          const cut = force ? pendingText.length : safeSegmentBoundary(pendingText, target)
          const segment = pendingText.slice(0, cut)
          pendingText = pendingText.slice(cut)
          if (!segment) break
          // Keep approved overlap so unsafe meaning split across streaming
          // boundaries is still evaluated as one piece of language.
          const moderationWindow = moderationCarry + segment
          const decision = await moderateText(client, moderationWindow)
          if (!decision.allowed) {
            throw new EvaHttpError(422, 'output_rejected', 'I can’t provide that response, but I can help with a safer alternative.')
          }
          enqueue({
            type: 'response.text.delta',
            requestId: request.requestId,
            sequence: sequence++,
            delta: segment,
          })
          moderationCarry = moderationWindow.slice(-512)
          visibleDeltaSent = true
        }
      }

      enqueue({
        type: 'response.accepted', requestId: request.requestId, sequence: sequence++,
        credits: initialCredits, quota: initialQuota,
      })
      const timeout = setTimeout(() => abortController.abort(), 60_000)
      try {
        let completedResponse: Responses.Response | undefined
        for (let attempt = 0; attempt < 2; attempt += 1) {
          try {
            const stream = await client.responses.create({
              model: 'gpt-5.6-luna',
              input: modelInput(request),
              max_output_tokens: policy.outputTokenCap,
              reasoning: { context: 'current_turn', effort: policy.reasoning },
              safety_identifier: principal.accountId.slice(0, 64),
              store: false,
              stream: true,
              tools: [],
              prompt_cache_key: `eva:eva-cloud-v2:${request.route}:v${request.contractVersion}`,
              prompt_cache_options: { mode: 'explicit', ttl: '30m' },
            }, { signal: abortController.signal })
            for await (const event of stream) {
              if (event.type === 'response.output_text.delta') {
                firstDeltaAt ??= Date.now()
                fullText += event.delta
                pendingText += event.delta
                await flushModerated(false)
              } else if (event.type === 'response.completed') {
                completedResponse = event.response
              } else if (event.type === 'response.failed') {
                throw new Error('OpenAI response failed.')
              } else if (event.type === 'response.incomplete') {
                throw new Error('OpenAI response was incomplete.')
              } else if (event.type === 'response.refusal.delta' || event.type === 'response.refusal.done') {
                throw new EvaHttpError(422, 'output_rejected', 'Cloud EVA declined this request.')
              }
            }
            if (!completedResponse) throw new Error('OpenAI stream ended without completion.')
            ensureUsableResponse(completedResponse)
            break
          } catch (error) {
            if (attempt === 0 && !visibleDeltaSent && !abortController.signal.aborted && isTransientProviderError(error)) {
              pendingText = ''
              fullText = ''
              completedResponse = undefined
              continue
            }
            throw error
          }
        }

        const answer = fullText.trim()
        if (!answer || !completedResponse) {
          throw new EvaHttpError(422, 'output_rejected', 'Cloud EVA did not produce a usable answer.', { retryable: true })
        }
        await flushModerated(true)
        const usage = usageFrom(completedResponse)
        const actualCost = actualLunaCostMicroUsd(usage, priceSchedule)
        await commitCost(env, principal.accountId, request.requestId, actualCost)
        recordModelCompletion(env, principal, request, usage, actualCost, startedAt, 'valid', firstDeltaAt)
        costActive = false

        let credits = initialCredits
        let quota = initialQuota
        let ticket: string | undefined
        if (quotaActive) {
          const ticketId = policy.billable ? crypto.randomUUID() : undefined
          const textHash = ticketId ? await sha256(fullText) : undefined
          const expiresAt = ticketId ? Date.now() + 30 * 24 * 60 * 60 * 1_000 : undefined
          const commit = await durableJson<{ credits: EvaCreditState; quota: EvaQuotaStateV1 }>(accountStub(env, principal.accountId), '/quota/commit', {
            method: 'POST',
            body: JSON.stringify({
              requestId: request.requestId,
              ...(ticketId && textHash && expiresAt ? { speechTicket: { ticketId, textHash, expiresAt } } : {}),
            }),
          })
          quotaActive = false
          credits = commit.credits
          quota = commit.quota
          if (ticketId && textHash && expiresAt) {
            ticket = await issueSpeechTicket(env, {
              accountId: principal.accountId,
              ticketId,
              responseRequestId: request.requestId,
              textHash,
              expiresAt,
            })
          }
        }
        settled = true
        enqueue({
          type: 'response.usage',
          requestId: request.requestId,
          sequence: sequence++,
          inputTokens: usage.inputTokens,
          cachedInputTokens: usage.cachedInputTokens,
          cacheWriteTokens: usage.cacheWriteTokens,
          outputTokens: usage.outputTokens,
          reasoningTokens: usage.reasoningTokens,
        })
        enqueue({
          type: 'response.completed',
          requestId: request.requestId,
          sequence,
          ...(ticket ? { speechTicket: ticket } : {}),
          ...(credits ? { credits } : {}),
          ...(quota ? { quota } : {}),
        })
        controller.close()
      } catch (error) {
        await cleanup()
        if (clientSignal.aborted) {
          try { controller.close() } catch { /* client already disconnected */ }
          return
        }
        recordTelemetry(env, {
          event: 'model.failed', requestId: request.requestId, accountId: principal.accountId, route: request.route,
          status: error instanceof EvaHttpError ? error.code : 'unexpected', durationMs: Date.now() - startedAt,
        })
        const failure = error instanceof EvaHttpError
          ? error
          : new EvaHttpError(503, 'provider_unavailable', 'Cloud EVA could not finish the response.', {
            retryable: true, recoveryAction: 'tryOffline',
          })
        try {
          enqueue({
            type: 'response.failed',
            requestId: request.requestId,
            sequence,
            error: failure.envelope(request.requestId),
          })
          controller.close()
        } catch { /* client already disconnected */ }
      } finally {
        clearTimeout(timeout)
      }
    },
    cancel() {
      abortController.abort()
      void cleanup()
    },
  })
  return new Response(body, {
    headers: {
      'Content-Type': 'text/event-stream; charset=utf-8',
      'Cache-Control': 'no-store',
      'X-Accel-Buffering': 'no',
    },
  })
}

function safeSegmentBoundary(text: string, target: number): number {
  const bounded = text.slice(0, Math.max(1, target))
  const candidates = [bounded.lastIndexOf('. '), bounded.lastIndexOf('! '), bounded.lastIndexOf('? '), bounded.lastIndexOf('\n')]
  const boundary = Math.max(...candidates)
  return boundary >= Math.floor(target / 2) ? boundary + 1 : Math.max(1, target)
}

async function generateResponse(
  env: Env,
  principal: SessionPrincipal,
  request: EvaInferenceRequestV1,
  policy: EvaRoutePolicy,
): Promise<GeneratedResult> {
  const client = openAIClient(env)

  const create = async (repairText?: string) => client.responses.create({
    model: 'gpt-5.6-luna',
    input: repairText
      ? [...modelInput(request), { role: 'user', content: repairText }]
      : modelInput(request),
    max_output_tokens: policy.outputTokenCap,
    reasoning: { context: 'current_turn', effort: policy.reasoning },
    safety_identifier: principal.accountId.slice(0, 64),
    store: false,
    stream: false,
    tools: [],
    prompt_cache_key: `eva:eva-cloud-v2:${request.route}:v${request.contractVersion}`,
    prompt_cache_options: { mode: 'explicit', ttl: '30m' },
    ...(policy.structured ? { text: structuredTextFormat(request.route) } : {}),
  }, { signal: AbortSignal.timeout(60_000) })

  let response: Responses.Response
  try {
    response = await create()
  } catch (error) {
    if (!isTransientProviderError(error)) throw providerError(error)
    try {
      response = await create()
    } catch (retryError) {
      throw providerError(retryError)
    }
  }
  ensureUsableResponse(response)
  let usage = usageFrom(response)
  let text = response.output_text.trim()
  if (!text) throw new EvaHttpError(422, 'output_rejected', 'Cloud EVA did not produce a usable answer.', { retryable: true })

  let structured: unknown
  let repaired = false
  if (policy.structured) {
    try {
      structured = parseStructuredResult(request, text)
    } catch {
      repaired = true
      const repair = await create(`The previous payload was not a valid JSON object. Re-emit only a corrected payload for this route. Previous output:\n${text.slice(0, 12_000)}`)
      ensureUsableResponse(repair)
      usage = addUsage(usage, usageFrom(repair))
      text = repair.output_text.trim()
      try {
        structured = parseStructuredResult(request, text)
      } catch {
        throw new EvaHttpError(422, 'schema_invalid', 'Cloud EVA could not produce a valid structured answer.', {
          retryable: true,
        })
      }
    }
  }
  const visibleText = policy.structured ? JSON.stringify(structured) : text
  const outputDecision = await moderateText(client, visibleText)
  if (!outputDecision.allowed) {
    throw new EvaHttpError(422, 'output_rejected', 'I can’t provide that response, but I can help with a safer alternative.')
  }
  return { text: visibleText, structured, usage, billableSuccess: true, repaired }
}

function recordModelCompletion(
  env: Env,
  principal: SessionPrincipal,
  request: EvaInferenceRequestV1,
  usage: UsageBreakdown,
  actualMicroUsd: number,
  startedAt: number,
  status: string,
  firstDeltaAt?: number,
): void {
  recordTelemetry(env, {
    event: 'model.completed', requestId: request.requestId, accountId: principal.accountId,
    route: request.route, status, durationMs: Date.now() - startedAt,
    ttftMs: firstDeltaAt === undefined ? undefined : firstDeltaAt - startedAt,
    inputTokens: usage.inputTokens, cachedInputTokens: usage.cachedInputTokens,
    cacheWriteTokens: usage.cacheWriteTokens, outputTokens: usage.outputTokens,
    reasoningTokens: usage.reasoningTokens, actualMicroUsd,
  })
}

function responseContainsRefusal(response: Responses.Response): boolean {
  return response.output.some((item) => item.type === 'message'
    && item.content.some((content) => content.type === 'refusal'))
}

function ensureUsableResponse(response: Responses.Response): void {
  if (responseContainsRefusal(response)) {
    throw new EvaHttpError(422, 'output_rejected', 'Cloud EVA declined this request.')
  }
  if (response.status === 'incomplete' || response.status === 'failed' || response.status === 'cancelled') {
    throw new EvaHttpError(422, 'output_rejected', 'Cloud EVA did not complete a usable answer.')
  }
}

function isTransientProviderError(error: unknown): boolean {
  if (error instanceof EvaHttpError || (error instanceof DOMException && error.name === 'AbortError')) return false
  if (typeof error !== 'object' || error === null) return error instanceof TypeError
  const candidate = error as { status?: unknown; name?: unknown; code?: unknown }
  if (typeof candidate.status === 'number') return candidate.status === 429 || candidate.status >= 500
  if (typeof candidate.code === 'string' && ['ETIMEDOUT', 'ECONNRESET', 'ECONNREFUSED', 'EAI_AGAIN'].includes(candidate.code)) return true
  return candidate.name === 'APIConnectionError' || candidate.name === 'APIConnectionTimeoutError' || candidate.name === 'TypeError'
}

function providerError(error: unknown): EvaHttpError {
  if (error instanceof EvaHttpError) return error
  return new EvaHttpError(503, 'provider_unavailable', 'Cloud EVA could not respond right now.', {
    retryable: isTransientProviderError(error), recoveryAction: 'tryOffline',
  })
}

function usageFrom(response: Responses.Response): UsageBreakdown {
  const usage = response.usage
  return {
    inputTokens: usage?.input_tokens ?? 0,
    cachedInputTokens: usage?.input_tokens_details.cached_tokens ?? 0,
    cacheWriteTokens: usage?.input_tokens_details.cache_write_tokens ?? 0,
    outputTokens: usage?.output_tokens ?? 0,
    reasoningTokens: usage?.output_tokens_details.reasoning_tokens ?? 0,
  }
}

function addUsage(left: UsageBreakdown, right: UsageBreakdown): UsageBreakdown {
  return {
    inputTokens: left.inputTokens + right.inputTokens,
    cachedInputTokens: left.cachedInputTokens + right.cachedInputTokens,
    cacheWriteTokens: left.cacheWriteTokens + right.cacheWriteTokens,
    outputTokens: left.outputTokens + right.outputTokens,
    reasoningTokens: left.reasoningTokens + right.reasoningTokens,
  }
}

function parseStructuredResult(request: EvaInferenceRequestV1, text: string): unknown {
  const value: unknown = JSON.parse(text)
  const schema = structuredSchemaForRoute(request.route)
  if (!schema || !Value.Check(schema, value)) throw new Error('Route schema validation failed.')
  const semanticError = semanticValidationError(request.route, value, request)
  if (semanticError) throw new Error(semanticError)
  return value
}

function eventsForResult(
  request: EvaInferenceRequestV1,
  result: GeneratedResult,
  credits: EvaCreditState | undefined,
  ticket: string | undefined,
  quota: EvaQuotaStateV1 | undefined,
): EvaStreamEvent[] {
  let sequence = 0
  const events: EvaStreamEvent[] = [{
    type: 'response.accepted', requestId: request.requestId, sequence: sequence++, credits, quota,
  }]
  if (result.structured !== undefined) {
    events.push({ type: 'response.structured', requestId: request.requestId, sequence: sequence++, value: result.structured })
  } else {
    for (const delta of chunkText(result.text, 240)) {
      events.push({ type: 'response.text.delta', requestId: request.requestId, sequence: sequence++, delta })
    }
  }
  events.push({
    type: 'response.usage', requestId: request.requestId, sequence: sequence++,
    inputTokens: result.usage.inputTokens,
    cachedInputTokens: result.usage.cachedInputTokens,
    cacheWriteTokens: result.usage.cacheWriteTokens,
    outputTokens: result.usage.outputTokens,
    reasoningTokens: result.usage.reasoningTokens,
  })
  events.push({
    type: 'response.completed',
    requestId: request.requestId,
    sequence,
    speechTicket: ticket,
    ...(ticket ? { speechSource: result.text } : {}),
    credits,
    quota,
  })
  return events
}

function eventsForSafeResponse(
  requestId: string,
  text: string,
  credits: EvaCreditState | undefined,
  quota?: EvaQuotaStateV1,
): EvaStreamEvent[] {
  return [
    { type: 'response.accepted', requestId, sequence: 0, credits, quota },
    { type: 'response.text.delta', requestId, sequence: 1, delta: text },
    { type: 'response.completed', requestId, sequence: 2, credits, quota },
  ]
}

function sseResponse(events: EvaStreamEvent[]): Response {
  const body = new ReadableStream({
    start(controller) {
      for (const event of events) controller.enqueue(encoder.encode(`data: ${JSON.stringify(event)}\n\n`))
      controller.close()
    },
  })
  return new Response(body, {
    headers: {
      'Content-Type': 'text/event-stream; charset=utf-8',
      'Cache-Control': 'no-store',
      'X-Accel-Buffering': 'no',
    },
  })
}

function chunkText(text: string, size: number): string[] {
  const chunks: string[] = []
  for (let offset = 0; offset < text.length; offset += size) chunks.push(text.slice(offset, offset + size))
  return chunks
}

async function releaseQuota(env: Env, accountId: string, requestId: string): Promise<void> {
  await durableJson(accountStub(env, accountId), '/quota/release', {
    method: 'POST', body: JSON.stringify({ requestId }),
  })
}

function validatePrincipal(request: EvaInferenceRequestV1, principal: SessionPrincipal): void {
  if (request.installationId !== principal.installationId || request.platform !== principal.platform) {
    throw new EvaHttpError(401, 'unauthenticated', 'This request does not match the signed-in device.', {
      recoveryAction: 'signIn',
    })
  }
}

function enforceInputBudget(request: EvaInferenceRequestV1, policy: EvaRoutePolicy): void {
  const promptInputTokens = Math.ceil(JSON.stringify(modelInput(request)).length / 4)
  const reservedTotalTokens = promptInputTokens + policy.outputTokenCap
  const routeEnvelopeTokens = policy.inputTokenCap + policy.outputTokenCap
  if (promptInputTokens > policy.inputTokenCap || reservedTotalTokens > routeEnvelopeTokens) {
    throw new EvaHttpError(413, 'input_rejected', 'This request contains too much context. Reduce the selected context and try again.')
  }
}

function compareVersions(left: string, right: string): number {
  const parse = (value: string) => value.split('.').map((part) => Number.parseInt(part, 10) || 0)
  const a = parse(left)
  const b = parse(right)
  for (let index = 0; index < Math.max(a.length, b.length); index += 1) {
    if ((a[index] ?? 0) !== (b[index] ?? 0)) return (a[index] ?? 0) - (b[index] ?? 0)
  }
  return 0
}

function authorizationError(reason: 'session' | 'age' | 'attestation' | 'deleted' | undefined): EvaHttpError {
  if (reason === 'age') return new EvaHttpError(403, 'adult_eligibility_required', 'Cloud EVA is available to people age 13 and older.', { recoveryAction: 'verifyAge' })
  if (reason === 'attestation') return new EvaHttpError(401, 'attestation_required', 'Verify this device to use Cloud EVA.', { recoveryAction: 'signIn' })
  return new EvaHttpError(401, 'session_expired', 'Your EVA session has expired.', { recoveryAction: 'signIn' })
}
