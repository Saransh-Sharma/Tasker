import { Type } from '@sinclair/typebox'
import { Hono } from 'hono'
import {
  EvaDeleteAccountRequestV1Schema,
  EvaAdultEligibilityRequestV1Schema,
  type EvaAdultEligibilityRequestV1,
  type EvaConsentPolicy,
} from '@lifeboard/eva-contracts'
import type { AppVariables, Env } from '../environment.js'
import { requireSession } from '../auth/middleware.js'
import { verifyRequestAttestation } from '../attestation/app-attest.js'
import {
  accountStub,
  authorizeAccount,
  getConsent,
  getCredits,
  getQuota,
  registerDeviceAge,
} from '../durable-objects/account-client.js'
import { durableJson } from '../durable-objects/helpers.js'
import { readJson } from '../http/body.js'
import { EvaHttpError } from '../http/errors.js'
import { requiresAgeDecision, runtimeConfig } from '../config/runtime-config.js'

const ConsentUpdateSchema = Type.Object({
  expectedRevision: Type.Integer({ minimum: 0 }),
  grants: Type.Array(Type.Union([
    Type.Literal('journal'),
    Type.Literal('health'),
    Type.Literal('lifeMoments'),
    Type.Literal('personalMemory'),
  ]), { maxItems: 4, uniqueItems: true }),
}, { additionalProperties: false })

export const accountRoutes = new Hono<{ Bindings: Env; Variables: AppVariables }>()
accountRoutes.use('*', requireSession)

accountRoutes.post('/age/eligibility', async (context) => {
  const principal = context.get('principal')
  const session = await authorizeAccount(context.env, principal, {
    requireAdult: false,
    requireAttestation: false,
    allowAgeManagement: true,
  })
  if (!session.authorized) throw authorizationError(session.reason)
  if (principal.platform === 'ios' && context.req.header('X-EVA-Attest-Assertion')) {
    await verifyRequestAttestation(context.env, principal, context.req.raw, { allowAgeManagement: true })
  }
  const body = await readJson<EvaAdultEligibilityRequestV1>(
    context.req.raw,
    EvaAdultEligibilityRequestV1Schema,
  )
  const policyRequired = requiresAgeDecision(await runtimeConfig(context.env))
  const eligibleAdult = body.lowerBound === null
    ? !policyRequired
    : body.lowerBound >= 13
  const result = await registerDeviceAge(context.env, principal.accountId, {
    installationId: principal.installationId,
    platform: principal.platform,
    eligibleAdult,
    lowerBound: body.lowerBound ?? undefined,
    policyRequired,
    declaration: `${body.declaration}:${body.policyVersion}`,
  })
  if (!result.eligibleAdult) {
    throw new EvaHttpError(403, 'adult_eligibility_required', 'Cloud EVA is available to people age 13 and older.', {
      recoveryAction: 'verifyAge',
    })
  }
  return context.json(result)
})

accountRoutes.get('/eva/credits', async (context) => {
  const principal = context.get('principal')
  const config = await runtimeConfig(context.env)
  const authorization = await authorizeAccount(context.env, principal, {
    requireAdult: requiresAgeDecision(config),
    requireAttestation: false,
  })
  if (!authorization.authorized) throw authorizationError(authorization.reason)
  return context.json(await getCredits(context.env, principal.accountId))
})

accountRoutes.get('/eva/quota', async (context) => {
  const principal = context.get('principal')
  const config = await runtimeConfig(context.env)
  const authorization = await authorizeAccount(context.env, principal, {
    requireAdult: requiresAgeDecision(config),
    requireAttestation: false,
  })
  if (!authorization.authorized) throw authorizationError(authorization.reason)
  return context.json(await getQuota(context.env, principal.accountId))
})

accountRoutes.get('/eva/consent', async (context) => {
  const principal = context.get('principal')
  const config = await runtimeConfig(context.env)
  const authorization = await authorizeAccount(context.env, principal, {
    requireAdult: requiresAgeDecision(config),
    requireAttestation: false,
  })
  if (!authorization.authorized) throw authorizationError(authorization.reason)
  return context.json(await getConsent(context.env, principal.accountId))
})

accountRoutes.put('/eva/consent', async (context) => {
  const principal = context.get('principal')
  const config = await runtimeConfig(context.env)
  const authorization = await authorizeAccount(context.env, principal, {
    requireAdult: requiresAgeDecision(config),
    requireAttestation: false,
  })
  if (!authorization.authorized) throw authorizationError(authorization.reason)
  if (principal.platform === 'ios' && context.req.header('X-EVA-Attest-Assertion')) {
    await verifyRequestAttestation(context.env, principal, context.req.raw)
  }
  const body = await readJson<{
    expectedRevision: number
    grants: EvaConsentPolicy['grants']
  }>(context.req.raw, ConsentUpdateSchema)
  const response = await accountStub(context.env, principal.accountId).fetch('https://durable.internal/consent', {
    method: 'PUT',
    body: JSON.stringify(body),
  })
  const payload = await response.json<EvaConsentPolicy & { consent?: EvaConsentPolicy }>()
  if (response.status === 409) {
    throw new EvaHttpError(409, 'consent_revision_conflict', 'Consent changed on another device. Review it and try again.', {
      recoveryAction: 'reviewConsent',
    })
  }
  if (!response.ok) throw new EvaHttpError(503, 'provider_unavailable', 'Consent could not be updated.', { retryable: true })
  return context.json(payload)
})

accountRoutes.delete('/account', async (context) => {
  const principal = context.get('principal')
  const authorization = await authorizeAccount(context.env, principal, {
    requireAdult: false,
    requireAttestation: false,
    allowAgeManagement: true,
  })
  if (!authorization.authorized) throw authorizationError(authorization.reason)
  if (principal.identityKind === 'apple' && Date.now() - principal.authenticatedAt > 5 * 60 * 1_000) {
    throw new EvaHttpError(401, 'unauthenticated', 'Sign in with Apple again before deleting this account.', {
      recoveryAction: 'signIn',
    })
  }
  if (principal.platform === 'ios' && context.req.header('X-EVA-Attest-Assertion')) {
    await verifyRequestAttestation(context.env, principal, context.req.raw, { allowAgeManagement: true })
  }
  await readJson(context.req.raw, EvaDeleteAccountRequestV1Schema)
  const deletionMaterial = await durableJson<{
    encryptedRefreshToken?: string
    clientId?: string
    guestBootstrapId?: string
  }>(
    accountStub(context.env, principal.accountId),
    '/apple/credential',
  )
  if (deletionMaterial.guestBootstrapId) {
    // Remove the recovery mapping first. If account erasure then fails, the
    // still-active device session can retry; the reverse order could resurrect
    // a deleted guest account from a stranded mapping.
    const mapping = context.env.AUTH_CHALLENGES.get(
      context.env.AUTH_CHALLENGES.idFromName(deletionMaterial.guestBootstrapId.toLowerCase()),
    )
    const unmapped = await mapping.fetch('https://durable.internal/guest-account', { method: 'DELETE' })
      .catch(() => undefined)
    if (!unmapped?.ok) {
      throw new EvaHttpError(503, 'provider_unavailable', 'Guest Cloud EVA deletion could not start yet.', {
        retryable: true, retryAfter: 1, recoveryAction: 'wait',
      })
    }
  }
  let appleRevocation: DurableObjectStub | undefined
  if (
    principal.identityKind === 'apple'
    && deletionMaterial.encryptedRefreshToken
    && deletionMaterial.clientId
  ) {
    appleRevocation = context.env.AUTH_CHALLENGES.get(
      context.env.AUTH_CHALLENGES.idFromName(`apple-revoke:${principal.accountId}`),
    )
    const scheduled = await appleRevocation.fetch('https://durable.internal/apple-revocation', {
      method: 'POST',
      body: JSON.stringify({
        encryptedRefreshToken: deletionMaterial.encryptedRefreshToken,
        clientId: deletionMaterial.clientId,
      }),
    }).catch(() => undefined)
    if (!scheduled?.ok) {
      throw new EvaHttpError(503, 'provider_unavailable', 'Apple authorization revocation could not be scheduled yet.', {
        retryable: true, retryAfter: 1, recoveryAction: 'wait',
      })
    }
  }
  await durableJson(
    accountStub(context.env, principal.accountId),
    '/account',
    { method: 'DELETE' },
  )
  if (appleRevocation) {
    context.executionCtx.waitUntil(appleRevocation.fetch(
      'https://durable.internal/apple-revocation/reconcile',
      { method: 'POST' },
    ).then(() => undefined).catch(() => undefined))
  }
  return context.body(null, 204)
})

function authorizationError(reason: 'session' | 'age' | 'attestation' | 'deleted' | undefined): EvaHttpError {
  if (reason === 'age') {
    return new EvaHttpError(403, 'adult_eligibility_required', 'Cloud EVA is available to people age 13 and older.', {
      recoveryAction: 'verifyAge',
    })
  }
  if (reason === 'attestation') {
    return new EvaHttpError(401, 'attestation_required', 'Verify this device to use Cloud EVA.', {
      recoveryAction: 'signIn',
    })
  }
  return new EvaHttpError(401, 'session_expired', 'Your EVA session has expired.', { recoveryAction: 'signIn' })
}
