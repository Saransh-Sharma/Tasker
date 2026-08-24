import { env } from 'cloudflare:test'
import { Value } from '@sinclair/typebox/value'
import { afterEach, describe, expect, it } from 'vitest'
import productionPolicy from '../config/runtime-config.production.json'
import stagingPolicy from '../config/runtime-config.staging.json'
import type { Env } from '../src/environment.js'
import {
  EvaRuntimeConfigSchema,
  failClosedRuntimeConfig,
  requiresAgeDecision,
  runtimeConfig,
} from '../src/config/runtime-config.js'

const bindings = env as unknown as Env
const supportedProductionRoutes = [
  'chat', 'capture', 'navigation', 'plan', 'planRepair', 'fieldSuggestion', 'memoryCandidate', 'topThree',
  'taskBreakdown', 'dailyBrief', 'universalInputClassification', 'dynamicChips', 'journalAnswer',
  'knowledgeAnswer', 'shortcutsAnswer',
] as const

describe.sequential('signed runtime configuration source', () => {
  afterEach(async () => bindings.EVA_CONFIG.delete('runtime-config-v2'))

  it('fails closed when KV is missing or malformed', async () => {
    await expect(runtimeConfig(bindings)).resolves.toMatchObject({ version: 0, cloudState: 'disabled', ttsEnabled: false })
    await bindings.EVA_CONFIG.put('runtime-config-v2', JSON.stringify({ cloudState: 'enabled' }))
    await expect(runtimeConfig(bindings)).resolves.toMatchObject({ version: 0, cloudState: 'disabled', ttsEnabled: false })
  })

  it('does not turn a disabled cloud into an age-verification dead end', () => {
    const disabled = failClosedRuntimeConfig(bindings)
    expect(disabled.agePolicy?.requiredRegionFailClosed).toBe(true)
    expect(requiresAgeDecision(disabled)).toBe(false)

    disabled.cloudState = 'enabled'
    expect(requiresAgeDecision(disabled)).toBe(true)
  })

  it('rejects future, rolled-back, and unapproved enabled documents', async () => {
    const candidate = failClosedRuntimeConfig(bindings)
    candidate.version = 1
    candidate.cloudState = 'enabled'
    candidate.routes.chat!.enabled = true

    candidate.issuedAt = new Date(Date.now() + 10 * 60_000).toISOString()
    candidate.priceSchedule.approved = true
    await bindings.EVA_CONFIG.put('runtime-config-v2', JSON.stringify(candidate))
    await expect(runtimeConfig(bindings)).resolves.toMatchObject({ version: 0, cloudState: 'disabled' })

    candidate.issuedAt = new Date().toISOString()
    candidate.version = 0
    await bindings.EVA_CONFIG.put('runtime-config-v2', JSON.stringify(candidate))
    await expect(runtimeConfig(bindings)).resolves.toMatchObject({ version: 0, cloudState: 'disabled' })

    candidate.version = 1
    candidate.priceSchedule.approved = false
    await bindings.EVA_CONFIG.put('runtime-config-v2', JSON.stringify(candidate))
    await expect(runtimeConfig(bindings)).resolves.toMatchObject({ version: 0, cloudState: 'disabled' })
  })

  it('reissues a persisted policy with a current signed-document timestamp', async () => {
    const candidate = failClosedRuntimeConfig(bindings)
    candidate.version = 1
    candidate.issuedAt = new Date(Date.now() - 30 * 86_400_000).toISOString()
    candidate.cloudState = 'enabled'
    candidate.routes.chat!.enabled = true
    candidate.priceSchedule.approved = true
    await bindings.EVA_CONFIG.put('runtime-config-v2', JSON.stringify(candidate))

    const result = await runtimeConfig(bindings)

    expect(result).toMatchObject({ version: 1, cloudState: 'enabled' })
    expect(Date.parse(result.issuedAt)).toBeGreaterThan(Date.now() - 60_000)
  })

  it('accepts a current approved environment-matched document', async () => {
    const candidate = failClosedRuntimeConfig(bindings)
    candidate.version = 1
    candidate.issuedAt = new Date().toISOString()
    candidate.cloudState = 'enabled'
    candidate.routes.chat!.enabled = true
    candidate.priceSchedule.approved = true
    await bindings.EVA_CONFIG.put('runtime-config-v2', JSON.stringify(candidate))
    await expect(runtimeConfig(bindings)).resolves.toMatchObject({
      version: 1,
      cloudState: 'enabled',
      appRuntime: {
        onboardingLifeWeaveV6Enabled: true,
        existingUserRefreshVersion: 1,
        existingUserRefreshEnabled: true,
        productEventsEnabled: true,
      },
    })
  })
})

describe('versioned runtime policies', () => {
  it.each([
    ['staging', stagingPolicy],
    ['production', productionPolicy],
  ] as const)('%s policy matches schema v2 and enables the supported product', (environment, policy) => {
    expect(Value.Check(EvaRuntimeConfigSchema, policy)).toBe(true)
    expect(policy.environment).toBe(environment)
    expect(policy.cloudState).toBe('enabled')
    expect(policy.ttsEnabled).toBe(true)
    expect(policy.contractVersions).toEqual([1, 2, 3, 4])
    expect(policy.priceSchedule).toMatchObject({
      approved: true,
      lunaInputMicroUsdPerMillion: 200_000,
      lunaCachedInputMicroUsdPerMillion: 20_000,
      lunaCacheWriteMicroUsdPerMillion: 250_000,
      lunaOutputMicroUsdPerMillion: 1_200_000,
      ttsMicroUsdPerMillionCharacters: 15_000_000,
    })
    expect(policy.guestAccess).toMatchObject({
      bootstrapEnabled: true,
      inferenceEnabled: true,
      appleLinkingEnabled: true,
      rolloutPercent: 100,
    })
    expect(policy.appRuntime).toMatchObject({
      productEventsEnabled: true,
      evaMakeItFitTodayV1Enabled: true,
      evaFrictionDetectiveV1Enabled: true,
      evaWeeklyResetV1Enabled: true,
    })
    for (const route of supportedProductionRoutes) {
      expect(policy.routes[route].enabled, `${environment}.${route}`).toBe(true)
    }
  })

  it('keeps the debug smoke route staging-only', () => {
    expect(stagingPolicy.routes.debugSmoke.enabled).toBe(true)
    expect(productionPolicy.routes.debugSmoke.enabled).toBe(false)
  })

  it('advances monotonically from the currently deployed policies', () => {
    expect(stagingPolicy.version).toBe(3)
    expect(productionPolicy.version).toBe(2)
  })
})
