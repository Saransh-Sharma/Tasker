import { Type } from '@sinclair/typebox'
import { Hono } from 'hono'
import {
  EvaAdultEligibilityRequestV1Schema,
  type EvaAdultEligibilityRequestV1,
  type EvaConsentPolicy,
} from '@lifeboard/eva-contracts'
import type { AppVariables, Env } from '../environment.js'
import { requireSession } from '../auth/middleware.js'
import { revokeAppleRefreshToken } from '../auth/apple.js'
import { verifyRequestAttestation } from '../attestation/app-attest.js'
import {
  accountStub,
  authorizeAccount,
  getConsent,
  getCredits,
  registerDeviceAge,
} from '../durable-objects/account-client.js'
import { durableJson } from '../durable-objects/helpers.js'
import { readJson } from '../http/body.js'
import { EvaHttpError } from '../http/errors.js'
import { decryptString } from '../security/crypto.js'

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
  await verifyRequestAttestation(context.env, principal, context.req.raw)
  const body = await readJson<EvaAdultEligibilityRequestV1>(
    context.req.raw,
    EvaAdultEligibilityRequestV1Schema,
  )
  const eligibleAdult = body.declaration === 'shared' && body.lowerBound !== null && body.lowerBound >= 18
  const result = await registerDeviceAge(context.env, principal.accountId, {
    installationId: principal.installationId,
    platform: principal.platform,
    eligibleAdult,
    declaration: `${body.declaration}:${body.policyVersion}`,
  })
  if (!result.eligibleAdult) {
    throw new EvaHttpError(403, 'adult_eligibility_required', 'Cloud EVA is available only after an 18+ age-range result.', {
      recoveryAction: 'verifyAge',
    })
  }
  return context.json(result)
})

accountRoutes.get('/eva/credits', async (context) => {
  const principal = context.get('principal')
  const authorization = await authorizeAccount(context.env, principal, {
    requireAdult: true,
    requireAttestation: principal.platform === 'ios',
  })
  if (!authorization.authorized) throw authorizationError(authorization.reason)
  return context.json(await getCredits(context.env, principal.accountId))
})

accountRoutes.get('/eva/consent', async (context) => {
  const principal = context.get('principal')
  const authorization = await authorizeAccount(context.env, principal, {
    requireAdult: true,
    requireAttestation: principal.platform === 'ios',
  })
  if (!authorization.authorized) throw authorizationError(authorization.reason)
  return context.json(await getConsent(context.env, principal.accountId))
})

accountRoutes.put('/eva/consent', async (context) => {
  const principal = context.get('principal')
  await verifyRequestAttestation(context.env, principal, context.req.raw)
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
  if (Date.now() - principal.authenticatedAt > 5 * 60 * 1_000) {
    throw new EvaHttpError(401, 'unauthenticated', 'Sign in with Apple again before deleting this account.', {
      recoveryAction: 'signIn',
    })
  }
  await verifyRequestAttestation(context.env, principal, context.req.raw)
  const credential = await durableJson<{ encryptedRefreshToken?: string; clientId?: string }>(
    accountStub(context.env, principal.accountId),
    '/apple/credential',
  )
  if (credential.encryptedRefreshToken && credential.clientId) {
    try {
      await revokeAppleRefreshToken(
        context.env,
        await decryptString(context.env.TOKEN_ENCRYPTION_KEY, credential.encryptedRefreshToken),
        credential.clientId,
      )
    } catch {
      throw new EvaHttpError(503, 'provider_unavailable', 'Apple account authorization could not be revoked. Try again.', {
        retryable: true,
      })
    }
  }
  await durableJson(accountStub(context.env, principal.accountId), '/account', { method: 'DELETE' })
  return context.body(null, 204)
})

function authorizationError(reason: 'session' | 'age' | 'attestation' | 'deleted' | undefined): EvaHttpError {
  if (reason === 'age') {
    return new EvaHttpError(403, 'adult_eligibility_required', 'Confirm 18+ eligibility to use Cloud EVA.', {
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
