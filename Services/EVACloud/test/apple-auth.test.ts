import { exportPKCS8, generateKeyPair } from 'jose'
import { afterEach, beforeAll, describe, expect, it, vi } from 'vitest'
import {
  AppleUpstreamTimeoutError,
  exchangeAppleAuthorizationCode,
  verifyAppleIdentityToken,
} from '../src/auth/apple.js'
import type { Env } from '../src/environment.js'

let signingKeyPem: string

beforeAll(async () => {
  const { privateKey } = await generateKeyPair('ES256', { extractable: true })
  signingKeyPem = await exportPKCS8(privateKey)
})

function fixtureEnvironment(overrides: Partial<Env> = {}): Env {
  return {
    APPLE_TEAM_ID: 'TEAM123456',
    APPLE_KEY_ID: 'KEY1234567',
    APPLE_PRIVATE_KEY_P8: signingKeyPem,
    APPLE_CLIENT_IDS: 'com.example.app',
    ...overrides,
  } as Env
}

/** How `AbortSignal.timeout` surfaces once the deadline passes. */
function timeoutRejection(): DOMException {
  return new DOMException('The operation was aborted due to timeout', 'TimeoutError')
}

afterEach(() => vi.unstubAllGlobals())

describe('Apple upstream timeouts', () => {
  it('reports a timed-out authorization-code exchange as an upstream outage, not a bad credential', async () => {
    vi.stubGlobal('fetch', vi.fn().mockRejectedValue(timeoutRejection()))

    await expect(
      exchangeAppleAuthorizationCode(fixtureEnvironment(), 'apple-authorization-code', 'com.example.app'),
    ).rejects.toBeInstanceOf(AppleUpstreamTimeoutError)
  })

  it('reports an unreachable Apple JWKS endpoint as an upstream outage', async () => {
    vi.stubGlobal('fetch', vi.fn().mockRejectedValue(timeoutRejection()))

    // A syntactically valid but unverifiable token: verification cannot even
    // begin until the signing keys arrive, so the JWKS failure is what surfaces.
    const token = `${btoa('{"alg":"RS256","kid":"abc"}')}.${btoa('{"sub":"user"}')}.signature`
    await expect(
      verifyAppleIdentityToken(fixtureEnvironment(), token, 'raw-nonce'),
    ).rejects.toBeInstanceOf(AppleUpstreamTimeoutError)
  })

  it('still surfaces a genuine Apple rejection as a plain failure', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(
      Response.json({ error: 'invalid_grant' }, { status: 400 }),
    ))

    const failure = exchangeAppleAuthorizationCode(
      fixtureEnvironment(),
      'apple-authorization-code',
      'com.example.app',
    )
    await expect(failure).rejects.toThrow('Apple authorization-code exchange failed.')
    await expect(failure).rejects.not.toBeInstanceOf(AppleUpstreamTimeoutError)
  })

  it('imports the Apple client-secret signing key once across repeated exchanges', async () => {
    const fetchStub = vi.fn().mockResolvedValue(Response.json({ error: 'invalid_grant' }, { status: 400 }))
    vi.stubGlobal('fetch', fetchStub)
    const environment = fixtureEnvironment({ APPLE_KEY_ID: `KEY${crypto.randomUUID().slice(0, 7)}` } as Partial<Env>)
    const importKey = vi.spyOn(crypto.subtle, 'importKey')

    for (let attempt = 0; attempt < 2; attempt += 1) {
      await expect(
        exchangeAppleAuthorizationCode(environment, 'apple-authorization-code', 'com.example.app'),
      ).rejects.toThrow()
    }

    expect(fetchStub).toHaveBeenCalledTimes(2)
    expect(importKey).toHaveBeenCalledTimes(1)
    importKey.mockRestore()
  })
})
