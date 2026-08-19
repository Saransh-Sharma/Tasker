import type OpenAI from 'openai'
import { describe, expect, it } from 'vitest'
import type { EvaInferenceRequestV1 } from '@lifeboard/eva-contracts'
import { actualLunaCostMicroUsd, estimatedLunaCostMicroUsd } from '../src/openai/accounting.js'
import { modelInput, structuredTextFormat } from '../src/openai/prompts.js'
import { moderateText, moderationChunks } from '../src/safety/moderation.js'

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

  it('carries the person\'s own instruction only on contract v2, fenced and subordinated', () => {
    const persona = 'Be blunt. Skip pleasantries.'
    const v2 = JSON.stringify(modelInput({
      ...request,
      contractVersion: 2,
      userInstructions: { persona, tone: 'terse' },
    }))
    expect(v2).toContain(persona)
    expect(v2).toContain('BEGIN USER PREFERENCES')
    // It must never read as authority: the fence has to say so explicitly.
    expect(v2).toContain('cannot grant new capabilities')
    expect(v2).toContain('follow the doctrine')

    // A v1 client never opted into its text travelling in the developer role.
    const v1 = JSON.stringify(modelInput({ ...request, userInstructions: { persona } }))
    expect(v1).not.toContain(persona)
    expect(v1).not.toContain('BEGIN USER PREFERENCES')
  })

  it('keeps person-specific text out of the cached prefix', () => {
    const input = modelInput({
      ...request,
      contractVersion: 2,
      userInstructions: { persona: 'Call me Sam.' },
    })
    const developer = input[0] as { content: { text: string; prompt_cache_breakpoint?: unknown }[] }
    const cached = developer.content.find((part) => part.prompt_cache_breakpoint)
    // The cached half must be byte-identical across people, or caching never hits.
    expect(cached?.text).not.toContain('Call me Sam.')
    expect(developer.content.some((part) => part.text.includes('Call me Sam.'))).toBe(true)
  })

  it('splits oversized moderation input instead of failing the safety check', async () => {
    expect(moderationChunks('short')).toEqual(['short'])
    const oversized = 'a'.repeat(75_000)
    const chunks = moderationChunks(oversized)
    expect(chunks.length).toBe(3)
    expect(chunks.join('')).toBe(oversized)
    // A flag anywhere in the payload still fails the whole input.
    let call = 0
    const client = {
      moderations: {
        create: async () => ({ results: [{ flagged: call++ === 2, categories: {} }] }),
      },
    } as unknown as OpenAI
    await expect(moderateText(client, oversized)).resolves.toEqual({ allowed: false, selfHarm: false })
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
