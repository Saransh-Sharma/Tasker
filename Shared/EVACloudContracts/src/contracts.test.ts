import { Value } from '@sinclair/typebox/value'
import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'
import {
  EvaErrorEnvelopeSchema,
  EvaInferenceRequestV1Schema,
  EvaStreamEventSchema,
  EvaPlanResultSchema,
  EvaTopThreeResultSchema,
  semanticValidationError,
  structuredSchemaForRoute,
} from './index.js'

describe('EVA cloud v1 contracts', () => {
  it('accepts a bounded inference request fixture', () => {
    expect(Value.Check(EvaInferenceRequestV1Schema, {
      requestId: '5ad4a27b-73f7-48d6-909f-14f12a8fc98c',
      route: 'chat',
      contractVersion: 1,
      locale: 'en-IN',
      timeZone: 'Asia/Kolkata',
      messages: [{ role: 'user', content: 'Plan my afternoon.' }],
      context: [{ category: 'planning', payload: { taskCount: 3 } }],
      clientVersion: '1.0.0',
      platform: 'ios',
      installationId: 'e6703cd8-eada-48bd-b9f5-b593d03d09a3',
      consentRevision: 0,
      providerCapabilities: {
        streaming: true,
        structuredOutput: true,
        spokenOutput: true,
      },
    })).toBe(true)
  })

  it('rejects client-owned model controls', () => {
    const value = {
      requestId: '5ad4a27b-73f7-48d6-909f-14f12a8fc98c',
      route: 'chat',
      contractVersion: 1,
      locale: 'en-IN',
      timeZone: 'Asia/Kolkata',
      messages: [{ role: 'user', content: 'Hello' }],
      context: [],
      clientVersion: '1.0.0',
      platform: 'ios',
      installationId: 'e6703cd8-eada-48bd-b9f5-b593d03d09a3',
      consentRevision: 0,
      providerCapabilities: { streaming: true, structuredOutput: true, spokenOutput: false },
      model: 'client-controlled-model',
    }
    expect(Value.Check(EvaInferenceRequestV1Schema, value)).toBe(false)
  })

  it('accepts stable error and stream envelopes', () => {
    const error = {
      code: 'insufficient_credits',
      message: 'No cloud credits are available.',
      requestId: '5ad4a27b-73f7-48d6-909f-14f12a8fc98c',
      retryable: false,
      recoveryAction: 'tryOffline',
    }
    expect(Value.Check(EvaErrorEnvelopeSchema, error)).toBe(true)
    expect(Value.Check(EvaStreamEventSchema, {
      type: 'response.failed',
      requestId: error.requestId,
      sequence: 1,
      error,
    })).toBe(true)
    expect(Value.Check(EvaStreamEventSchema, {
      type: 'response.usage',
      requestId: error.requestId,
      sequence: 2,
      inputTokens: 100,
      cachedInputTokens: 20,
      cacheWriteTokens: 10,
      outputTokens: 30,
      reasoningTokens: 5,
    })).toBe(true)
  })

  it('enforces strict route schemas and bounded top priorities', () => {
    const task = (task_id: string) => ({ task_id, rationale: 'Important now', confidence: 0.9 })
    expect(Value.Check(EvaTopThreeResultSchema, {
      items: [
        task('11111111-1111-4111-8111-111111111111'),
        task('22222222-2222-4222-8222-222222222222'),
        task('33333333-3333-4333-8333-333333333333'),
        task('44444444-4444-4444-8444-444444444444'),
      ],
    })).toBe(false)
    expect(Value.Check(EvaPlanResultSchema, {
      schemaVersion: 3,
      commands: [],
      rationaleText: 'No change required.',
      unexpected: true,
    })).toBe(false)
  })

  it('rejects invented identifiers and invalid schedule intervals', () => {
    const knownProject = '11111111-1111-4111-8111-111111111111'
    const inventedProject = '22222222-2222-4222-8222-222222222222'
    const request = { context: [{ category: 'planning' as const, payload: { projectID: knownProject } }] }
    const plan = {
      schemaVersion: 3,
      commands: [{
        type: 'createScheduledTask',
        projectID: inventedProject,
        title: 'Focus',
        scheduledStartAt: '2026-08-14T11:00:00Z',
        scheduledEndAt: '2026-08-14T10:00:00Z',
        estimatedDuration: null,
        lifeAreaID: null,
        priority: null,
        energy: null,
        category: null,
        context: null,
        details: null,
        tagIDs: [],
      }],
      rationaleText: 'Create a focus block.',
    }
    expect(semanticValidationError('plan', plan, request)).toContain('outside supplied context')
    plan.commands[0]!.projectID = knownProject
    expect(semanticValidationError('plan', plan, request)).toContain('end after it starts')
  })

  it('validates every shared structured fixture against its route schema', () => {
    const fixtures = JSON.parse(readFileSync(new URL('../fixtures/structured-results-v1.json', import.meta.url), 'utf8')) as Record<string, unknown>
    for (const [route, value] of Object.entries(fixtures)) {
      const schema = structuredSchemaForRoute(route as Parameters<typeof structuredSchemaForRoute>[0])
      expect(schema, `${route} schema`).toBeDefined()
      expect(Value.Check(schema!, value), `${route} fixture`).toBe(true)
    }
  })
})
