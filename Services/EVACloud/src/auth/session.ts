import { importJWK, jwtVerify, SignJWT } from 'jose'
import type { Env, SessionPrincipal } from '../environment.js'
import { parsePrivateJwk, publicJwk, randomToken, sha256 } from '../security/crypto.js'

const accessLifetimeSeconds = 15 * 60
const refreshLifetimeSeconds = 30 * 24 * 60 * 60

async function signingKey(env: Env): Promise<CryptoKey> {
  return importJWK(parsePrivateJwk(env.SESSION_SIGNING_PRIVATE_KEY), 'EdDSA') as Promise<CryptoKey>
}

async function verificationKey(env: Env): Promise<CryptoKey> {
  return importJWK(publicJwk(parsePrivateJwk(env.SESSION_SIGNING_PRIVATE_KEY)), 'EdDSA') as Promise<CryptoKey>
}

export async function issueAccessToken(env: Env, principal: SessionPrincipal): Promise<string> {
  const now = Math.floor(Date.now() / 1_000)
  return new SignJWT({
    sid: principal.sessionFamilyId,
    installation_id: principal.installationId,
    platform: principal.platform,
      auth_time: Math.floor(principal.authenticatedAt / 1_000),
      identity_kind: principal.identityKind,
  })
    .setProtectedHeader({ alg: 'EdDSA', kid: 'eva-session-v1' })
    .setIssuer('https://api.getlifeboard.app')
    .setAudience('lifeboard-eva')
    .setSubject(principal.accountId)
    .setIssuedAt(now)
    .setExpirationTime(now + accessLifetimeSeconds)
    .setJti(crypto.randomUUID())
    .sign(await signingKey(env))
}

export async function verifyAccessToken(env: Env, token: string): Promise<SessionPrincipal> {
  const { payload } = await jwtVerify(token, await verificationKey(env), {
    issuer: 'https://api.getlifeboard.app',
    audience: 'lifeboard-eva',
  })
  if (
    !payload.sub
    || typeof payload.sid !== 'string'
    || typeof payload.installation_id !== 'string'
    || (payload.platform !== 'ios' && payload.platform !== 'catalyst')
    || typeof payload.auth_time !== 'number'
  ) throw new Error('Access token claims are incomplete.')
  return {
    accountId: payload.sub,
    sessionFamilyId: payload.sid,
    installationId: payload.installation_id,
    platform: payload.platform,
    authenticatedAt: payload.auth_time * 1_000,
    identityKind: payload.identity_kind === 'guest' ? 'guest' : 'apple',
  }
}

export async function newRefreshToken(generation = 0): Promise<{
  token: string
  hash: string
  expiresAt: number
  generation: number
}> {
  const normalizedGeneration = Math.max(0, Math.floor(generation))
  // The generation is not an authenticator; the random suffix is. Keeping a
  // monotonic value inside the opaque token lets the account DO recognize an
  // arbitrarily old exact-token replay without retaining thousands of hashes.
  const token = `r1.${normalizedGeneration}.${randomToken(48)}`
  return {
    token,
    hash: await sha256(token),
    expiresAt: Date.now() + refreshLifetimeSeconds * 1_000,
    generation: normalizedGeneration,
  }
}

export function refreshTokenGeneration(token: string): number | undefined {
  const match = /^r1\.(\d{1,6})\.[A-Za-z0-9_-]{32,}$/u.exec(token)
  if (!match?.[1]) return undefined
  const value = Number(match[1])
  return Number.isSafeInteger(value) ? value : undefined
}

export function accessTokenExpiresAt(): string {
  return new Date(Date.now() + accessLifetimeSeconds * 1_000).toISOString()
}
