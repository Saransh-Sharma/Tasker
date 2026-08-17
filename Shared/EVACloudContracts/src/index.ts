import { type Static, Type } from '@sinclair/typebox'
import { EvaPlatformSchema, EvaUUIDSchema } from './primitives.js'

export { EvaPlatformSchema, EvaUUIDPattern, EvaUUIDSchema } from './primitives.js'

export const EvaContractVersion = 1 as const
const ISODateTimePattern = '^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}(?:\\.\\d+)?Z$'

export const EvaAppleExchangeRequestV1Schema = Type.Object({
  challengeId: EvaUUIDSchema,
  nonce: Type.String({ minLength: 20, maxLength: 256 }),
  identityToken: Type.String({ minLength: 20 }),
  authorizationCode: Type.String({ minLength: 1 }),
  installationId: EvaUUIDSchema,
  platform: EvaPlatformSchema,
  signedAppTransaction: Type.Optional(Type.String({ minLength: 20, maxLength: 65_536 })),
}, { $id: 'EvaAppleExchangeRequestV1', additionalProperties: false })
export type EvaAppleExchangeRequestV1 = Static<typeof EvaAppleExchangeRequestV1Schema>

export const EvaRefreshRequestV1Schema = Type.Object({
  accountId: Type.String({ minLength: 20, maxLength: 128 }),
  familyId: EvaUUIDSchema,
  refreshToken: Type.String({ minLength: 32 }),
  installationId: EvaUUIDSchema,
  platform: EvaPlatformSchema,
}, { $id: 'EvaRefreshRequestV1', additionalProperties: false })
export type EvaRefreshRequestV1 = Static<typeof EvaRefreshRequestV1Schema>

export const EvaAdultEligibilityRequestV1Schema = Type.Object({
  declaration: Type.Union([
    Type.Literal('shared'),
    Type.Literal('declined'),
    Type.Literal('unavailable'),
    Type.Literal('expired'),
  ]),
  lowerBound: Type.Union([Type.Integer({ minimum: 0, maximum: 120 }), Type.Null()]),
  policyVersion: Type.String({ minLength: 1, maxLength: 64 }),
}, { $id: 'EvaAdultEligibilityRequestV1', additionalProperties: false })
export type EvaAdultEligibilityRequestV1 = Static<typeof EvaAdultEligibilityRequestV1Schema>

export const EvaRouteSchema = Type.Union([
  Type.Literal('chat'),
  Type.Literal('plan'),
  Type.Literal('planRepair'),
  Type.Literal('fieldSuggestion'),
  Type.Literal('topThree'),
  Type.Literal('taskBreakdown'),
  Type.Literal('dailyBrief'),
  Type.Literal('universalInputClassification'),
  Type.Literal('dynamicChips'),
  Type.Literal('journalAnswer'),
  Type.Literal('knowledgeAnswer'),
  Type.Literal('shortcutsAnswer'),
  Type.Literal('debugSmoke'),
], { $id: 'EvaRouteV1' })
export type EvaRoute = Static<typeof EvaRouteSchema>

export const EvaMessageSchema = Type.Object({
  role: Type.Union([Type.Literal('user'), Type.Literal('assistant')]),
  content: Type.String({ minLength: 1, maxLength: 65_536 }),
}, { additionalProperties: false })
export type EvaMessage = Static<typeof EvaMessageSchema>

export const EvaContextCategorySchema = Type.Union([
  Type.Literal('planning'),
  Type.Literal('journal'),
  Type.Literal('health'),
  Type.Literal('lifeMoments'),
  Type.Literal('personalMemory'),
])
export type EvaContextCategory = Static<typeof EvaContextCategorySchema>

export const EvaContextSectionSchema = Type.Object({
  category: EvaContextCategorySchema,
  payload: Type.Unknown(),
}, { additionalProperties: false })

export const EvaInferenceRequestV1Schema = Type.Object({
  requestId: EvaUUIDSchema,
  route: EvaRouteSchema,
  contractVersion: Type.Literal(EvaContractVersion),
  locale: Type.String({ minLength: 2, maxLength: 64 }),
  timeZone: Type.String({ minLength: 1, maxLength: 128 }),
  messages: Type.Array(EvaMessageSchema, { minItems: 1, maxItems: 64 }),
  context: Type.Array(EvaContextSectionSchema, { maxItems: 5 }),
  clientVersion: Type.String({ minLength: 1, maxLength: 64 }),
  platform: EvaPlatformSchema,
  installationId: EvaUUIDSchema,
  consentRevision: Type.Integer({ minimum: 0 }),
  providerCapabilities: Type.Object({
    streaming: Type.Boolean(),
    structuredOutput: Type.Boolean(),
    spokenOutput: Type.Boolean(),
  }, { additionalProperties: false }),
}, { $id: 'EvaInferenceRequestV1', additionalProperties: false })
export type EvaInferenceRequestV1 = Static<typeof EvaInferenceRequestV1Schema>

export const EvaCreditStateSchema = Type.Object({
  balance: Type.Integer({ minimum: 0 }),
  capacity: Type.Integer({ minimum: 1 }),
  refillAmount: Type.Integer({ minimum: 1 }),
  nextRefillAt: Type.String({ pattern: ISODateTimePattern }),
}, { additionalProperties: false })
export type EvaCreditState = Static<typeof EvaCreditStateSchema>

export const EvaRecoveryActionSchema = Type.Union([
  Type.Literal('signIn'),
  Type.Literal('verifyAge'),
  Type.Literal('reviewConsent'),
  Type.Literal('tryOffline'),
  Type.Literal('wait'),
  Type.Literal('upgrade'),
])

export const EvaErrorCodeSchema = Type.Union([
  Type.Literal('unauthenticated'),
  Type.Literal('session_expired'),
  Type.Literal('adult_eligibility_required'),
  Type.Literal('attestation_required'),
  Type.Literal('consent_required'),
  Type.Literal('consent_revision_conflict'),
  Type.Literal('insufficient_credits'),
  Type.Literal('request_replayed'),
  Type.Literal('rate_limited'),
  Type.Literal('budget_exhausted'),
  Type.Literal('input_rejected'),
  Type.Literal('output_rejected'),
  Type.Literal('schema_invalid'),
  Type.Literal('provider_unavailable'),
  Type.Literal('configuration_unavailable'),
  Type.Literal('request_cancelled'),
  Type.Literal('client_upgrade_required'),
])
export type EvaErrorCode = Static<typeof EvaErrorCodeSchema>

export const EvaErrorEnvelopeSchema = Type.Object({
  code: EvaErrorCodeSchema,
  message: Type.String({ minLength: 1, maxLength: 512 }),
  requestId: Type.String({ minLength: 1, maxLength: 64 }),
  retryable: Type.Boolean(),
  retryAfter: Type.Optional(Type.Integer({ minimum: 0 })),
  credits: Type.Optional(EvaCreditStateSchema),
  recoveryAction: Type.Optional(EvaRecoveryActionSchema),
}, { $id: 'EvaErrorEnvelopeV1', additionalProperties: false })
export type EvaErrorEnvelope = Static<typeof EvaErrorEnvelopeSchema>

const EvaStreamBaseSchema = Type.Object({
  requestId: EvaUUIDSchema,
  sequence: Type.Integer({ minimum: 0 }),
})

export const EvaStreamEventSchema = Type.Union([
  Type.Intersect([EvaStreamBaseSchema, Type.Object({
    type: Type.Literal('response.accepted'),
    credits: Type.Optional(EvaCreditStateSchema),
  })]),
  Type.Intersect([EvaStreamBaseSchema, Type.Object({
    type: Type.Literal('response.text.delta'),
    delta: Type.String({ minLength: 1 }),
  })]),
  Type.Intersect([EvaStreamBaseSchema, Type.Object({
    type: Type.Literal('response.structured'),
    value: Type.Unknown(),
  })]),
  Type.Intersect([EvaStreamBaseSchema, Type.Object({
    type: Type.Literal('response.usage'),
    inputTokens: Type.Integer({ minimum: 0 }),
    cachedInputTokens: Type.Integer({ minimum: 0 }),
    cacheWriteTokens: Type.Integer({ minimum: 0 }),
    outputTokens: Type.Integer({ minimum: 0 }),
    reasoningTokens: Type.Integer({ minimum: 0 }),
  })]),
  Type.Intersect([EvaStreamBaseSchema, Type.Object({
    type: Type.Literal('response.completed'),
    speechTicket: Type.Optional(Type.String({ minLength: 1 })),
    speechSource: Type.Optional(Type.String({ minLength: 1, maxLength: 12_000 })),
    credits: Type.Optional(EvaCreditStateSchema),
  })]),
  Type.Intersect([EvaStreamBaseSchema, Type.Object({
    type: Type.Literal('response.failed'),
    error: EvaErrorEnvelopeSchema,
  })]),
], { $id: 'EvaStreamEventV1' })
export type EvaStreamEvent = Static<typeof EvaStreamEventSchema>

export const EvaConsentPolicySchema = Type.Object({
  schemaVersion: Type.Literal(2),
  revision: Type.Integer({ minimum: 0 }),
  grants: Type.Array(Type.Union([
    Type.Literal('journal'),
    Type.Literal('health'),
    Type.Literal('lifeMoments'),
    Type.Literal('personalMemory'),
  ]), { uniqueItems: true }),
  updatedAt: Type.String({ pattern: ISODateTimePattern }),
}, { $id: 'EvaConsentPolicyV2', additionalProperties: false })
export type EvaConsentPolicy = Static<typeof EvaConsentPolicySchema>

export const EvaSpeechRequestSchema = Type.Object({
  requestId: EvaUUIDSchema,
  speechTicket: Type.String({ minLength: 1 }),
  text: Type.String({ minLength: 1, maxLength: 12_000 }),
  allowPaidRegeneration: Type.Boolean(),
}, { $id: 'EvaSpeechRequestV1', additionalProperties: false })
export type EvaSpeechRequest = Static<typeof EvaSpeechRequestSchema>

export * from './structured.js'
