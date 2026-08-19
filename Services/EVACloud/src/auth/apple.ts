import { createRemoteJWKSet, importPKCS8, jwtVerify, SignJWT } from 'jose'
import type { Env } from '../environment.js'
import { sha256 } from '../security/crypto.js'

const appleIssuer = 'https://appleid.apple.com'

/** Ceiling for any single call out to Apple. Well inside the client's own
 *  request budget, so a slow Apple leaves us time to answer with a retryable
 *  error rather than letting the caller time out first and guess why. */
const appleUpstreamTimeoutMs = 8_000
const appleJwksTimeoutMs = 5_000

// Without an explicit timeout, a cold isolate whose JWKS cache is empty can
// spend the entire request budget fetching Apple's signing keys before the
// token exchange has even started.
const appleKeys = createRemoteJWKSet(new URL('https://appleid.apple.com/auth/keys'), {
  timeoutDuration: appleJwksTimeoutMs,
  cooldownDuration: 30_000,
})

/** Raised when Apple did not answer inside `appleUpstreamTimeoutMs`. Distinct
 *  from a verification failure: the user's credential may be perfectly valid,
 *  so the right advice is "try again", not "sign in again". */
export class AppleUpstreamTimeoutError extends Error {
  constructor(readonly endpoint: string) {
    super(`Apple did not respond in time: ${endpoint}`)
    this.name = 'AppleUpstreamTimeoutError'
  }
}

function isTimeout(error: unknown): boolean {
  if (error instanceof DOMException) return error.name === 'TimeoutError' || error.name === 'AbortError'
  // jose surfaces an unreachable JWKS endpoint as its own error code rather than
  // an AbortError. Being unable to reach Apple's keys is an outage on our side
  // of the trust check, never evidence that the user's token is bad.
  return typeof error === 'object' && error !== null && (error as { code?: string }).code === 'ERR_JWKS_TIMEOUT'
}

// `importPKCS8` runs an ASN.1 parse and key import on every call. The key
// material only changes when the secret rotates, which restarts the isolate, so
// one import per isolate is both correct and materially cheaper per exchange.
let cachedClientSecretKey: { keyId: string; key: Promise<Awaited<ReturnType<typeof importPKCS8>>> } | undefined

export interface VerifiedAppleIdentity {
  subject: string
  audience: string
}

export interface VerifiedAppleAccountEvent {
  jti: string
  subject: string
  type: 'email-disabled' | 'email-enabled' | 'consent-revoked' | 'account-deleted'
}

export async function verifyAppleIdentityToken(
  env: Env,
  identityToken: string,
  rawNonce: string,
): Promise<VerifiedAppleIdentity> {
  const audiences = env.APPLE_CLIENT_IDS.split(',').map((value) => value.trim()).filter(Boolean)
  let payload: Awaited<ReturnType<typeof jwtVerify>>['payload']
  try {
    ;({ payload } = await jwtVerify(identityToken, appleKeys, {
      issuer: appleIssuer,
      audience: audiences,
    }))
  } catch (error) {
    if (isTimeout(error)) throw new AppleUpstreamTimeoutError('/auth/keys')
    throw error
  }
  if (!payload.sub || typeof payload.aud !== 'string') throw new Error('Apple identity is incomplete.')
  if (payload.nonce !== await sha256(rawNonce)) throw new Error('Apple identity nonce does not match.')
  return { subject: payload.sub, audience: payload.aud }
}

export async function verifyAppleAccountEvent(env: Env, token: string): Promise<VerifiedAppleAccountEvent> {
  const audiences = [env.APPLE_CLIENT_IDS, env.APPLE_BUNDLE_IDS]
    .flatMap((value) => value.split(','))
    .map((value) => value.trim())
    .filter(Boolean)
  const { payload } = await jwtVerify(token, appleKeys, { issuer: appleIssuer, audience: audiences })
  const events = payload.events
  if (!payload.jti || !events || typeof events !== 'object') throw new Error('Apple event claims are incomplete.')
  const value = events as Record<string, unknown>
  const type = value.type
  if (
    typeof value.sub !== 'string'
    || (type !== 'email-disabled' && type !== 'email-enabled' && type !== 'consent-revoked' && type !== 'account-deleted')
  ) throw new Error('Apple event type is unsupported.')
  return { jti: payload.jti, subject: value.sub, type }
}

async function appleClientSecret(env: Env, clientId: string): Promise<string> {
  if (cachedClientSecretKey?.keyId !== env.APPLE_KEY_ID) {
    cachedClientSecretKey = {
      keyId: env.APPLE_KEY_ID,
      key: importPKCS8(env.APPLE_PRIVATE_KEY_P8.replaceAll('\\n', '\n'), 'ES256'),
    }
  }
  let key: Awaited<ReturnType<typeof importPKCS8>>
  try {
    key = await cachedClientSecretKey.key
  } catch (error) {
    // A rejected promise would otherwise be cached forever, turning one bad
    // import into a permanently broken exchange route.
    cachedClientSecretKey = undefined
    throw error
  }
  const now = Math.floor(Date.now() / 1_000)
  return new SignJWT({})
    .setProtectedHeader({ alg: 'ES256', kid: env.APPLE_KEY_ID })
    .setIssuer(env.APPLE_TEAM_ID)
    .setSubject(clientId)
    .setAudience(appleIssuer)
    .setIssuedAt(now)
    .setExpirationTime(now + 15 * 60)
    .sign(key)
}

export async function exchangeAppleAuthorizationCode(
  env: Env,
  authorizationCode: string,
  clientId: string,
): Promise<{ refreshToken?: string; identity: VerifiedAppleIdentity }> {
  let response: Response
  try {
    response = await fetch('https://appleid.apple.com/auth/token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        grant_type: 'authorization_code',
        code: authorizationCode,
        client_id: clientId,
        client_secret: await appleClientSecret(env, clientId),
      }),
      signal: AbortSignal.timeout(appleUpstreamTimeoutMs),
    })
  } catch (error) {
    if (isTimeout(error)) throw new AppleUpstreamTimeoutError('/auth/token')
    throw error
  }
  const body = await response.json<Record<string, unknown>>()
  if (!response.ok) throw new Error('Apple authorization-code exchange failed.')
  if (typeof body.id_token !== 'string') throw new Error('Apple token exchange omitted identity.')
  const { payload } = await jwtVerify(body.id_token, appleKeys, {
    issuer: appleIssuer,
    audience: clientId,
  })
  if (!payload.sub || typeof payload.aud !== 'string') throw new Error('Apple exchanged identity is incomplete.')
  return {
    refreshToken: typeof body.refresh_token === 'string' ? body.refresh_token : undefined,
    identity: { subject: payload.sub, audience: payload.aud },
  }
}

export async function revokeAppleRefreshToken(env: Env, refreshToken: string, clientId: string): Promise<void> {
  let response: Response
  try {
    response = await fetch('https://appleid.apple.com/auth/revoke', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        token: refreshToken,
        token_type_hint: 'refresh_token',
        client_id: clientId,
        client_secret: await appleClientSecret(env, clientId),
      }),
      signal: AbortSignal.timeout(appleUpstreamTimeoutMs),
    })
  } catch (error) {
    if (isTimeout(error)) throw new AppleUpstreamTimeoutError('/auth/revoke')
    throw error
  }
  if (!response.ok) throw new Error('Apple token revocation failed.')
}
