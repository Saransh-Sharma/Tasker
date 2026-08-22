import { Type } from '@sinclair/typebox'
import { Hono } from 'hono'
import type { AppVariables, Env } from '../environment.js'
import { accountStub, authorizeAccount } from '../durable-objects/account-client.js'
import { durableJson } from '../durable-objects/helpers.js'
import { readJson } from '../http/body.js'
import { EvaHttpError } from '../http/errors.js'
import { requireSession } from '../auth/middleware.js'
import { validateAttestationRegistration, verifyRequestAttestation } from './app-attest.js'

const RegistrationSchema = Type.Object({
  challenge: Type.String({ minLength: 20, maxLength: 256 }),
  keyId: Type.String({ minLength: 16, maxLength: 512 }),
  attestation: Type.String({ minLength: 32, maxLength: 64_000 }),
}, { additionalProperties: false })

export const attestationRoutes = new Hono<{ Bindings: Env; Variables: AppVariables }>()
attestationRoutes.use('*', requireSession)

attestationRoutes.post('/challenge', async (context) => {
  const principal = context.get('principal')
  if (principal.platform !== 'ios') {
    throw new EvaHttpError(409, 'attestation_required', 'App Attest is available only on iOS.')
  }
  const authorization = await authorizeAccount(context.env, principal, {
    requireAdult: false,
    requireAttestation: false,
  })
  if (!authorization.authorized) {
    throw new EvaHttpError(401, 'session_expired', 'Your EVA session has expired.', { recoveryAction: 'signIn' })
  }
  return context.json(await durableJson(accountStub(context.env, principal.accountId), '/device/attestation/challenge', {
    method: 'POST',
    body: JSON.stringify({ installationId: principal.installationId }),
  }))
})

attestationRoutes.post('/register', async (context) => {
  const principal = context.get('principal')
  if (principal.platform !== 'ios') {
    throw new EvaHttpError(409, 'attestation_required', 'App Attest is available only on iOS.')
  }
  const authorization = await authorizeAccount(context.env, principal, {
    requireAdult: false,
    requireAttestation: false,
  })
  if (!authorization.authorized) {
    throw new EvaHttpError(401, 'session_expired', 'Your EVA session has expired.', { recoveryAction: 'signIn' })
  }
  const body = await readJson<{ challenge: string; keyId: string; attestation: string }>(
    context.req.raw,
    RegistrationSchema,
  )
  const verified = await validateAttestationRegistration(context.env, body)
  await durableJson(accountStub(context.env, principal.accountId), '/device/attestation/register', {
    method: 'POST',
    body: JSON.stringify({
      installationId: principal.installationId,
      challenge: body.challenge,
      keyId: verified.keyId,
      publicKey: verified.publicKey,
    }),
  })
  return context.json({ registered: true })
})

attestationRoutes.post('/verify', async (context) => {
  const principal = context.get('principal')
  if (principal.platform !== 'ios') {
    throw new EvaHttpError(409, 'attestation_required', 'App Attest is available only on iOS.')
  }
  await verifyRequestAttestation(context.env, principal, context.req.raw)
  return context.json({ verified: true })
})
