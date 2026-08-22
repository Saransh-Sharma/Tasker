import { Hono } from 'hono'
import type { EvaSpeechRequest } from '@lifeboard/eva-contracts'
import { EvaSpeechRequestSchema } from '@lifeboard/eva-contracts'
import type { AppVariables, Env } from '../environment.js'
import { requireSession } from '../auth/middleware.js'
import { verifySpeechTicket } from '../auth/speech-ticket.js'
import { verifyRequestAttestation } from '../attestation/app-attest.js'
import { accountStub, authorizeAccount } from '../durable-objects/account-client.js'
import { durableJson } from '../durable-objects/helpers.js'
import { readJson } from '../http/body.js'
import { EvaHttpError } from '../http/errors.js'
import { commitCost, markRequestRunning, releaseCost, reserveCost, speechCostMicroUsd } from '../openai/accounting.js'
import { openAIClient } from '../openai/client.js'
import { requiresAgeDecision, runtimeConfig } from '../config/runtime-config.js'
import { sha256 } from '../security/crypto.js'

export const speechRoutes = new Hono<{ Bindings: Env; Variables: AppVariables }>()
speechRoutes.use('*', requireSession)

speechRoutes.post('/speech', async (context) => {
  const principal = context.get('principal')
  if (principal.platform === 'ios' && context.req.header('X-EVA-Attest-Assertion')) {
    await verifyRequestAttestation(context.env, principal, context.req.raw)
  }
  const request = await readJson<EvaSpeechRequest>(context.req.raw, EvaSpeechRequestSchema)
  const config = await runtimeConfig(context.env)
  if (!config.ttsEnabled) {
    throw new EvaHttpError(503, 'configuration_unavailable', 'Spoken output is temporarily unavailable.')
  }
  if (principal.identityKind === 'guest' && !config.guestAccess?.inferenceEnabled) {
    throw new EvaHttpError(503, 'configuration_unavailable', 'Guest Cloud EVA is temporarily unavailable.')
  }
  const authorization = await authorizeAccount(context.env, principal, {
    requireAdult: requiresAgeDecision(config),
  })
  if (!authorization.authorized) {
    throw new EvaHttpError(401, 'session_expired', 'Your EVA session has expired.', {
      recoveryAction: 'wait',
    })
  }
  const limit = principal.platform === 'catalyst' ? 5 : 10
  const rate = await durableJson<{ allowed: boolean; retryAfter?: number }>(accountStub(context.env, principal.accountId), '/rate/consume', {
    method: 'POST', body: JSON.stringify({ bucket: 'speech', limit }),
  })
  if (!rate.allowed) {
    throw new EvaHttpError(429, 'rate_limited', 'Spoken output is receiving too many requests.', {
      retryable: true, retryAfter: rate.retryAfter ?? 60, recoveryAction: 'wait',
    })
  }

  let claims: Awaited<ReturnType<typeof verifySpeechTicket>>
  try {
    claims = await verifySpeechTicket(context.env, request.speechTicket)
  } catch {
    throw new EvaHttpError(409, 'unauthenticated', 'The speech permission is invalid or expired.')
  }
  const textHash = await sha256(request.text)
  if (claims.accountId !== principal.accountId || claims.textHash !== textHash) {
    throw new EvaHttpError(409, 'unauthenticated', 'The speech permission does not match this answer.')
  }

  const paidReservationId = `speech:${request.requestId}`
  const claim = await durableJson<{
    claimed: boolean
    included?: boolean
    requiresCredit?: boolean
    credits?: unknown
  }>(accountStub(context.env, principal.accountId), '/speech/claim', {
    method: 'POST',
    body: JSON.stringify({
      ticketId: claims.ticketId,
      textHash,
      allowPaidRegeneration: request.allowPaidRegeneration,
      paidReservationId,
    }),
  })
  if (!claim.claimed) {
    throw new EvaHttpError(429, 'daily_quota_exhausted', 'Spoken-output regeneration has reached its current limit.', {
      recoveryAction: 'wait',
    })
  }

  const costRequestId = `tts:${claims.ticketId}:${request.requestId}`
  const estimatedMicroUsd = speechCostMicroUsd(request.text.length, config.priceSchedule)
  const costReservation = await reserveCost(context.env, principal.accountId, costRequestId, estimatedMicroUsd)
  if (costReservation !== 'reserved') {
    await failSpeech(context.env, principal.accountId, claims.ticketId)
    if (costReservation === 'replayed') {
      throw new EvaHttpError(409, 'request_replayed', 'This speech request ID has already been used. Start a new request to regenerate.')
    }
    throw new EvaHttpError(503, 'budget_exhausted', 'Spoken output has reached its current usage budget.', {
      recoveryAction: 'tryOffline',
    })
  }
  await markRequestRunning(context.env, principal.accountId, costRequestId)

  const chunks = sentenceChunks(request.text, 4_000)
  const client = openAIClient(context.env)
  const abortController = new AbortController()
  context.req.raw.signal.addEventListener('abort', () => abortController.abort(), { once: true })
  const body = new ReadableStream<Uint8Array>({
    async start(controller) {
      try {
        for (const chunk of chunks) {
          const response = await client.audio.speech.create({
            model: config.speechModel,
            voice: config.speechVoice,
            input: chunk,
            response_format: 'pcm',
            stream_format: 'audio',
          }, { signal: abortController.signal })
          if (!response.body) throw new Error('Speech response did not include a stream.')
          const reader = response.body.getReader()
          while (true) {
            const result = await reader.read()
            if (result.done) break
            controller.enqueue(result.value)
          }
        }
        await durableJson(accountStub(context.env, principal.accountId), '/speech/complete', {
          method: 'POST', body: JSON.stringify({ ticketId: claims.ticketId }),
        })
        await commitCost(context.env, principal.accountId, costRequestId, estimatedMicroUsd)
        controller.close()
      } catch (error) {
        await failSpeech(context.env, principal.accountId, claims.ticketId)
        await releaseCost(context.env, principal.accountId, costRequestId)
        controller.error(error)
      }
    },
    cancel() {
      abortController.abort()
    },
  })
  return new Response(body, {
    headers: {
      'Content-Type': 'audio/pcm',
      'Cache-Control': 'no-store',
      'X-EVA-Audio-Sample-Rate': '24000',
      'X-EVA-Audio-Channels': '1',
      'X-EVA-Audio-Sample-Format': 's16le',
      'X-EVA-Voice-Disclosure': 'AI-generated',
    },
  })
})

async function failSpeech(env: Env, accountId: string, ticketId: string): Promise<void> {
  await durableJson(accountStub(env, accountId), '/speech/fail', {
    method: 'POST', body: JSON.stringify({ ticketId }),
  })
}

export function sentenceChunks(text: string, maximumLength: number): string[] {
  const normalized = text.trim()
  if (normalized.length <= maximumLength) return normalized ? [normalized] : []
  const sentences = normalized.match(/[^.!?]+(?:[.!?]+|$)/gu) ?? [normalized]
  const result: string[] = []
  let current = ''
  for (const sentence of sentences) {
    const value = sentence.trim()
    if (!value) continue
    if (value.length > maximumLength) {
      if (current) result.push(current)
      current = ''
      for (let offset = 0; offset < value.length; offset += maximumLength) {
        result.push(value.slice(offset, offset + maximumLength))
      }
    } else if (!current) {
      current = value
    } else if (current.length + 1 + value.length <= maximumLength) {
      current += ` ${value}`
    } else {
      result.push(current)
      current = value
    }
  }
  if (current) result.push(current)
  return result
}
