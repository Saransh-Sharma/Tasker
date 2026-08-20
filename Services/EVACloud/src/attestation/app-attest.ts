import { Buffer } from 'node:buffer'
import { X509Certificate } from 'node:crypto'
import { decodeAllSync } from 'cbor'
import { verifyAssertion, verifyAttestation } from 'node-app-attest'
import type { Env, SessionPrincipal } from '../environment.js'
import { accountStub, authorizeAccount } from '../durable-objects/account-client.js'
import { durableJson } from '../durable-objects/helpers.js'
import { EvaHttpError } from '../http/errors.js'
import { sha256 } from '../security/crypto.js'

function decodeBase64(value: string): Buffer {
  return Buffer.from(value.replaceAll('-', '+').replaceAll('_', '/'), 'base64')
}

function iosBundleIdentifier(env: Env): string {
  const bundleId = env.APPLE_BUNDLE_IDS.split(',').map((value) => value.trim())[0]
  if (!bundleId) throw new EvaHttpError(503, 'configuration_unavailable', 'Device verification is unavailable.')
  return bundleId
}

function assertCertificateValidity(attestation: Buffer, now = Date.now()): void {
  const decoded = decodeAllSync(attestation)
  if (decoded.length !== 1) throw new Error('Invalid App Attest certificate envelope.')
  const x5c = (decoded[0] as { attStmt?: { x5c?: unknown[] } }).attStmt?.x5c
  if (!Array.isArray(x5c) || x5c.length !== 2 || !x5c.every((value) => Buffer.isBuffer(value))) {
    throw new Error('Invalid App Attest certificate chain.')
  }
  for (const encodedCertificate of x5c as Buffer[]) {
    const certificate = new X509Certificate(encodedCertificate)
    const validFrom = Date.parse(certificate.validFrom)
    const validTo = Date.parse(certificate.validTo)
    if (!Number.isFinite(validFrom) || !Number.isFinite(validTo) || now < validFrom || now > validTo) {
      throw new Error('App Attest certificate is outside its validity window.')
    }
  }
}

export async function validateAttestationRegistration(
  env: Env,
  input: { attestation: string; challenge: string; keyId: string },
): Promise<{ keyId: string; publicKey: string }> {
  try {
    const attestation = decodeBase64(input.attestation)
    const result = verifyAttestation({
      attestation,
      challenge: input.challenge,
      keyId: input.keyId,
      bundleIdentifier: iosBundleIdentifier(env),
      teamIdentifier: env.APPLE_TEAM_ID,
      allowDevelopmentEnvironment: env.ENVIRONMENT !== 'production' && env.APP_ATTEST_ENVIRONMENT === 'development',
    })
    assertCertificateValidity(attestation)
    if (result.environment !== env.APP_ATTEST_ENVIRONMENT) {
      throw new Error('The App Attest environment does not match server configuration.')
    }
    return { keyId: result.keyId, publicKey: result.publicKey }
  } catch {
    throw new EvaHttpError(401, 'attestation_required', 'This device could not be verified.', {
      recoveryAction: 'signIn',
    })
  }
}

export function validateAppAttestAssertion(
  env: Env,
  input: { assertion: string; payload: string; publicKey: string; previousCounter: number },
): number {
  const result = verifyAssertion({
    assertion: decodeBase64(input.assertion),
    payload: input.payload,
    publicKey: input.publicKey,
    bundleIdentifier: iosBundleIdentifier(env),
    teamIdentifier: env.APPLE_TEAM_ID,
    signCount: input.previousCounter,
  })
  return result.signCount
}

export async function verifyRequestAttestation(
  env: Env,
  principal: SessionPrincipal,
  request: Request,
): Promise<void> {
  const authorization = await authorizeAccount(env, principal, { requireAdult: false, requireAttestation: true })
  if (!authorization.authorized) {
    throw new EvaHttpError(401, 'attestation_required', 'Verify this device to use Cloud EVA.', {
      recoveryAction: 'signIn',
    })
  }
  if (principal.platform === 'catalyst') return

  const challenge = request.headers.get('X-EVA-Attest-Challenge')
  const assertion = request.headers.get('X-EVA-Attest-Assertion')
  if (!challenge || !assertion) {
    throw new EvaHttpError(401, 'attestation_required', 'A fresh device assertion is required.', {
      recoveryAction: 'signIn',
    })
  }
  let material: { keyId: string; publicKey: string; counter: number }
  try {
    material = await durableJson(accountStub(env, principal.accountId), '/device/assertion/material', {
      method: 'POST',
      body: JSON.stringify({ installationId: principal.installationId, challenge }),
    })
  } catch {
    throw new EvaHttpError(401, 'attestation_required', 'The device assertion expired. Try again.', {
      recoveryAction: 'signIn',
    })
  }

  const payload = await appAttestRequestPayload(request, challenge)
  try {
    const counter = validateAppAttestAssertion(env, {
      assertion,
      payload,
      publicKey: material.publicKey,
      previousCounter: material.counter,
    })
    await durableJson(accountStub(env, principal.accountId), '/device/assertion/commit', {
      method: 'POST',
      body: JSON.stringify({ installationId: principal.installationId, counter }),
    })
  } catch {
    throw new EvaHttpError(401, 'attestation_required', 'The device assertion was rejected.', {
      recoveryAction: 'signIn',
    })
  }
}

export async function appAttestRequestPayload(request: Request, challenge: string): Promise<string> {
  const rawBody = await request.clone().text()
  return [request.method, new URL(request.url).pathname, challenge, await sha256(rawBody)].join('\n')
}
