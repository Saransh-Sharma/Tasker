import { Buffer } from 'node:buffer'
import { afterEach, describe, expect, it, vi } from 'vitest'
import developmentFixture from './fixtures/attestation-development.json'
import productionFixture from './fixtures/attestation-production.json'
import {
  appAttestRequestPayload,
  validateAppAttestAssertion,
  validateAttestationRegistration,
} from '../src/attestation/app-attest.js'
import type { Env } from '../src/environment.js'

const fixtureBundleIdentifier = 'io.uebelacker.AppAttestExample'
const fixtureTeamIdentifier = 'V8H6LQ9448'
const assertionPayload = '{"subject":"Lorem ipsum","message":"Lorem ipsum dolor sit amet, consectetur adipiscing elit."}'
const assertion = 'omlzaWduYXR1cmVYRzBFAiBB8BGAwkmFCg1M5J0mOYEun0SUN1/lse79/7ypG9WiMQIhAIHvqj7eg59B1PMFX1CN4GMGlsgfFtdL30pHCf7G/dNRcWF1dGhlbnRpY2F0b3JEYXRhWCXKPdw7T3iujcFZbHVrHX0mDSMrNms5PzEbrFbQPRA6rEAAAAAB'
const assertionPublicKey = `-----BEGIN PUBLIC KEY-----
MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEg69t2YzgcPTLUx8Zgu+rbcikeaEL
8Ppb+HG0QTIulz8YUB9tgv1pDRruWk87nZC3our56pzIWaqXEbaWyamdzA==
-----END PUBLIC KEY-----
`

function fixtureEnvironment(
  environment: Env['ENVIRONMENT'],
  appAttestEnvironment: Env['APP_ATTEST_ENVIRONMENT'],
  overrides: Partial<Env> = {},
): Env {
  return {
    ENVIRONMENT: environment,
    APP_ATTEST_ENVIRONMENT: appAttestEnvironment,
    APPLE_BUNDLE_IDS: fixtureBundleIdentifier,
    APPLE_TEAM_ID: fixtureTeamIdentifier,
    ...overrides,
  } as Env
}

function fixtureChallenge(value: { challenge: string }): string {
  return Buffer.from(value.challenge, 'base64').toString('utf8')
}

afterEach(() => vi.useRealTimers())

describe('App Attest request binding', () => {
  it('binds an assertion to method, path, one-time challenge, and exact body', async () => {
    const first = await appAttestRequestPayload(new Request('https://eva.test/v1/eva/responses', {
      method: 'POST', body: '{"value":1}',
    }), 'challenge-a')
    const same = await appAttestRequestPayload(new Request('https://another-host.test/v1/eva/responses', {
      method: 'POST', body: '{"value":1}',
    }), 'challenge-a')
    const changedBody = await appAttestRequestPayload(new Request('https://eva.test/v1/eva/responses', {
      method: 'POST', body: '{"value":2}',
    }), 'challenge-a')
    const changedPath = await appAttestRequestPayload(new Request('https://eva.test/v1/eva/speech', {
      method: 'POST', body: '{"value":1}',
    }), 'challenge-a')
    const changedChallenge = await appAttestRequestPayload(new Request('https://eva.test/v1/eva/responses', {
      method: 'POST', body: '{"value":1}',
    }), 'challenge-b')

    expect(first).toBe(same)
    expect(new Set([first, changedBody, changedPath, changedChallenge])).toHaveLength(4)
  })
})

describe('App Attest registration verification', () => {
  it('accepts valid development and production chains only in their configured environment', async () => {
    vi.useFakeTimers()
    vi.setSystemTime(new Date('2024-02-10T00:00:00Z'))

    await expect(validateAttestationRegistration(
      fixtureEnvironment('development', 'development'),
      {
        attestation: developmentFixture.attestation,
        challenge: fixtureChallenge(developmentFixture),
        keyId: developmentFixture.keyId,
      },
    )).resolves.toMatchObject({ keyId: developmentFixture.keyId })
    await expect(validateAttestationRegistration(
      fixtureEnvironment('production', 'production'),
      {
        attestation: productionFixture.attestation,
        challenge: fixtureChallenge(productionFixture),
        keyId: productionFixture.keyId,
      },
    )).resolves.toMatchObject({ keyId: productionFixture.keyId })
    await expect(validateAttestationRegistration(
      fixtureEnvironment('staging', 'development'),
      {
        attestation: productionFixture.attestation,
        challenge: fixtureChallenge(productionFixture),
        keyId: productionFixture.keyId,
      },
    )).rejects.toMatchObject({ code: 'attestation_required' })
  })

  it('rejects expired certificates, development evidence in production, and a damaged chain', async () => {
    await expect(validateAttestationRegistration(
      fixtureEnvironment('development', 'development'),
      {
        attestation: developmentFixture.attestation,
        challenge: fixtureChallenge(developmentFixture),
        keyId: developmentFixture.keyId,
      },
    )).rejects.toMatchObject({ code: 'attestation_required' })

    vi.useFakeTimers()
    vi.setSystemTime(new Date('2024-02-10T00:00:00Z'))
    const damaged = Buffer.from(developmentFixture.attestation, 'base64')
    const damagedIndex = Math.floor(damaged.length / 3)
    damaged[damagedIndex] = (damaged[damagedIndex] ?? 0) ^ 0xff
    for (const input of [
      {
        attestation: developmentFixture.attestation,
        challenge: fixtureChallenge(developmentFixture),
        keyId: developmentFixture.keyId,
      },
      {
        attestation: damaged.toString('base64'),
        challenge: fixtureChallenge(developmentFixture),
        keyId: developmentFixture.keyId,
      },
    ]) {
      await expect(validateAttestationRegistration(
        fixtureEnvironment('production', 'production'),
        input,
      )).rejects.toMatchObject({ code: 'attestation_required' })
    }
  })

  it('rejects the wrong nonce, key identifier, RP ID, and team identifier', async () => {
    vi.useFakeTimers()
    vi.setSystemTime(new Date('2024-02-10T00:00:00Z'))
    const baseline = {
      attestation: developmentFixture.attestation,
      challenge: fixtureChallenge(developmentFixture),
      keyId: developmentFixture.keyId,
    }
    const cases: Array<{ env: Env; input: typeof baseline }> = [
      { env: fixtureEnvironment('development', 'development'), input: { ...baseline, challenge: 'wrong-challenge' } },
      { env: fixtureEnvironment('development', 'development'), input: { ...baseline, keyId: 'wrong-key' } },
      {
        env: fixtureEnvironment('development', 'development', { APPLE_BUNDLE_IDS: 'com.example.attacker' }),
        input: baseline,
      },
      {
        env: fixtureEnvironment('development', 'development', { APPLE_TEAM_ID: 'ATTACKER00' }),
        input: baseline,
      },
    ]
    for (const testCase of cases) {
      await expect(validateAttestationRegistration(testCase.env, testCase.input))
        .rejects.toMatchObject({ code: 'attestation_required' })
    }
  })
})

describe('App Attest assertion verification', () => {
  const environment = fixtureEnvironment('development', 'development')

  it('accepts a valid assertion and advances its counter', () => {
    expect(validateAppAttestAssertion(environment, {
      assertion,
      payload: assertionPayload,
      publicKey: assertionPublicKey,
      previousCounter: 0,
    })).toBe(1)
  })

  it('rejects signature, payload, RP ID, and counter replay attacks', () => {
    const invalidCases = [
      { assertion: `${assertion.slice(0, -2)}AA`, payload: assertionPayload, previousCounter: 0, env: environment },
      { assertion, payload: '{}', previousCounter: 0, env: environment },
      { assertion, payload: assertionPayload, previousCounter: 1, env: environment },
      {
        assertion,
        payload: assertionPayload,
        previousCounter: 0,
        env: fixtureEnvironment('development', 'development', { APPLE_BUNDLE_IDS: 'com.example.attacker' }),
      },
    ]
    for (const testCase of invalidCases) {
      expect(() => validateAppAttestAssertion(testCase.env, {
        assertion: testCase.assertion,
        payload: testCase.payload,
        publicKey: assertionPublicKey,
        previousCounter: testCase.previousCounter,
      })).toThrow()
    }
  })
})
