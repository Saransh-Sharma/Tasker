import {
  type EvaAppleExchangeRequestV1,
  EvaAppleExchangeRequestV1Schema,
  type EvaGuestBootstrapRequestV1,
  EvaGuestBootstrapRequestV1Schema,
  type EvaRefreshRequestV1,
  EvaRefreshRequestV1Schema,
} from '@lifeboard/eva-contracts'
import { Type } from '@sinclair/typebox'
import { Hono } from 'hono'
import type { AppVariables, Env, SessionPrincipal } from '../environment.js'
import { readJson } from '../http/body.js'
import { EvaHttpError } from '../http/errors.js'
import { durableJson, durableObjectStub } from '../durable-objects/helpers.js'
import { accountStub, authorizeAccount } from '../durable-objects/account-client.js'
import { encryptString, hmacSha256, sha256 } from '../security/crypto.js'
import {
  AppleUpstreamTimeoutError,
  exchangeAppleAuthorizationCode,
  verifyAppleAccountEvent,
  verifyAppleIdentityToken,
} from './apple.js'
import { verifyCatalystAppTransaction } from './app-transaction.js'
import { requireSession } from './middleware.js'
import { accessTokenExpiresAt, issueAccessToken, newRefreshToken, refreshTokenGeneration } from './session.js'
import { recordTelemetry } from '../telemetry/events.js'
import { requiresAgeDecision, runtimeConfig } from '../config/runtime-config.js'
import { markDeviceCheckGuestBootstrap, queryDeviceCheckRisk } from '../attestation/device-check.js'
import { guestRolloutBucket } from './guest-rollout.js'

const ChallengeRequestSchema = Type.Object({
  purpose: Type.Optional(Type.Union([Type.Literal('signIn'), Type.Literal('reauthenticate'), Type.Literal('link')])),
}, { additionalProperties: false })

export const authRoutes = new Hono<{ Bindings: Env; Variables: AppVariables }>()

authRoutes.post('/guest/bootstrap', async (context) => {
  const config = await runtimeConfig(context.env)
  const guest = config.guestAccess
  if (!guest?.bootstrapEnabled || guest.rolloutPercent <= 0) {
    throw new EvaHttpError(503, 'configuration_unavailable', 'Guest Cloud EVA is not enabled yet.', {
      recoveryAction: 'tryOffline',
    })
  }
  const body = await readJson<EvaGuestBootstrapRequestV1>(context.req.raw, EvaGuestBootstrapRequestV1Schema)
  const bucket = await guestRolloutBucket(context.env.ACCOUNT_HMAC_KEY, body.bootstrapId)
  if (bucket >= guest.rolloutPercent) {
    throw new EvaHttpError(503, 'configuration_unavailable', 'Guest Cloud EVA is still rolling out.', {
      recoveryAction: 'tryOffline',
    })
  }

  let catalystRisk: Awaited<ReturnType<typeof verifyCatalystAppTransaction>> | undefined
  if (body.platform === 'catalyst' && body.signedAppTransaction) {
    catalystRisk = await verifyCatalystAppTransaction(context.env, body.signedAppTransaction).catch(() => undefined)
  }
  const guestIdentity = await durableJson<{ accountId: string }>(
    authChallengeStub(context.env, body.bootstrapId),
    '/guest-account',
    { method: 'POST' },
  )
  const accountId = guestIdentity.accountId
  const refresh = await newRefreshToken()
  const familyId = crypto.randomUUID()
  const authenticatedAt = Date.now()
  const bootstrap = await durableJson<{
    created: boolean
    identityKind: 'guest'
    trustTier: 'high' | 'low'
    quota: unknown
    credits: unknown
    consent: unknown
  }>(accountStub(context.env, accountId), '/bootstrap', {
    method: 'POST',
    body: JSON.stringify({
      accountId,
      identityKind: 'guest',
      guestBootstrapId: body.bootstrapId.toLowerCase(),
      grants: body.grants,
      quotaPolicy: config.usagePolicy,
      familyId,
      refreshTokenHash: refresh.hash,
      refreshGeneration: refresh.generation,
      installationId: body.installationId,
      platform: body.platform,
      catalystRisk: catalystRisk ? {
        appTransactionIdHash: await hmacSha256(context.env.ACCOUNT_HMAC_KEY, catalystRisk.appTransactionId),
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
    identityKind: 'guest',
  }
  recordTelemetry(context.env, {
    event: 'auth.guest.bootstrap', requestId: context.get('requestId'), accountId,
    status: bootstrap.trustTier,
  })
  if (body.platform === 'ios' && body.deviceCheckToken) {
    context.executionCtx.waitUntil(recordDeviceCheckObservation(
      context.env,
      accountId,
      body.installationId,
      body.deviceCheckToken,
    ))
  }
  return context.json({
    accountId,
    familyId,
    identityKind: 'guest',
    trustTier: bootstrap.trustTier,
    accessToken: await issueAccessToken(context.env, principal),
    accessTokenExpiresAt: accessTokenExpiresAt(),
    refreshToken: refresh.token,
    refreshTokenExpiresAt: new Date(refresh.expiresAt).toISOString(),
    requiresAdultEligibility: requiresAgeDecision(config),
    requiresAttestation: false,
    created: bootstrap.created,
    quota: bootstrap.quota,
    credits: bootstrap.credits,
    consent: bootstrap.consent,
  })
})

async function recordDeviceCheckObservation(
  env: Env,
  accountId: string,
  installationId: string,
  token: string,
): Promise<void> {
  const observed = await queryDeviceCheckRisk(env, token)
  if (!observed) return
  await Promise.allSettled([
    markDeviceCheckGuestBootstrap(env, token, observed),
    accountStub(env, accountId).fetch('https://durable.internal/device/risk', {
      method: 'POST', body: JSON.stringify({ installationId, deviceCheckRisk: observed }),
    }),
  ])
}

authRoutes.post('/challenge', async (context) => {
  const body = await readJson<{ purpose?: 'signIn' | 'reauthenticate' | 'link' }>(context.req.raw, ChallengeRequestSchema)
  const challengeId = crypto.randomUUID()
  const stub = authChallengeStub(context.env, challengeId)
  const challenge = await durableJson<{ nonce: string; expiresAt: string }>(stub, '/issue', {
    method: 'POST',
    body: JSON.stringify({ purpose: body.purpose ?? 'signIn', ttlSeconds: 300 }),
  })
  return context.json({ challengeId, ...challenge })
})

authRoutes.post('/apple/exchange', async (context) => {
  const body = await readJson<EvaAppleExchangeRequestV1>(context.req.raw, EvaAppleExchangeRequestV1Schema)
  const challenge = authChallengeStub(context.env, body.challengeId)
  try {
    await durableJson(challenge, '/consume', {
      method: 'POST',
      body: JSON.stringify({ purpose: 'signIn', nonce: body.nonce }),
    })
  } catch {
    recordAppleExchangeFailure(context.env, context.get('requestId'), 'challenge')
    throw new EvaHttpError(409, 'unauthenticated', 'The sign-in request expired. Try again.', {
      recoveryAction: 'signIn',
    })
  }

  let identity: Awaited<ReturnType<typeof verifyAppleIdentityToken>>
  try {
    identity = await verifyAppleIdentityToken(context.env, body.identityToken, body.nonce)
  } catch (error) {
    if (error instanceof AppleUpstreamTimeoutError) {
      throw appleTimeout(context.env, context.get('requestId'), 'identity_token_timeout')
    }
    recordAppleExchangeFailure(context.env, context.get('requestId'), 'identity_token')
    throw new EvaHttpError(401, 'unauthenticated', 'Apple sign-in could not be verified.', {
      recoveryAction: 'signIn',
    })
  }

  let catalystRisk: Awaited<ReturnType<typeof verifyCatalystAppTransaction>> | undefined
  if (body.platform === 'catalyst') {
    catalystRisk = await verifyCatalystAppTransaction(context.env, body.signedAppTransaction).catch(() => undefined)
  }

  let appleTokens: Awaited<ReturnType<typeof exchangeAppleAuthorizationCode>>
  try {
    appleTokens = await exchangeAppleAuthorizationCode(
      context.env,
      body.authorizationCode,
      identity.audience,
    )
  } catch (error) {
    // A timeout says nothing about the credential — reporting it as
    // "unauthenticated" sends the user back through the Apple sheet to fix a
    // problem that was never theirs.
    if (error instanceof AppleUpstreamTimeoutError) {
      throw appleTimeout(context.env, context.get('requestId'), 'authorization_code_timeout')
    }
    recordAppleExchangeFailure(context.env, context.get('requestId'), 'authorization_code')
    throw new EvaHttpError(401, 'unauthenticated', 'Apple sign-in could not be verified.', {
      recoveryAction: 'signIn',
    })
  }
  if (appleTokens.identity.subject !== identity.subject || appleTokens.identity.audience !== identity.audience) {
    recordAppleExchangeFailure(context.env, context.get('requestId'), 'identity_mismatch')
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
    identityKind: 'apple'
    trustTier: 'high' | 'low'
    quota: unknown
    credits: unknown
    consent: unknown
  }>(accountStub(context.env, accountId), '/bootstrap', {
    method: 'POST',
    body: JSON.stringify({
      accountId,
      identityKind: 'apple',
      encryptedAppleRefreshToken,
      appleClientId: identity.audience,
      familyId,
      refreshTokenHash: refresh.hash,
      refreshGeneration: refresh.generation,
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
  const recoveredMerge = await reconcilePendingGuestLink(context.env, accountId)
  const principal: SessionPrincipal = {
    accountId,
    sessionFamilyId: familyId,
    installationId: body.installationId,
    platform: body.platform,
    authenticatedAt,
    identityKind: 'apple',
  }
  return context.json({
    accountId,
    familyId,
    accessToken: await issueAccessToken(context.env, principal),
    accessTokenExpiresAt: accessTokenExpiresAt(),
    refreshToken: refresh.token,
    refreshTokenExpiresAt: new Date(refresh.expiresAt).toISOString(),
    identityKind: 'apple',
    requiresAdultEligibility: requiresAgeDecision(await runtimeConfig(context.env)),
    requiresAttestation: false,
    created: bootstrap.created,
    trustTier: bootstrap.trustTier,
    requiresConsentReview: recoveredMerge.consent === undefined ? undefined : true,
    quota: recoveredMerge.quota ?? bootstrap.quota,
    credits: recoveredMerge.credits ?? bootstrap.credits,
    consent: recoveredMerge.consent ?? bootstrap.consent,
  })
})

authRoutes.use('/apple/reauthenticate', requireSession)
authRoutes.post('/apple/reauthenticate', async (context) => {
  const principal = context.get('principal')
  if (principal.identityKind !== 'apple') {
    throw new EvaHttpError(409, 'unauthenticated', 'Guest Cloud EVA does not require Apple reauthentication.')
  }
  const session = await authorizeAccount(context.env, principal, {
    requireAdult: false,
    requireAttestation: false,
    allowAgeManagement: true,
  })
  if (!session.authorized) throwAuthorizationFailure(session.reason)

  const body = await readJson<EvaAppleExchangeRequestV1>(context.req.raw, EvaAppleExchangeRequestV1Schema)
  if (body.installationId !== principal.installationId || body.platform !== principal.platform) {
    throw new EvaHttpError(401, 'unauthenticated', 'The Apple verification request does not match this device.')
  }
  try {
    await durableJson(authChallengeStub(context.env, body.challengeId), '/consume', {
      method: 'POST', body: JSON.stringify({ purpose: 'reauthenticate', nonce: body.nonce }),
    })
  } catch {
    throw new EvaHttpError(409, 'unauthenticated', 'The Apple verification request expired. Try again.', {
      recoveryAction: 'signIn',
    })
  }

  let identity: Awaited<ReturnType<typeof verifyAppleIdentityToken>>
  try {
    identity = await verifyAppleIdentityToken(context.env, body.identityToken, body.nonce)
  } catch (error) {
    if (error instanceof AppleUpstreamTimeoutError) {
      throw appleTimeout(context.env, context.get('requestId'), 'reauth_identity_timeout')
    }
    throw new EvaHttpError(401, 'unauthenticated', 'Apple verification could not be completed.', {
      recoveryAction: 'signIn',
    })
  }
  const verifiedAccountId = await hmacSha256(context.env.ACCOUNT_HMAC_KEY, identity.subject)
  if (verifiedAccountId !== principal.accountId) {
    throw new EvaHttpError(409, 'unauthenticated', 'Use the Apple account already linked to this Cloud EVA account.', {
      recoveryAction: 'signIn',
    })
  }

  let appleTokens: Awaited<ReturnType<typeof exchangeAppleAuthorizationCode>>
  try {
    appleTokens = await exchangeAppleAuthorizationCode(context.env, body.authorizationCode, identity.audience)
  } catch (error) {
    if (error instanceof AppleUpstreamTimeoutError) {
      throw appleTimeout(context.env, context.get('requestId'), 'reauth_code_timeout')
    }
    throw new EvaHttpError(401, 'unauthenticated', 'Apple verification could not be completed.', {
      recoveryAction: 'signIn',
    })
  }
  if (appleTokens.identity.subject !== identity.subject || appleTokens.identity.audience !== identity.audience) {
    throw new EvaHttpError(401, 'unauthenticated', 'Apple verification identities did not match.', {
      recoveryAction: 'signIn',
    })
  }

  const authenticatedAt = Date.now()
  const encryptedAppleRefreshToken = appleTokens.refreshToken
    ? await encryptString(context.env.TOKEN_ENCRYPTION_KEY, appleTokens.refreshToken)
    : undefined
  const reauthentication = await accountStub(context.env, principal.accountId).fetch(
    'https://durable.internal/session/reauthenticate',
    {
      method: 'POST',
      body: JSON.stringify({
        familyId: principal.sessionFamilyId,
        installationId: principal.installationId,
        authenticatedAt,
        encryptedAppleRefreshToken,
        appleClientId: identity.audience,
      }),
    },
  ).catch(() => undefined)
  if (!reauthentication || reauthentication.status >= 500) {
    throw new EvaHttpError(503, 'provider_unavailable', 'Apple verification could not be saved yet.', {
      retryable: true, retryAfter: 1, recoveryAction: 'wait',
    })
  }
  if (!reauthentication.ok) {
    throw new EvaHttpError(401, 'session_expired', 'Your EVA session has expired.', {
      recoveryAction: 'signIn',
    })
  }
  const renewedPrincipal: SessionPrincipal = { ...principal, authenticatedAt }
  return context.json({
    accountId: principal.accountId,
    familyId: principal.sessionFamilyId,
    identityKind: 'apple',
    authenticatedAt: new Date(authenticatedAt).toISOString(),
    accessToken: await issueAccessToken(context.env, renewedPrincipal),
    accessTokenExpiresAt: accessTokenExpiresAt(),
  })
})

authRoutes.use('/apple/link', requireSession)
authRoutes.post('/apple/link', async (context) => {
  const guestPrincipal = context.get('principal')
  if (guestPrincipal.identityKind !== 'guest') {
    throw new EvaHttpError(409, 'unauthenticated', 'This Cloud EVA account is already protected with Apple.')
  }
  const config = await runtimeConfig(context.env)
  if (!config.guestAccess?.appleLinkingEnabled) {
    throw new EvaHttpError(503, 'configuration_unavailable', 'Apple account linking is temporarily unavailable.', {
      recoveryAction: 'wait', retryable: true,
    })
  }
  const guestAuthorization = await authorizeAccount(context.env, guestPrincipal, {
    requireAdult: requiresAgeDecision(config),
    requireAttestation: false,
  })
  if (!guestAuthorization.authorized) throwAuthorizationFailure(guestAuthorization.reason)
  const body = await readJson<EvaAppleExchangeRequestV1>(context.req.raw, EvaAppleExchangeRequestV1Schema)
  if (body.installationId !== guestPrincipal.installationId || body.platform !== guestPrincipal.platform) {
    throw new EvaHttpError(401, 'unauthenticated', 'The Apple link request does not match this device.')
  }
  try {
    await durableJson(authChallengeStub(context.env, body.challengeId), '/consume', {
      method: 'POST', body: JSON.stringify({ purpose: 'link', nonce: body.nonce }),
    })
  } catch {
    throw new EvaHttpError(409, 'unauthenticated', 'The Apple link request expired. Try again.', { recoveryAction: 'signIn' })
  }

  let identity: Awaited<ReturnType<typeof verifyAppleIdentityToken>>
  try {
    identity = await verifyAppleIdentityToken(context.env, body.identityToken, body.nonce)
  } catch (error) {
    if (error instanceof AppleUpstreamTimeoutError) throw appleTimeout(context.env, context.get('requestId'), 'link_identity_timeout')
    throw new EvaHttpError(401, 'unauthenticated', 'Apple sign-in could not be verified.', { recoveryAction: 'signIn' })
  }
  const accountId = await hmacSha256(context.env.ACCOUNT_HMAC_KEY, identity.subject)
  const linkId = body.challengeId.toLowerCase()
  const linkLock = durableObjectStub(context.env.AUTH_CHALLENGES, `apple-link:${accountId}`)
  const lockResponse = await linkLock.fetch('https://durable.internal/link-lock/acquire', {
    method: 'POST', body: JSON.stringify({ linkId, ttlSeconds: 120 }),
  })
  if (!lockResponse.ok) {
    throw new EvaHttpError(409, 'rate_limited', 'This Apple account is already being linked. Try again shortly.', {
      retryable: true, retryAfter: 2, recoveryAction: 'wait',
    })
  }
  try {
    let appleTokens: Awaited<ReturnType<typeof exchangeAppleAuthorizationCode>>
    try {
      appleTokens = await exchangeAppleAuthorizationCode(context.env, body.authorizationCode, identity.audience)
    } catch (error) {
      if (error instanceof AppleUpstreamTimeoutError) throw appleTimeout(context.env, context.get('requestId'), 'link_code_timeout')
      throw new EvaHttpError(401, 'unauthenticated', 'Apple sign-in could not be verified.', { recoveryAction: 'signIn' })
    }
    if (appleTokens.identity.subject !== identity.subject || appleTokens.identity.audience !== identity.audience) {
      throw new EvaHttpError(401, 'unauthenticated', 'Apple sign-in identities did not match.', { recoveryAction: 'signIn' })
    }
    await schedulePendingGuestLink(context.env, accountId, {
      mergeId: linkId,
      sourceAccountId: guestPrincipal.accountId,
      targetAccountId: accountId,
    })
    let catalystRisk: Awaited<ReturnType<typeof verifyCatalystAppTransaction>> | undefined
    if (body.platform === 'catalyst' && body.signedAppTransaction) {
      catalystRisk = await verifyCatalystAppTransaction(context.env, body.signedAppTransaction).catch(() => undefined)
    }

    const refresh = await newRefreshToken()
    const familyId = crypto.randomUUID()
    const authenticatedAt = Date.now()
    const encryptedAppleRefreshToken = appleTokens.refreshToken
      ? await encryptString(context.env.TOKEN_ENCRYPTION_KEY, appleTokens.refreshToken)
      : undefined
    await durableJson(accountStub(context.env, accountId), '/bootstrap', {
      method: 'POST', body: JSON.stringify({
        accountId, identityKind: 'apple', encryptedAppleRefreshToken, appleClientId: identity.audience,
        familyId, refreshTokenHash: refresh.hash, refreshGeneration: refresh.generation,
        installationId: body.installationId, platform: body.platform,
        catalystRisk: catalystRisk ? {
          appTransactionIdHash: await hmacSha256(context.env.ACCOUNT_HMAC_KEY, catalystRisk.appTransactionId),
          receiptEnvironment: catalystRisk.receiptEnvironment,
          originalPlatform: catalystRisk.originalPlatform,
          verifiedAt: authenticatedAt,
        } : undefined,
        authenticatedAt, refreshExpiresAt: refresh.expiresAt,
      }),
    })
    const merged = await reconcilePendingGuestLink(context.env, accountId)

    const principal: SessionPrincipal = {
      accountId, sessionFamilyId: familyId, installationId: body.installationId, platform: body.platform,
      authenticatedAt, identityKind: 'apple',
    }
    recordTelemetry(context.env, {
      event: 'auth.apple.linked', requestId: context.get('requestId'), accountId, status: 'consent_review_required',
    })
    return context.json({
      accountId, familyId, identityKind: 'apple',
      accessToken: await issueAccessToken(context.env, principal),
      accessTokenExpiresAt: accessTokenExpiresAt(),
      refreshToken: refresh.token,
      refreshTokenExpiresAt: new Date(refresh.expiresAt).toISOString(),
      requiresAdultEligibility: requiresAgeDecision(config),
      requiresAttestation: false,
      requiresConsentReview: true,
      quota: merged.quota,
      consent: merged.consent,
    })
  } finally {
    await linkLock.fetch('https://durable.internal/link-lock/release', {
      method: 'POST', body: JSON.stringify({ linkId }),
    }).catch(() => undefined)
  }
})

function authChallengeStub(env: Env, challengeId: string): DurableObjectStub {
  // Swift's UUID Codable representation is uppercase while crypto.randomUUID()
  // is lowercase. Durable Object names are case-sensitive, so always resolve a
  // UUID challenge through one canonical name at both issuance and consumption.
  return durableObjectStub(env.AUTH_CHALLENGES, challengeId.toLowerCase())
}

function appleLinkCoordinator(env: Env, accountId: string): DurableObjectStub {
  return durableObjectStub(env.AUTH_CHALLENGES, `apple-link:${accountId}`)
}

async function schedulePendingGuestLink(
  env: Env,
  accountId: string,
  pending: { mergeId: string; sourceAccountId: string; targetAccountId: string },
): Promise<void> {
  const response = await appleLinkCoordinator(env, accountId).fetch('https://durable.internal/link-pending', {
    method: 'POST', body: JSON.stringify(pending),
  }).catch(() => undefined)
  if (!response || !response.ok) {
    throw new EvaHttpError(503, 'provider_unavailable', 'Apple linking could not be scheduled safely yet.', {
      retryable: true, retryAfter: 2, recoveryAction: 'wait',
    })
  }
}

async function reconcilePendingGuestLink(
  env: Env,
  accountId: string,
): Promise<{ quota?: unknown; credits?: unknown; consent?: unknown }> {
  const response = await appleLinkCoordinator(env, accountId).fetch(
    'https://durable.internal/link-pending/reconcile',
    { method: 'POST' },
  ).catch(() => undefined)
  if (!response || !response.ok) {
    throw new EvaHttpError(503, 'provider_unavailable', 'Apple linking is finishing safely. Try again shortly.', {
      retryable: true, retryAfter: 2, recoveryAction: 'wait',
    })
  }
  return response.json<{ quota?: unknown; credits?: unknown; consent?: unknown }>()
}

function recordAppleExchangeFailure(env: Env, requestId: string, stage: string): void {
  recordTelemetry(env, {
    event: 'auth.apple.exchange.failed',
    requestId,
    route: '/v1/auth/apple/exchange',
    status: stage,
  })
  // Deliberately content-free so live Worker tails can identify the failing
  // verification stage without exposing credentials, subjects, or payloads.
  console.warn(JSON.stringify({ event: 'auth.apple.exchange.failed', requestId, stage }))
}

/** Apple was unreachable, not unconvinced. `wait` plus `retryable` tells the
 *  client to offer another attempt instead of restarting sign-in. */
function appleTimeout(env: Env, requestId: string, stage: string): EvaHttpError {
  recordAppleExchangeFailure(env, requestId, stage)
  return new EvaHttpError(503, 'provider_unavailable', 'Apple did not respond in time. Try again.', {
    retryable: true,
    retryAfter: 2,
    recoveryAction: 'wait',
  })
}

authRoutes.post('/refresh', async (context) => {
  const body = await readJson<EvaRefreshRequestV1>(context.req.raw, EvaRefreshRequestV1Schema)
  const presentedGeneration = refreshTokenGeneration(body.refreshToken)
  const replacement = await newRefreshToken((presentedGeneration ?? -1) + 1)
  let response: Response
  try {
    response = await accountStub(context.env, body.accountId).fetch('https://durable.internal/refresh/rotate', {
      method: 'POST',
      body: JSON.stringify({
        familyId: body.familyId,
        presentedTokenHash: await sha256(body.refreshToken),
        presentedGeneration,
        replacementTokenHash: replacement.hash,
        replacementGeneration: replacement.generation,
        replacementExpiresAt: replacement.expiresAt,
        installationId: body.installationId,
        platform: body.platform,
      }),
    })
  } catch {
    throw new EvaHttpError(503, 'provider_unavailable', 'Your EVA session could not be refreshed yet.', {
      retryable: true, retryAfter: 1, recoveryAction: 'wait',
    })
  }
  if (response.status === 401 || response.status === 404) {
    throw new EvaHttpError(401, 'session_expired', 'Your EVA session has expired.', {
      recoveryAction: 'signIn',
    })
  }
  if (response.status === 429) {
    throw new EvaHttpError(429, 'rate_limited', 'Session refresh is receiving too many requests.', {
      retryable: true, retryAfter: 60, recoveryAction: 'wait',
    })
  }
  if (!response.ok) {
    throw new EvaHttpError(503, 'provider_unavailable', 'Your EVA session could not be refreshed yet.', {
      retryable: true, retryAfter: 1, recoveryAction: 'wait',
    })
  }
  let rotation: {
      family: { installationId: string; authenticatedAt: number; identityKind?: 'guest' | 'apple' }
      platform: 'ios' | 'catalyst'
  }
  try {
    rotation = await response.json<typeof rotation>()
  } catch {
    throw new EvaHttpError(503, 'provider_unavailable', 'Your EVA session could not be refreshed yet.', {
      retryable: true, retryAfter: 1, recoveryAction: 'wait',
    })
  }
  const principal: SessionPrincipal = {
    accountId: body.accountId,
    sessionFamilyId: body.familyId,
    installationId: rotation.family.installationId,
    platform: rotation.platform,
    authenticatedAt: rotation.family.authenticatedAt,
    identityKind: rotation.family.identityKind ?? 'apple',
  }
  return context.json({
    accountId: body.accountId,
    accessToken: await issueAccessToken(context.env, principal),
    accessTokenExpiresAt: accessTokenExpiresAt(),
    refreshToken: replacement.token,
    refreshTokenExpiresAt: new Date(replacement.expiresAt).toISOString(),
  })
})

authRoutes.use('/logout', requireSession)
authRoutes.post('/logout', async (context) => {
  const principal = context.get('principal')
  const authorization = await authorizeAccount(context.env, principal, {
    requireAdult: false, requireAttestation: false, allowAgeManagement: true,
  })
  if (!authorization.authorized && authorization.reason !== 'session') {
    throwAuthorizationFailure(authorization.reason)
  }
  await durableJson(accountStub(context.env, principal.accountId), '/session/revoke', {
    method: 'POST',
    body: JSON.stringify({ familyId: principal.sessionFamilyId }),
  })
  return context.body(null, 204)
})

function throwAuthorizationFailure(reason: 'session' | 'age' | 'attestation' | 'deleted' | undefined): never {
  if (reason === 'age') {
    throw new EvaHttpError(403, 'adult_eligibility_required', 'Cloud EVA is available to people age 13 and older.', {
      recoveryAction: 'verifyAge',
    })
  }
  throw new EvaHttpError(401, 'session_expired', 'Your EVA session has expired.', {
    recoveryAction: 'signIn',
  })
}

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
