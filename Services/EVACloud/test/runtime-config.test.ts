import { env } from 'cloudflare:test'
import { afterEach, describe, expect, it } from 'vitest'
import type { Env } from '../src/environment.js'
import { failClosedRuntimeConfig, requiresAgeDecision, runtimeConfig } from '../src/config/runtime-config.js'

const bindings = env as unknown as Env

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
