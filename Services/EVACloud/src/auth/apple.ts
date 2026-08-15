import { createRemoteJWKSet, importPKCS8, jwtVerify, SignJWT } from 'jose'
import type { Env } from '../environment.js'
import { sha256 } from '../security/crypto.js'

const appleIssuer = 'https://appleid.apple.com'
const appleKeys = createRemoteJWKSet(new URL('https://appleid.apple.com/auth/keys'))

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
  const { payload } = await jwtVerify(identityToken, appleKeys, {
    issuer: appleIssuer,
    audience: audiences,
  })
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
  const key = await importPKCS8(env.APPLE_PRIVATE_KEY_P8.replaceAll('\\n', '\n'), 'ES256')
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
  const response = await fetch('https://appleid.apple.com/auth/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'authorization_code',
      code: authorizationCode,
      client_id: clientId,
      client_secret: await appleClientSecret(env, clientId),
    }),
  })
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
  const response = await fetch('https://appleid.apple.com/auth/revoke', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      token: refreshToken,
      token_type_hint: 'refresh_token',
      client_id: clientId,
      client_secret: await appleClientSecret(env, clientId),
    }),
  })
  if (!response.ok) throw new Error('Apple token revocation failed.')
}
