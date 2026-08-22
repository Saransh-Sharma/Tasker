import { type Static, Type } from '@sinclair/typebox'
import { Value } from '@sinclair/typebox/value'
import { CompactSign, importJWK } from 'jose'
import type { EvaRoute } from '@lifeboard/eva-contracts'
import type { Env } from '../environment.js'
import { parsePrivateJwk } from '../security/crypto.js'

const ISODateTimePattern = '^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}(?:\\.\\d+)?(?:Z|[+-]\\d{2}:\\d{2})$'

export interface EvaRoutePolicy {
  enabled: boolean
  inputTokenCap: number
  outputTokenCap: number
  reasoning: 'none' | 'low' | 'medium'
  billable: boolean
  structured: boolean
}

const RoutePolicySchema = Type.Object({
  enabled: Type.Boolean(),
  inputTokenCap: Type.Integer({ minimum: 256, maximum: 64_000 }),
  outputTokenCap: Type.Integer({ minimum: 64, maximum: 8_192 }),
  reasoning: Type.Union([Type.Literal('none'), Type.Literal('low'), Type.Literal('medium')]),
  billable: Type.Boolean(),
  structured: Type.Boolean(),
}, { additionalProperties: false })

const routes = [
  'chat', 'capture', 'navigation', 'plan', 'planRepair', 'fieldSuggestion', 'topThree', 'taskBreakdown', 'dailyBrief',
  'universalInputClassification', 'dynamicChips', 'journalAnswer', 'knowledgeAnswer',
  'shortcutsAnswer', 'debugSmoke', 'memoryCandidate',
] as const satisfies readonly EvaRoute[]

const RoutesSchema = Type.Object(Object.fromEntries(routes.map((name) => [name, RoutePolicySchema])), {
  additionalProperties: false,
})

export const EvaRuntimeConfigSchema = Type.Object({
  schemaVersion: Type.Literal(2),
  version: Type.Integer({ minimum: 0 }),
  issuedAt: Type.String({ pattern: ISODateTimePattern }),
  environment: Type.Union([Type.Literal('development'), Type.Literal('staging'), Type.Literal('production')]),
  cloudState: Type.Union([Type.Literal('enabled'), Type.Literal('degraded'), Type.Literal('disabled')]),
  ttsEnabled: Type.Boolean(),
  maintenanceMessage: Type.Union([Type.String({ minLength: 1, maxLength: 280 }), Type.Null()]),
  offlineRecoveryPolicy: Type.Literal('offerTryOffline'),
  textModel: Type.Literal('gpt-5.6-luna'),
  speechModel: Type.Literal('tts-1'),
  speechVoice: Type.Literal('nova'),
  minimumClientVersion: Type.String({ minLength: 1, maxLength: 64 }),
  contractVersions: Type.Tuple([Type.Literal(1), Type.Literal(2), Type.Literal(3), Type.Literal(4)]),
  appRuntime: Type.Object({
    onboardingLifeWeaveV6Enabled: Type.Boolean(),
    existingUserRefreshVersion: Type.Integer({ minimum: 1, maximum: 100 }),
    existingUserRefreshEnabled: Type.Boolean(),
    productEventsEnabled: Type.Boolean(),
  }, { additionalProperties: false }),
  guestAccess: Type.Optional(Type.Object({
    bootstrapEnabled: Type.Boolean(),
    inferenceEnabled: Type.Boolean(),
    appleLinkingEnabled: Type.Boolean(),
    rolloutPercent: Type.Integer({ minimum: 0, maximum: 100 }),
  }, { additionalProperties: false })),
  usagePolicy: Type.Optional(Type.Object({
    billableLimit: Type.Integer({ minimum: 1, maximum: 100 }),
    helperLimit: Type.Integer({ minimum: 1, maximum: 1_000 }),
    rollingWindowSeconds: Type.Integer({ minimum: 3_600, maximum: 604_800 }),
  }, { additionalProperties: false })),
  agePolicy: Type.Optional(Type.Object({
    minimumAge: Type.Literal(13),
    unknownAgeAllowed: Type.Boolean(),
    requiredRegionFailClosed: Type.Boolean(),
  }, { additionalProperties: false })),
  creditPolicy: Type.Object({
    initial: Type.Literal(100),
    capacity: Type.Literal(100),
    refillAmount: Type.Literal(20),
    refillPeriodSeconds: Type.Literal(86_400),
  }, { additionalProperties: false }),
  priceSchedule: Type.Object({
    version: Type.String({ minLength: 1, maxLength: 64 }),
    effectiveAt: Type.String({ pattern: ISODateTimePattern }),
    approved: Type.Boolean(),
    lunaInputMicroUsdPerMillion: Type.Integer({ minimum: 0 }),
    lunaCachedInputMicroUsdPerMillion: Type.Integer({ minimum: 0 }),
    lunaCacheWriteMicroUsdPerMillion: Type.Integer({ minimum: 0 }),
    lunaOutputMicroUsdPerMillion: Type.Integer({ minimum: 0 }),
    moderationMicroUsdPerMillion: Type.Integer({ minimum: 0 }),
    ttsMicroUsdPerMillionCharacters: Type.Integer({ minimum: 0 }),
  }, { additionalProperties: false }),
  routes: RoutesSchema,
}, { $id: 'EvaRuntimeConfigurationV2', additionalProperties: false })

export type EvaRuntimeConfig = Static<typeof EvaRuntimeConfigSchema>

/** The server owns this decision. Clients may present regional age UI, but a
 * modified or stale client cannot relax an enabled fail-closed policy. */
export function requiresAgeDecision(config: EvaRuntimeConfig): boolean {
  // A disabled cloud configuration must stay disabled without turning account
  // recovery/deletion screens into an age-verification dead end. Inference
  // routes reject the disabled state before authorization.
  return config.cloudState !== 'disabled' && (
    config.agePolicy?.requiredRegionFailClosed === true
    || config.agePolicy?.unknownAgeAllowed === false
  )
}

const route = (
  inputTokenCap: number,
  outputTokenCap: number,
  reasoning: EvaRoutePolicy['reasoning'],
  billable: boolean,
  structured: boolean,
): EvaRoutePolicy => ({ enabled: false, inputTokenCap, outputTokenCap, reasoning, billable, structured })

/**
 * Safe bootstrap document. It is intentionally disabled and its price schedule
 * is intentionally unapproved. Environments become billable only after a full,
 * validated runtime-config-v2 document is written to KV.
 */
export function failClosedRuntimeConfig(env: Env): EvaRuntimeConfig {
  return {
    schemaVersion: 2,
    version: 0,
    issuedAt: new Date().toISOString(),
    environment: env.ENVIRONMENT,
    cloudState: 'disabled',
    ttsEnabled: false,
    maintenanceMessage: 'Cloud EVA has not been enabled for this environment.',
    offlineRecoveryPolicy: 'offerTryOffline',
    textModel: 'gpt-5.6-luna',
    speechModel: 'tts-1',
    speechVoice: 'nova',
    minimumClientVersion: env.MINIMUM_CLIENT_VERSION,
    contractVersions: [1, 2, 3, 4],
    appRuntime: {
      onboardingLifeWeaveV6Enabled: true,
      existingUserRefreshVersion: 1,
      existingUserRefreshEnabled: true,
      productEventsEnabled: true,
    },
    guestAccess: {
      bootstrapEnabled: false,
      inferenceEnabled: false,
      appleLinkingEnabled: false,
      rolloutPercent: 0,
    },
    usagePolicy: { billableLimit: 20, helperLimit: 100, rollingWindowSeconds: 86_400 },
    agePolicy: { minimumAge: 13, unknownAgeAllowed: true, requiredRegionFailClosed: true },
    creditPolicy: { initial: 100, capacity: 100, refillAmount: 20, refillPeriodSeconds: 86_400 },
    // Values mirror the official model pages fetched on 2026-08-16, but stay
    // unapproved until checked against the actual OpenAI project billing page.
    priceSchedule: {
      version: 'openai-2026-08-16-unverified',
      effectiveAt: '2026-08-16T00:00:00.000Z',
      approved: false,
      lunaInputMicroUsdPerMillion: 200_000,
      lunaCachedInputMicroUsdPerMillion: 20_000,
      lunaCacheWriteMicroUsdPerMillion: 250_000,
      lunaOutputMicroUsdPerMillion: 1_200_000,
      moderationMicroUsdPerMillion: 0,
      ttsMicroUsdPerMillionCharacters: 15_000_000,
    },
    routes: {
      // Chat and the daily brief both weigh capacity against ambition, which is
      // reasoning work rather than retrieval; 'low' was chosen when the client
      // could only send ~1,500 tokens and there was nothing to reason over.
      chat: route(16_000, 2_048, 'medium', true, false),
      capture: route(8_000, 1_200, 'low', true, true),
      navigation: route(4_000, 512, 'none', false, true),
      plan: route(32_000, 4_096, 'medium', true, true),
      planRepair: route(32_000, 4_096, 'low', false, true),
      fieldSuggestion: route(8_000, 1_200, 'low', false, true),
      memoryCandidate: route(2_000, 320, 'none', false, true),
      topThree: route(8_000, 1_200, 'low', true, true),
      taskBreakdown: route(8_000, 1_200, 'low', true, true),
      dailyBrief: route(16_000, 1_600, 'medium', true, true),
      universalInputClassification: route(2_000, 512, 'none', false, true),
      dynamicChips: route(2_000, 512, 'none', false, true),
      journalAnswer: route(16_000, 1_600, 'low', true, false),
      knowledgeAnswer: route(16_000, 1_600, 'low', true, false),
      shortcutsAnswer: route(8_000, 1_200, 'low', true, false),
      debugSmoke: route(2_000, 256, 'none', false, false),
    },
  }
}

export async function runtimeConfig(env: Env): Promise<EvaRuntimeConfig> {
  const fallback = failClosedRuntimeConfig(env)
  const value = await env.EVA_CONFIG.get('runtime-config-v2', 'json')
  if (!Value.Check(EvaRuntimeConfigSchema, value)) return fallback
  const config = value as EvaRuntimeConfig
  if (config.environment !== env.ENVIRONMENT) return fallback
  if (config.version < Number(env.MIN_RUNTIME_CONFIG_VERSION)) return fallback
  const issuedAt = Date.parse(config.issuedAt)
  if (!Number.isFinite(issuedAt) || issuedAt > Date.now() + 5 * 60 * 1_000) {
    return fallback
  }
  if (config.cloudState !== 'disabled' && !config.priceSchedule.approved) return fallback
  if (config.ttsEnabled && config.cloudState === 'disabled') return fallback
  // KV contains the durable policy revision. `issuedAt` describes the signed
  // response delivered to clients, so refresh it whenever the Worker signs the
  // policy. Otherwise an intentionally persistent enabled policy expires after
  // seven days and silently disables every client.
  return { ...config, issuedAt: new Date().toISOString() }
}

export async function signedRuntimeConfig(env: Env): Promise<string> {
  const config = await runtimeConfig(env)
  const payload = new TextEncoder().encode(JSON.stringify(config))
  const key = await importJWK(parsePrivateJwk(env.CONFIG_SIGNING_PRIVATE_KEY), 'EdDSA')
  return new CompactSign(payload)
    .setProtectedHeader({ alg: 'EdDSA', kid: 'eva-config-v2', typ: 'JWT' })
    .sign(key)
}
