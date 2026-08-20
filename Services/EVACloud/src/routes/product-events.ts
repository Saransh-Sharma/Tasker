import { Type } from '@sinclair/typebox'
import { Hono } from 'hono'
import type { AppVariables, Env } from '../environment.js'
import { readJson } from '../http/body.js'
import { recordTelemetry } from '../telemetry/events.js'

const eventNames = [
  'onboardingPresented', 'onboardingStepViewed', 'onboardingStepCompleted', 'onboardingBack',
  'onboardingDeferred', 'firstCaptureInterpreted', 'firstCaptureConfirmed', 'firstCaptureFailed',
  'firstCaptureSkipped', 'commitStarted', 'commitCompleted', 'commitFailed', 'revealViewed',
  'coreFinalized', 'refreshPresented', 'refreshCompleted', 'refreshDeferred', 'setupCenterOpened',
  'setupCenterDismissed', 'connectorResult', 'evaActivationStarted', 'evaActivationSucceeded',
  'evaActivationFailed', 'evaActivationDismissed', 'memoryProposalShown', 'memoryProposalSaved',
  'memoryProposalEdited', 'memoryProposalDeferred', 'memoryProposalDismissed', 'contextReceiptOpened',
  'contextSourceExcluded', 'contextSourceRestored', 'contextConsentChanged',
] as const

const ProductEventSchema = Type.Object({
  name: Type.Union(eventNames.map((name) => Type.Literal(name))),
  timestamp: Type.String({ pattern: '^\\d{4}-\\d{2}-\\d{2}T' }),
  flowVersion: Type.Optional(Type.Integer({ minimum: 1, maximum: 100 })),
  audience: Type.Optional(Type.String({ pattern: '^[a-zA-Z0-9_-]{1,40}$' })),
  outcome: Type.Optional(Type.String({ pattern: '^[a-zA-Z0-9_-]{1,40}$' })),
  errorCode: Type.Optional(Type.String({ pattern: '^[a-zA-Z0-9_.-]{1,80}$' })),
  count: Type.Optional(Type.Integer({ minimum: 0, maximum: 100_000 })),
  durationBucket: Type.Optional(Type.Union([
    Type.Literal('under_1s'), Type.Literal('1_3s'), Type.Literal('3_10s'),
    Type.Literal('10_30s'), Type.Literal('over_30s'),
  ])),
}, { additionalProperties: false })

const ProductEventBatchSchema = Type.Object({
  schemaVersion: Type.Literal(1),
  installationId: Type.String({ pattern: '^[0-9A-Fa-f-]{36}$' }),
  events: Type.Array(ProductEventSchema, { minItems: 1, maxItems: 32 }),
}, { additionalProperties: false })

export const productEventRoutes = new Hono<{ Bindings: Env; Variables: AppVariables }>()

productEventRoutes.post('/', async (context) => {
  const batch = await readJson<{
    installationId: string
    events: Array<{ name: string; outcome?: string; errorCode?: string; count?: number; durationBucket?: string }>
  }>(context.req.raw, ProductEventBatchSchema)
  for (const event of batch.events) {
    recordTelemetry(context.env, {
      event: `product.${event.name}`,
      requestId: batch.installationId,
      status: event.outcome ?? event.errorCode ?? '',
      route: event.durationBucket,
      inputTokens: event.count,
    })
  }
  return context.json({ accepted: batch.events.length }, 202)
})
