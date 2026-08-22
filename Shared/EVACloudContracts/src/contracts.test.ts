import { Value } from '@sinclair/typebox/value'
import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'
import {
  EvaErrorEnvelopeSchema,
  EvaAdultEligibilityRequestV1Schema,
  EvaAppleExchangeRequestV1Schema,
  EvaGuestBootstrapRequestV1Schema,
  EvaQuotaStateV1Schema,
  EvaInferenceRequestV1Schema,
  EvaRefreshRequestV1Schema,
  EvaStreamEventSchema,
  EvaContextPayloadSchemas,
  EvaPlanResultSchema,
  EvaTopThreeResultSchema,
  semanticValidationError,
  sensitiveContextCategories,
  contextPayloadError,
  structuredSchemaForRoute,
  EvaRecordKindSchema,
  EvaNavigationTargetSchema,
} from './index.js'

describe('EVA cloud v1 contracts', () => {
  it('keeps record kinds and navigation targets aligned with the shared drift fixture', () => {
    const fixture = JSON.parse(readFileSync(
      new URL('../fixtures/eva-record-navigation-v1.json', import.meta.url),
      'utf8',
    )) as { recordKinds: string[]; navigationTargets: string[] }
    const literals = (schema: unknown): string[] => ((schema as { anyOf: Array<{ const: string }> }).anyOf)
      .map((item) => item.const)
      .sort()
    expect(literals(EvaRecordKindSchema)).toEqual([...fixture.recordKinds].sort())
    expect(literals(EvaNavigationTargetSchema)).toEqual([...fixture.navigationTargets].sort())
  })

  it('accepts Apple auth UUIDs without relying on an ambient format registry', () => {
    const exchange = JSON.parse(readFileSync(
      new URL('../fixtures/apple-auth-exchange-v1.json', import.meta.url),
      'utf8',
    )) as Record<string, unknown>
    expect(Value.Check(EvaAppleExchangeRequestV1Schema, exchange)).toBe(true)
    expect(Value.Check(EvaAppleExchangeRequestV1Schema, { ...exchange, challengeId: 'not-a-uuid' })).toBe(false)
    expect(Value.Check(EvaAppleExchangeRequestV1Schema, { ...exchange, unexpected: 'private-value' })).toBe(false)

    expect(Value.Check(EvaRefreshRequestV1Schema, {
      accountId: 'account-identifier-long-enough',
      familyId: '33333333-3333-4333-8333-333333333333',
      refreshToken: 'r'.repeat(32),
      installationId: exchange.installationId,
      platform: exchange.platform,
    })).toBe(true)
  })

  it('accepts strict guest bootstrap consent and rolling quota state', () => {
    expect(Value.Check(EvaGuestBootstrapRequestV1Schema, {
      bootstrapId: '11111111-1111-4111-8111-111111111111',
      installationId: '22222222-2222-4222-8222-222222222222',
      platform: 'ios',
      grants: ['journal', 'health'],
      deviceCheckToken: 'd'.repeat(32),
    })).toBe(true)
    expect(Value.Check(EvaGuestBootstrapRequestV1Schema, {
      bootstrapId: '11111111-1111-4111-8111-111111111111',
      installationId: '22222222-2222-4222-8222-222222222222',
      platform: 'ios',
      grants: ['journal', 'journal'],
    })).toBe(false)
    expect(Value.Check(EvaQuotaStateV1Schema, {
      limit: 20,
      used: 7,
      remaining: 13,
      windowSeconds: 86_400,
      nextAvailableAt: '2026-08-21T00:00:00.000Z',
    })).toBe(true)
  })

  it('requires an explicit nullable lower bound for adult eligibility', () => {
    const eligibility = JSON.parse(readFileSync(
      new URL('../fixtures/adult-eligibility-v1.json', import.meta.url),
      'utf8',
    )) as Record<string, unknown>
    expect(Value.Check(EvaAdultEligibilityRequestV1Schema, eligibility)).toBe(true)
    expect(Value.Check(EvaAdultEligibilityRequestV1Schema, { ...eligibility, declaration: 'shared', lowerBound: 18 })).toBe(true)
    const missingLowerBound = { ...eligibility }
    delete missingLowerBound.lowerBound
    expect(Value.Check(EvaAdultEligibilityRequestV1Schema, missingLowerBound)).toBe(false)
    expect(Value.Check(EvaAdultEligibilityRequestV1Schema, { ...eligibility, unexpected: true })).toBe(false)
  })

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

  it('authorizes identifiers only from context, which is where the client must carry them', () => {
    // Swift emits uppercase UUID strings; the validator lowercases before
    // comparing, so the fixture keeps the real client casing.
    const taskID = 'AAAAAAAA-1111-4111-8111-AAAAAAAAAAAA'
    const topThree = {
      items: [{ task_id: taskID, rationale: 'Overdue and blocking the launch.', confidence: 0.8 }],
    }

    // The pre-fix client shape: the task roster was inlined into the prompt and
    // `context` went out empty, so every ranked result named an identifier the
    // server could not authorize.
    expect(semanticValidationError('topThree', topThree, { context: [] }))
      .toContain('outside supplied context')

    // The shape `EvaRouteContextSections.planning` now produces: the roster is a
    // string payload inside a planning section, and the identifiers are
    // recovered from it by scanning.
    const carriedInContext = {
      context: [{
        category: 'planning' as const,
        payload: {
          kind: 'topThree',
          taskProjection: `{"task_id":"${taskID}","title":"Ship the beta","priority":"high"}`,
        },
      }],
    }
    expect(semanticValidationError('topThree', topThree, carriedInContext)).toBeUndefined()

    // Plan commands are authorized through the same path.
    const projectID = 'BBBBBBBB-2222-4222-9222-BBBBBBBBBBBB'
    const plan = {
      schemaVersion: 3,
      commands: [{
        type: 'createInboxTask',
        projectID,
        title: 'Draft the launch note',
        estimatedDuration: null,
        lifeAreaID: null,
        priority: 'high',
        category: null,
        details: null,
        tagIDs: [],
      }],
      rationaleText: 'Captured for review.',
    }
    expect(semanticValidationError('plan', plan, { context: [] })).toContain('outside supplied context')
    expect(semanticValidationError('plan', plan, {
      context: [{
        category: 'planning' as const,
        payload: { kind: 'plan', taskProjection: `Projects:\n- Launch | ${projectID}` },
      }],
    })).toBeUndefined()
  })

  it('gates exactly the four consent categories, and no more', () => {
    // Widening the category list must never widen what a grant covers. If a new
    // category needs a grant it belongs in this set and in a consent revision.
    expect([...sensitiveContextCategories].sort())
      .toEqual(['health', 'journal', 'lifeMoments', 'personalMemory'])
  })

  it('validates v2 context payloads and leaves v1 free-form payloads alone', () => {
    const capacity = {
      day: '2026-08-19T00:00:00Z',
      workingMinutes: 480,
      fixedCalendarMinutes: 120,
      bufferMinutes: 30,
      usableMinutes: 330,
      plannedMinutes: 500,
      overloadMinutes: 170,
      confidence: 'medium' as const,
      freeWindows: [{ start: '2026-08-19T13:00:00Z', end: '2026-08-19T14:00:00Z', minutes: 60 }],
    }
    expect(contextPayloadError(2, [{ category: 'capacity', payload: capacity }])).toBeUndefined()

    // A drifted projection has to fail at the boundary, not degrade an answer.
    const { usableMinutes, ...drifted } = capacity
    expect(usableMinutes).toBe(330)
    expect(contextPayloadError(2, [{ category: 'capacity', payload: drifted }]))
      .toContain('does not match its schema')

    expect(contextPayloadError(2, [{ category: 'nope', payload: {} }]))
      .toContain('Unknown context category')
    expect(contextPayloadError(2, [
      { category: 'capacity', payload: capacity },
      { category: 'capacity', payload: capacity },
    ])).toContain('Duplicate context section')

    // v1 clients keep working through their deprecation window.
    expect(contextPayloadError(1, [{ category: 'planning', payload: { anything: true } }])).toBeUndefined()
  })

  it('keeps the fields that change the character of an answer on a task record', () => {
    const task = {
      id: '44444444-4444-4444-8444-444444444444',
      title: 'Draft the launch note',
      project: 'Launch', projectID: '55555555-5555-4555-8555-555555555555',
      lifeArea: 'Work', priority: 'high' as const, energy: 'medium' as const,
      estimatedMinutes: 45, actualMinutes: null,
      due: '2026-08-19T17:00:00Z', scheduledStart: null, scheduledEnd: null,
      bucket: 'today' as const,
      deferredCount: 4, replanCount: 2, ageDays: 21,
      notesExcerpt: null, blockedBy: [], rankReasons: ['Deadline within 24h'],
    }
    expect(contextPayloadError(2, [{
      category: 'planning',
      payload: {
        generatedAt: '2026-08-19T09:00:00Z',
        summary: { overdue: 3, today: 5, tomorrow: 2, thisWeek: 9, unscheduled: 12, completedToday: 1 },
        tasks: [task], projects: [], lifeAreas: [], partialSections: [],
      },
    }])).toBeUndefined()

    // Dropping deferral history is exactly the v1 regression this guards.
    const { deferredCount, ...lossy } = task
    expect(deferredCount).toBe(4)
    expect(contextPayloadError(2, [{
      category: 'planning',
      payload: {
        generatedAt: '2026-08-19T09:00:00Z',
        summary: { overdue: 0, today: 0, tomorrow: 0, thisWeek: 0, unscheduled: 0, completedToday: 0 },
        tasks: [lossy], projects: [], lifeAreas: [], partialSections: [],
      },
    }])).toContain('does not match its schema')
  })

  it('accepts the context payloads the Swift client actually encodes', () => {
    const fixtures = JSON.parse(readFileSync(
      new URL('../fixtures/context-sections-v2.json', import.meta.url),
      'utf8',
    )) as Record<string, unknown>

    for (const [name, payload] of Object.entries(fixtures)) {
      // `planningDegraded` exercises the fallback path against the planning schema.
      const category = name === 'planningDegraded' ? 'planning' : name
      const schema = EvaContextPayloadSchemas[category as keyof typeof EvaContextPayloadSchemas]
      expect(schema, `${name} schema`).toBeDefined()
      expect(Value.Check(schema, payload), `${name} payload`).toBe(true)
    }

    // The shapes that shipped broken: a v2 request carrying any of these was
    // rejected with HTTP 400 before reaching the model, because contractVersion
    // is a build constant while the payload shape was decided per turn.
    const rejectedLegacyShapes: [string, keyof typeof EvaContextPayloadSchemas, unknown][] = [
      ['planning as loose strings', 'planning',
        { taskProjection: 'Planning context:', executiveState: '', slashCommandState: '' }],
      ['route planning as kind+projection', 'planning',
        { kind: 'plan', taskProjection: 'Context JSON:\n{}' }],
      ['personal memory as a bare string', 'personalMemory', 'User memory: mornings'],
      ['journal wrapped in an object', 'journal',
        { evidence: [{ id: 'x', date: '2026-08-19T09:00:00Z', snippet: 's', matchReason: 'keyword' }] }],
    ]
    for (const [name, category, payload] of rejectedLegacyShapes) {
      expect(Value.Check(EvaContextPayloadSchemas[category], payload), name).toBe(false)
    }

    // Swift's synthesized Encodable omits nil rather than writing null, and the
    // second fixture task exercises that: no due date, no project, no energy.
    // A schema that demanded explicit nulls would reject every real request.
    const planning = fixtures.planning as { tasks: Record<string, unknown>[] }
    expect(planning.tasks[1]).not.toHaveProperty('due')
    expect(planning.tasks[1]).not.toHaveProperty('energy')

    // Closed shapes: a drifted client field fails at the boundary rather than
    // being silently ignored by a prompt that no longer reads it.
    expect(Value.Check(EvaContextPayloadSchemas.planning, {
      ...(fixtures.planning as object),
      unexpectedField: 'drift',
    })).toBe(false)
  })

  it('requires availability metadata and retires summaries in contract v3', () => {
    const payload = {
      generatedAt: '2026-08-20T09:00:00Z',
      summary: { overdue: 0, today: 0, tomorrow: 0, thisWeek: 0, unscheduled: 0, completedToday: 0 },
      tasks: [], projects: [], lifeAreas: [], partialSections: [],
    }
    expect(contextPayloadError(3, [{ category: 'planning', payload }]))
      .toContain('missing v3 availability metadata')
    expect(contextPayloadError(3, [{
      category: 'planning', payload,
      metadata: { availability: 'complete', partialReasons: [], sourceIDs: [] },
    }])).toBeUndefined()
    expect(contextPayloadError(3, [{
      category: 'conversationSummary', payload: { summarizedTurnCount: 2, summary: 'Old turns' },
      metadata: { availability: 'complete', partialReasons: [], sourceIDs: [] },
    }])).toContain('not part of contract v3')
  })

  it('requires temporal turn context and selection provenance in contract v4', () => {
    const payload = {
      generatedAt: '2026-08-21T09:00:00Z',
      summary: { overdue: 0, today: 0, tomorrow: 0, thisWeek: 0, unscheduled: 0, completedToday: 0 },
      tasks: [], projects: [], lifeAreas: [], partialSections: [],
    }
    const metadata = {
      availability: 'complete', partialReasons: [], sourceIDs: [],
      selectionReasons: ['routeBaseline'], freshnessAt: '2026-08-21T09:00:00Z',
    }
    const turnContext = {
      requestedAt: '2026-08-21T09:00:00Z',
      localDate: '2026-08-21',
      calendarIdentifier: 'gregorian',
      firstWeekday: 2,
      surface: 'evaTab',
    }

    expect(contextPayloadError(4, [{ category: 'planning', payload, metadata }]))
      .toContain('requires a valid turnContext')
    expect(contextPayloadError(4, [{ category: 'planning', payload, metadata }], turnContext))
      .toBeUndefined()
    expect(contextPayloadError(4, [{
      category: 'planning', payload,
      metadata: { availability: 'complete', partialReasons: [], sourceIDs: [] },
    }], turnContext)).toContain('selection reasons')
  })

  it('accepts query-bounded Knowledge without adding a consent grant', () => {
    const turnContext = {
      requestedAt: '2026-08-21T09:00:00Z', localDate: '2026-08-21',
      calendarIdentifier: 'gregorian', firstWeekday: 2, surface: 'knowledge',
    }
    const knowledge = [{
      id: '11111111-1111-4111-8111-111111111111',
      title: 'Pricing decision',
      matchedExcerpt: 'We chose annual billing after the customer interviews.',
      modifiedAt: '2026-08-20T09:00:00Z',
      matchReason: 'semanticMatch',
    }]
    expect(contextPayloadError(4, [{
      category: 'knowledge', payload: knowledge,
      metadata: {
        availability: 'complete', availableCount: 1, includedCount: 1,
        partialReasons: [], sourceIDs: [knowledge[0]!.id],
        selectionReasons: ['semanticMatch'], freshnessAt: knowledge[0]!.modifiedAt,
      },
    }], turnContext)).toBeUndefined()
    expect([...sensitiveContextCategories]).not.toContain('knowledge')
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
