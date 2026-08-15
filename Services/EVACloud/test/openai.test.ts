import type OpenAI from 'openai'
import { describe, expect, it } from 'vitest'
import type { EvaInferenceRequestV1 } from '@lifeboard/eva-contracts'
import { actualLunaCostMicroUsd, estimatedLunaCostMicroUsd } from '../src/openai/accounting.js'
import { modelInput, structuredTextFormat } from '../src/openai/prompts.js'
import { moderateText } from '../src/safety/moderation.js'

function moderationClient(flagged: boolean, categories: Record<string, boolean> = {}): OpenAI {
  return {
    moderations: {
      create: async () => ({ results: [{ flagged, categories }] }),
    },
  } as unknown as OpenAI
}

const request: EvaInferenceRequestV1 = {
  requestId: '11111111-1111-4111-8111-111111111111',
  route: 'plan',
  contractVersion: 1,
  locale: 'en_US',
  timeZone: 'Asia/Kolkata',
  messages: [{ role: 'user', content: 'Plan my day.' }],
  context: [{ category: 'planning', payload: { tasks: [] } }],
  clientVersion: '1.0.0',
  platform: 'ios',
  installationId: '22222222-2222-4222-8222-222222222222',
  consentRevision: 1,
  providerCapabilities: { streaming: true, structuredOutput: true, spokenOutput: true },
}

const prices = {
  version: 'test',
  effectiveAt: '2026-08-14T00:00:00.000Z',
  approved: true,
  lunaInputMicroUsdPerMillion: 200_000,
  lunaCachedInputMicroUsdPerMillion: 20_000,
  lunaCacheWriteMicroUsdPerMillion: 250_000,
  lunaOutputMicroUsdPerMillion: 1_200_000,
  moderationMicroUsdPerMillion: 0,
  ttsMicroUsdPerMillionCharacters: 15_000_000,
}

describe('OpenAI policy adapter', () => {
  it('classifies ordinary and self-harm moderation results without retaining content', async () => {
    await expect(moderateText(moderationClient(false), 'ordinary planning request')).resolves.toEqual({
      allowed: true,
      selfHarm: false,
    })
    await expect(moderateText(
      moderationClient(true, { 'self-harm/intent': true }),
      'high-risk request',
    )).resolves.toEqual({ allowed: false, selfHarm: true })
  })

  it('keeps model ownership, cache boundary, and strict structured envelope on the server', () => {
    const input = JSON.stringify(modelInput(request))
    const format = structuredTextFormat('plan')
    expect(input).toContain('prompt_cache_breakpoint')
    expect(input).toContain('Use only context explicitly supplied')
    expect(input).not.toContain('gpt-5.6-luna')
    expect(format.format).toMatchObject({ type: 'json_schema', strict: true })
  })

  it('accounts for cache reads, cache writes, uncached input, and output separately', () => {
    expect(estimatedLunaCostMicroUsd(100, 50, prices, 3)).toBe(255)
    expect(actualLunaCostMicroUsd({
      inputTokens: 100,
      cachedInputTokens: 20,
      cacheWriteTokens: 10,
      outputTokens: 5,
      reasoningTokens: 2,
    }, prices)).toBe(23)
  })
})
