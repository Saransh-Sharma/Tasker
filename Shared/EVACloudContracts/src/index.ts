import { type Static, Type } from '@sinclair/typebox'
import { EvaContextSelectionReasonSchema, EvaTurnContextSchema } from './context.js'
import { EvaPlatformSchema, EvaUUIDSchema } from './primitives.js'

export { EvaPlatformSchema, EvaUUIDPattern, EvaUUIDSchema } from './primitives.js'

export const EvaContractVersion = 4 as const
/** Versions a current Worker still admits. */
export const EvaSupportedContractVersions = [1, 2, 3, 4] as const
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

export const EvaIdentityKindSchema = Type.Union([
  Type.Literal('guest'),
  Type.Literal('apple'),
], { $id: 'EvaIdentityKindV1' })
export type EvaIdentityKind = Static<typeof EvaIdentityKindSchema>

const EvaConsentGrantSchema = Type.Union([
  Type.Literal('journal'),
  Type.Literal('health'),
  Type.Literal('lifeMoments'),
  Type.Literal('personalMemory'),
])

export const EvaGuestBootstrapRequestV1Schema = Type.Object({
  bootstrapId: EvaUUIDSchema,
  installationId: EvaUUIDSchema,
  platform: EvaPlatformSchema,
  grants: Type.Array(EvaConsentGrantSchema, { maxItems: 4, uniqueItems: true }),
  signedAppTransaction: Type.Optional(Type.String({ minLength: 20, maxLength: 65_536 })),
  deviceCheckToken: Type.Optional(Type.String({ minLength: 20, maxLength: 8_192 })),
}, { $id: 'EvaGuestBootstrapRequestV1', additionalProperties: false })
export type EvaGuestBootstrapRequestV1 = Static<typeof EvaGuestBootstrapRequestV1Schema>

export const EvaAppleLinkRequestV1Schema = Type.Intersect([
  EvaAppleExchangeRequestV1Schema,
  Type.Object({}, { additionalProperties: false }),
], { $id: 'EvaAppleLinkRequestV1' })
export type EvaAppleLinkRequestV1 = EvaAppleExchangeRequestV1

export const EvaRefreshRequestV1Schema = Type.Object({
  accountId: Type.String({ minLength: 20, maxLength: 128 }),
  familyId: EvaUUIDSchema,
  refreshToken: Type.String({ minLength: 32 }),
  installationId: EvaUUIDSchema,
  platform: EvaPlatformSchema,
}, { $id: 'EvaRefreshRequestV1', additionalProperties: false })
export type EvaRefreshRequestV1 = Static<typeof EvaRefreshRequestV1Schema>

export const EvaDeleteAccountRequestV1Schema = Type.Object({
  confirmation: Type.Literal('deleteCloudEvaData'),
}, { $id: 'EvaDeleteAccountRequestV1', additionalProperties: false })
export type EvaDeleteAccountRequestV1 = Static<typeof EvaDeleteAccountRequestV1Schema>

export const EvaAdultEligibilityRequestV1Schema = Type.Object({
  declaration: Type.Union([
    Type.Literal('shared'),
    Type.Literal('declined'),
    Type.Literal('unavailable'),
    Type.Literal('expired'),
  ]),
  lowerBound: Type.Union([Type.Integer({ minimum: 0, maximum: 120 }), Type.Null()]),
  policyRequired: Type.Optional(Type.Boolean()),
  policyVersion: Type.String({ minLength: 1, maxLength: 64 }),
}, { $id: 'EvaAdultEligibilityRequestV1', additionalProperties: false })
export type EvaAdultEligibilityRequestV1 = Static<typeof EvaAdultEligibilityRequestV1Schema>

export const EvaRouteSchema = Type.Union([
  Type.Literal('chat'),
  Type.Literal('capture'),
  Type.Literal('navigation'),
  Type.Literal('plan'),
  Type.Literal('planRepair'),
  Type.Literal('fieldSuggestion'),
  Type.Literal('memoryCandidate'),
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

export const EvaRecordKindSchema = Type.Union([
  Type.Literal('task'), Type.Literal('project'), Type.Literal('habit'),
  Type.Literal('tracker'), Type.Literal('routine'), Type.Literal('goal'),
  Type.Literal('journal'), Type.Literal('note'), Type.Literal('knowledgeFolder'),
  Type.Literal('focusSession'), Type.Literal('lifeMoment'), Type.Literal('bodyMetric'),
  Type.Literal('hydration'), Type.Literal('mood'), Type.Literal('sleep'),
  Type.Literal('medication'), Type.Literal('insight'),
], { $id: 'EvaRecordKindV1' })
export type EvaRecordKind = Static<typeof EvaRecordKindSchema>

export const EvaNavigationTargetSchema = Type.Union([
  Type.Literal('home'), Type.Literal('today'), Type.Literal('dayPlan'),
  Type.Literal('weekPlan'), Type.Literal('weeklyReview'), Type.Literal('backlog'),
  Type.Literal('focus'), Type.Literal('habits'), Type.Literal('trackers'),
  Type.Literal('journal'), Type.Literal('notes'), Type.Literal('goals'),
  Type.Literal('routines'), Type.Literal('lifeMoments'), Type.Literal('wellness'),
  Type.Literal('nutrition'), Type.Literal('fasting'), Type.Literal('insights'),
  Type.Literal('settings'), Type.Literal('eva'),
], { $id: 'EvaNavigationTargetV1' })
export type EvaNavigationTarget = Static<typeof EvaNavigationTargetSchema>

export const EvaMessageSchema = Type.Object({
  role: Type.Union([Type.Literal('user'), Type.Literal('assistant')]),
  content: Type.String({ minLength: 1, maxLength: 65_536 }),
}, { additionalProperties: false })
export type EvaMessage = Static<typeof EvaMessageSchema>

/**
 * Context categories.
 *
 * Only the last four are consent-gated. The rest project records the person
 * already sees inside LifeBoard and ride on the same authorization as the
 * request itself, so widening this list does not widen what a grant means — see
 * `sensitiveContextCategories`.
 */
export const EvaContextCategorySchema = Type.Union([
  Type.Literal('planning'),
  Type.Literal('capacity'),
  Type.Literal('goals'),
  Type.Literal('habits'),
  Type.Literal('dayLoop'),
  Type.Literal('retrospective'),
  Type.Literal('calendar'),
  Type.Literal('conversationSummary'),
  Type.Literal('journal'),
  Type.Literal('health'),
  Type.Literal('lifeMoments'),
  Type.Literal('personalMemory'),
  Type.Literal('knowledge'),
])
export type EvaContextCategory = Static<typeof EvaContextCategorySchema>

/** Deny-by-default: adding a category here is what makes it need a grant. */
export const sensitiveContextCategories: ReadonlySet<EvaContextCategory> = new Set<EvaContextCategory>([
  'journal', 'health', 'lifeMoments', 'personalMemory',
])

export const EvaContextSectionSchema = Type.Object({
  category: EvaContextCategorySchema,
  payload: Type.Unknown(),
  metadata: Type.Optional(Type.Object({
    availability: Type.Union([
      Type.Literal('complete'), Type.Literal('partial'), Type.Literal('unavailable'),
    ]),
    availableCount: Type.Optional(Type.Union([Type.Integer({ minimum: 0 }), Type.Null()])),
    includedCount: Type.Optional(Type.Union([Type.Integer({ minimum: 0 }), Type.Null()])),
    partialReasons: Type.Array(Type.String({ minLength: 1, maxLength: 120 }), { maxItems: 16 }),
    sourceIDs: Type.Array(Type.String({ minLength: 1, maxLength: 160 }), { maxItems: 240 }),
    selectionReasons: Type.Optional(Type.Array(EvaContextSelectionReasonSchema, { minItems: 1, maxItems: 5, uniqueItems: true })),
    freshnessAt: Type.Optional(Type.Union([
      Type.String({ pattern: ISODateTimePattern }),
      Type.Null(),
    ])),
  }, { additionalProperties: false })),
}, { additionalProperties: false })

/**
 * The person's own standing instruction to EVA, carried from Settings.
 *
 * This is **user-authored text, not developer authority**. It reaches the model
 * inside the developer message so that tone and working style actually take
 * effect, but framed as a stated preference that cannot loosen policy, and it is
 * moderated with the rest of the input. Length is capped here rather than on the
 * client so a modified client cannot buy itself a larger instruction budget.
 */
export const EvaUserInstructionsSchema = Type.Object({
  persona: Type.String({ maxLength: 2_000 }),
  tone: Type.Optional(Type.String({ maxLength: 200 })),
}, { additionalProperties: false })
export type EvaUserInstructions = Static<typeof EvaUserInstructionsSchema>

/**
 * One schema accepts both contract versions.
 *
 * A v1 client simply never sends `userInstructions` and never names a category
 * outside the original five, so forking the schema would buy nothing but a
 * second code path through admission control. `contractVersion` still travels
 * because the prompt layer reads it: only a v2 request may carry user
 * instructions into the developer message.
 */
export const EvaInferenceRequestSchema = Type.Object({
  requestId: EvaUUIDSchema,
  route: EvaRouteSchema,
  contractVersion: Type.Union([Type.Literal(1), Type.Literal(2), Type.Literal(3), Type.Literal(4)]),
  locale: Type.String({ minLength: 2, maxLength: 64 }),
  timeZone: Type.String({ minLength: 1, maxLength: 128 }),
  turnContext: Type.Optional(EvaTurnContextSchema),
  messages: Type.Array(EvaMessageSchema, { minItems: 1, maxItems: 64 }),
  // One section per category, so the cap is the category count.
  context: Type.Array(EvaContextSectionSchema, { maxItems: 13 }),
  userInstructions: Type.Optional(EvaUserInstructionsSchema),
  clientVersion: Type.String({ minLength: 1, maxLength: 64 }),
  platform: EvaPlatformSchema,
  installationId: EvaUUIDSchema,
  consentRevision: Type.Integer({ minimum: 0 }),
  providerCapabilities: Type.Object({
    streaming: Type.Boolean(),
    structuredOutput: Type.Boolean(),
    spokenOutput: Type.Boolean(),
  }, { additionalProperties: false }),
}, { $id: 'EvaInferenceRequestV4', additionalProperties: false })
export type EvaInferenceRequest = Static<typeof EvaInferenceRequestSchema>

/** @deprecated Retained so existing imports keep resolving; accepts v1 and v2. */
export const EvaInferenceRequestV1Schema = EvaInferenceRequestSchema
/** @deprecated Use `EvaInferenceRequest`. */
export type EvaInferenceRequestV1 = EvaInferenceRequest

export const EvaCreditStateSchema = Type.Object({
  balance: Type.Integer({ minimum: 0 }),
  capacity: Type.Integer({ minimum: 1 }),
  refillAmount: Type.Integer({ minimum: 1 }),
  nextRefillAt: Type.String({ pattern: ISODateTimePattern }),
}, { additionalProperties: false })
export type EvaCreditState = Static<typeof EvaCreditStateSchema>

export const EvaQuotaStateV1Schema = Type.Object({
  limit: Type.Integer({ minimum: 1 }),
  used: Type.Integer({ minimum: 0 }),
  remaining: Type.Integer({ minimum: 0 }),
  windowSeconds: Type.Integer({ minimum: 60 }),
  nextAvailableAt: Type.Union([Type.String({ pattern: ISODateTimePattern }), Type.Null()]),
}, { $id: 'EvaQuotaStateV1', additionalProperties: false })
export type EvaQuotaStateV1 = Static<typeof EvaQuotaStateV1Schema>

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
  Type.Literal('daily_quota_exhausted'),
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
  quota: Type.Optional(EvaQuotaStateV1Schema),
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
    quota: Type.Optional(EvaQuotaStateV1Schema),
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
    quota: Type.Optional(EvaQuotaStateV1Schema),
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
  grants: Type.Array(EvaConsentGrantSchema, { uniqueItems: true }),
  reviewRequired: Type.Optional(Type.Boolean()),
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
export * from './context.js'
