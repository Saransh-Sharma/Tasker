import { decodeProtectedHeader, exportPKCS8, generateKeyPair } from 'jose'
import { afterEach, beforeAll, describe, expect, it, vi } from 'vitest'
import {
  deviceCheckBaseURL,
  markDeviceCheckGuestBootstrap,
  queryDeviceCheckRisk,
} from '../src/attestation/device-check.js'
import type { Env } from '../src/environment.js'

let signingKeyPem: string

beforeAll(async () => {
  const { privateKey } = await generateKeyPair('ES256', { extractable: true })
  signingKeyPem = await exportPKCS8(privateKey)
})

afterEach(() => vi.unstubAllGlobals())

function fixtureEnvironment(environment: Env['APP_ATTEST_ENVIRONMENT']): Env {
  return {
    APP_ATTEST_ENVIRONMENT: environment,
    APPLE_TEAM_ID: 'TEAM123456',
    APPLE_DEVICECHECK_KEY_ID: 'DEVICEKEY1',
    APPLE_DEVICECHECK_PRIVATE_KEY_P8: signingKeyPem,
    // These deliberately differ so a regression to the Sign in with Apple key
    // is observable in the JWT header.
    APPLE_KEY_ID: 'SIGNINKEY1',
    APPLE_PRIVATE_KEY_P8: 'not-a-device-check-key',
  } as Env
}

describe('DeviceCheck server integration', () => {
  it('selects the Apple endpoint that matches the configured evidence environment', () => {
    expect(deviceCheckBaseURL(fixtureEnvironment('development')))
      .toBe('https://api.development.devicecheck.apple.com')
    expect(deviceCheckBaseURL(fixtureEnvironment('production')))
      .toBe('https://api.devicecheck.apple.com')
  })

  it('uses the dedicated DeviceCheck key and preserves bit 1 when marking bootstrap', async () => {
    const calls: Request[] = []
    vi.stubGlobal('fetch', vi.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
      const request = new Request(input, init)
      calls.push(request)
      if (request.url.endsWith('/query_two_bits')) {
        return Response.json({ bit0: false, bit1: true, last_update_time: '2026-08-20T00:00:00Z' })
      }
      return new Response(null, { status: 200 })
    }))

    const environment = fixtureEnvironment('development')
    const observed = await queryDeviceCheckRisk(environment, 'opaque-device-token')
    expect(observed).toMatchObject({ bit0: false, bit1: true })
    expect(calls[0]?.url).toBe('https://api.development.devicecheck.apple.com/v1/query_two_bits')

    const authorization = calls[0]?.headers.get('Authorization') ?? ''
    expect(decodeProtectedHeader(authorization.replace('Bearer ', '')).kid).toBe('DEVICEKEY1')

    await markDeviceCheckGuestBootstrap(environment, 'opaque-device-token', observed!)
    expect(calls[1]?.url).toBe('https://api.development.devicecheck.apple.com/v1/update_two_bits')
    await expect(calls[1]?.json()).resolves.toMatchObject({ bit0: true, bit1: true })
  })

  it('remains advisory when Apple or key configuration is unavailable', async () => {
    vi.stubGlobal('fetch', vi.fn().mockRejectedValue(new Error('network unavailable')))
    await expect(queryDeviceCheckRisk(
      {
        ...fixtureEnvironment('production'),
        APPLE_DEVICECHECK_KEY_ID: 'DEVICEKEY2',
        APPLE_DEVICECHECK_PRIVATE_KEY_P8: 'invalid',
      },
      'opaque-device-token',
    )).resolves.toBeUndefined()
  })

  it('skips advisory lookup when DeviceCheck credentials are not configured', async () => {
    const fetch = vi.fn()
    vi.stubGlobal('fetch', fetch)
    const environment = fixtureEnvironment('production')
    environment.APPLE_DEVICECHECK_KEY_ID = undefined
    environment.APPLE_DEVICECHECK_PRIVATE_KEY_P8 = undefined

    await expect(queryDeviceCheckRisk(environment, 'opaque-device-token')).resolves.toBeUndefined()
    expect(fetch).not.toHaveBeenCalled()
  })
})
