import { Type } from '@sinclair/typebox'
import { Hono } from 'hono'
import type { AppVariables, Env, SessionPrincipal } from '../environment.js'
import { readJson } from '../http/body.js'
import { EvaHttpError } from '../http/errors.js'
import { durableJson, durableObjectStub } from '../durable-objects/helpers.js'
import { accountStub } from '../durable-objects/account-client.js'
import { encryptString, hmacSha256, sha256 } from '../security/crypto.js'
import { exchangeAppleAuthorizationCode, verifyAppleAccountEvent, verifyAppleIdentityToken } from './apple.js'
import { verifyCatalystAppTransaction } from './app-transaction.js'
import { requireSession } from './middleware.js'
import { accessTokenExpiresAt, issueAccessToken, newRefreshToken } from './session.js'

const ChallengeRequestSchema = Type.Object({
  purpose: Type.Optional(Type.Union([Type.Literal('signIn'), Type.Literal('reauthenticate')])),
}, { additionalProperties: false })

const AppleExchangeSchema = Type.Object({
  challengeId: Type.String({ format: 'uuid' }),
  nonce: Type.String({ minLength: 20, maxLength: 256 }),
  identityToken: Type.String({ minLength: 20 }),
  authorizationCode: Type.String({ minLength: 1 }),
  installationId: Type.String({ format: 'uuid' }),
  platform: Type.Union([Type.Literal('ios'), Type.Literal('catalyst')]),
  signedAppTransaction: Type.Optional(Type.String({ minLength: 20, maxLength: 65_536 })),
}, { additionalProperties: false })

const RefreshSchema = Type.Object({
  accountId: Type.String({ minLength: 20, maxLength: 128 }),
  familyId: Type.String({ format: 'uuid' }),
  refreshToken: Type.String({ minLength: 32 }),
  installationId: Type.String({ format: 'uuid' }),
  platform: Type.Union([Type.Literal('ios'), Type.Literal('catalyst')]),
}, { additionalProperties: false })

export const authRoutes = new Hono<{ Bindings: Env; Variables: AppVariables }>()

authRoutes.post('/challenge', async (context) => {
  const body = await readJson<{ purpose?: 'signIn' | 'reauthenticate' }>(context.req.raw, ChallengeRequestSchema)
  const challengeId = crypto.randomUUID()
  const stub = durableObjectStub(context.env.AUTH_CHALLENGES, challengeId)
  const challenge = await durableJson<{ nonce: string; expiresAt: string }>(stub, '/issue', {
    method: 'POST',
    body: JSON.stringify({ purpose: body.purpose ?? 'signIn', ttlSeconds: 300 }),
  })
  return context.json({ challengeId, ...challenge })
})

authRoutes.post('/apple/exchange', async (context) => {
  const body = await readJson<{
    challengeId: string
    nonce: string
    identityToken: string
    authorizationCode: string
    installationId: string
    platform: 'ios' | 'catalyst'
    signedAppTransaction?: string
  }>(context.req.raw, AppleExchangeSchema)
  const challenge = durableObjectStub(context.env.AUTH_CHALLENGES, body.challengeId)
  try {
    await durableJson(challenge, '/consume', {
      method: 'POST',
      body: JSON.stringify({ purpose: 'signIn', nonce: body.nonce }),
    })
  } catch {
    throw new EvaHttpError(409, 'unauthenticated', 'The sign-in request expired. Try again.', {
      recoveryAction: 'signIn',
    })
  }

  let identity: Awaited<ReturnType<typeof verifyAppleIdentityToken>>
  try {
    identity = await verifyAppleIdentityToken(context.env, body.identityToken, body.nonce)
  } catch {
    throw new EvaHttpError(401, 'unauthenticated', 'Apple sign-in could not be verified.', {
      recoveryAction: 'signIn',
    })
  }

  let catalystRisk: Awaited<ReturnType<typeof verifyCatalystAppTransaction>> | undefined
  if (body.platform === 'catalyst') {
    try {
      catalystRisk = await verifyCatalystAppTransaction(context.env, body.signedAppTransaction)
    } catch {
      throw new EvaHttpError(401, 'attestation_required', 'This Mac could not be verified for Cloud EVA.', {
        recoveryAction: 'signIn',
      })
    }
  }

  let appleTokens: Awaited<ReturnType<typeof exchangeAppleAuthorizationCode>>
  try {
    appleTokens = await exchangeAppleAuthorizationCode(
      context.env,
      body.authorizationCode,
      identity.audience,
    )
  } catch {
    throw new EvaHttpError(401, 'unauthenticated', 'Apple sign-in could not be verified.', {
      recoveryAction: 'signIn',
    })
  }
  if (appleTokens.identity.subject !== identity.subject || appleTokens.identity.audience !== identity.audience) {
    throw new EvaHttpError(401, 'unauthenticated', 'Apple sign-in identities did not match.', {
      recoveryAction: 'signIn',
    })
  }

  const accountId = await hmacSha256(context.env.ACCOUNT_HMAC_KEY, identity.subject)
  const refresh = await newRefreshToken()
  const familyId = crypto.randomUUID()
  const authenticatedAt = Date.now()
  const encryptedAppleRefreshToken = appleTokens.refreshToken
    ? await encryptString(context.env.TOKEN_ENCRYPTION_KEY, appleTokens.refreshToken)
    : undefined
  const bootstrap = await durableJson<{
    created: boolean
    credits: unknown
    consent: unknown
  }>(accountStub(context.env, accountId), '/bootstrap', {
    method: 'POST',
    body: JSON.stringify({
      accountId,
      encryptedAppleRefreshToken,
      appleClientId: identity.audience,
      familyId,
      refreshTokenHash: refresh.hash,
      installationId: body.installationId,
      platform: body.platform,
      catalystRisk: catalystRisk ? {
        appTransactionIdHash: await hmacSha256(
          context.env.ACCOUNT_HMAC_KEY,
          catalystRisk.appTransactionId,
        ),
        receiptEnvironment: catalystRisk.receiptEnvironment,
        originalPlatform: catalystRisk.originalPlatform,
        verifiedAt: authenticatedAt,
      } : undefined,
      authenticatedAt,
      refreshExpiresAt: refresh.expiresAt,
    }),
  })
  const principal: SessionPrincipal = {
    accountId,
    sessionFamilyId: familyId,
    installationId: body.installationId,
    platform: body.platform,
    authenticatedAt,
  }
  return context.json({
    accountId,
    familyId,
    accessToken: await issueAccessToken(context.env, principal),
    accessTokenExpiresAt: accessTokenExpiresAt(),
    refreshToken: refresh.token,
    refreshTokenExpiresAt: new Date(refresh.expiresAt).toISOString(),
    requiresAdultEligibility: true,
    requiresAttestation: body.platform === 'ios',
    created: bootstrap.created,
    credits: bootstrap.credits,
    consent: bootstrap.consent,
  })
})

authRoutes.post('/refresh', async (context) => {
  const body = await readJson<{
    accountId: string
    familyId: string
    refreshToken: string
    installationId: string
    platform: 'ios' | 'catalyst'
  }>(context.req.raw, RefreshSchema)
  const replacement = await newRefreshToken()
  try {
    const rotation = await durableJson<{
      family: { installationId: string; authenticatedAt: number }
      platform: 'ios' | 'catalyst'
    }>(accountStub(context.env, body.accountId), '/refresh/rotate', {
      method: 'POST',
      body: JSON.stringify({
        familyId: body.familyId,
        presentedTokenHash: await sha256(body.refreshToken),
        replacementTokenHash: replacement.hash,
        replacementExpiresAt: replacement.expiresAt,
      }),
    })
    if (rotation.family.installationId !== body.installationId || rotation.platform !== body.platform) {
      throw new Error('Refresh token device binding mismatch.')
    }
    const principal: SessionPrincipal = {
      accountId: body.accountId,
      sessionFamilyId: body.familyId,
      installationId: rotation.family.installationId,
      platform: rotation.platform,
      authenticatedAt: rotation.family.authenticatedAt,
    }
    return context.json({
      accountId: body.accountId,
      accessToken: await issueAccessToken(context.env, principal),
      accessTokenExpiresAt: accessTokenExpiresAt(),
      refreshToken: replacement.token,
      refreshTokenExpiresAt: new Date(replacement.expiresAt).toISOString(),
    })
  } catch {
    throw new EvaHttpError(401, 'session_expired', 'Your EVA session has expired.', {
      recoveryAction: 'signIn',
    })
  }
})

authRoutes.use('/logout', requireSession)
authRoutes.post('/logout', async (context) => {
  const principal = context.get('principal')
  await durableJson(accountStub(context.env, principal.accountId), '/session/revoke', {
    method: 'POST',
    body: JSON.stringify({ familyId: principal.sessionFamilyId }),
  })
  return context.body(null, 204)
})

// Apple sends signed server-to-server events. The full event JWS is retained only
// in memory; the endpoint never logs the token or its claims.
authRoutes.post('/apple/events', async (context) => {
  const body = await context.req.json<unknown>()
  const signedPayload = body && typeof body === 'object' && 'payload' in body ? body.payload : undefined
  if (typeof signedPayload !== 'string' || signedPayload.length < 20) {
    throw new EvaHttpError(400, 'schema_invalid', 'The Apple event is malformed.')
  }
  let event: Awaited<ReturnType<typeof verifyAppleAccountEvent>>
  try {
    event = await verifyAppleAccountEvent(context.env, signedPayload)
    await durableJson(durableObjectStub(context.env.AUTH_CHALLENGES, `apple-event:${event.jti}`), '/mark-once', {
      method: 'POST',
    })
  } catch {
    throw new EvaHttpError(401, 'unauthenticated', 'The Apple account event could not be verified.')
  }
  const accountId = await hmacSha256(context.env.ACCOUNT_HMAC_KEY, event.subject)
  if (event.type === 'consent-revoked') {
    await durableJson(accountStub(context.env, accountId), '/apple/revoke', { method: 'POST' }).catch(() => undefined)
  } else if (event.type === 'account-deleted') {
    await durableJson(accountStub(context.env, accountId), '/account', { method: 'DELETE' }).catch(() => undefined)
  }
  context.env.EVA_ANALYTICS.writeDataPoint({
    blobs: ['apple_account_event_received', event.type, context.env.ENVIRONMENT],
    indexes: [accountId],
  })
  return context.json({ accepted: true })
})
