import { Buffer } from 'node:buffer'
import type { AppTransaction, Environment as AppStoreEnvironment } from '@apple/app-store-server-library'
import type { Env } from '../environment.js'

type AppTransactionEnv = Pick<
  Env,
  | 'APPLE_APP_ID'
  | 'APPLE_CATALYST_BUNDLE_ID'
  | 'APPLE_ROOT_CERTIFICATES_BASE64'
  | 'APP_STORE_ENVIRONMENT'
>

export interface CatalystRiskEvidence {
  appTransactionId: string
  receiptEnvironment: string
  originalPlatform?: string
}

function configuredEnvironment(
  value: Env['APP_STORE_ENVIRONMENT'],
  environmentValues: typeof import('@apple/app-store-server-library').Environment,
): AppStoreEnvironment {
  switch (value) {
    case 'Production': return environmentValues.PRODUCTION
    case 'Sandbox': return environmentValues.SANDBOX
    case 'Xcode': return environmentValues.XCODE
    case 'LocalTesting': return environmentValues.LOCAL_TESTING
  }
}

function rootCertificates(value: string): Buffer[] {
  return value
    .split(',')
    .map((certificate) => certificate.trim())
    .filter(Boolean)
    .map((certificate) => Buffer.from(certificate, 'base64'))
}

function validateEvidence(transaction: AppTransaction): CatalystRiskEvidence {
  if (!transaction.appTransactionId
    || !transaction.deviceVerification
    || !transaction.deviceVerificationNonce
    || !transaction.receiptType) {
    throw new Error('The App Transaction is missing required device-risk fields.')
  }
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
    .test(transaction.deviceVerificationNonce)) {
    throw new Error('The App Transaction device nonce is malformed.')
  }
  return {
    appTransactionId: transaction.appTransactionId,
    receiptEnvironment: transaction.receiptType,
    originalPlatform: transaction.originalPlatform,
  }
}

/**
 * Verifies Apple's signed App Transaction as a Catalyst-only risk signal.
 * The caller must not treat this as account authentication or persist the JWS.
 */
export async function verifyCatalystAppTransaction(
  env: AppTransactionEnv,
  signedAppTransaction: string | undefined,
): Promise<CatalystRiskEvidence> {
  // jsrsasign (used by Apple's verifier) performs runtime initialization that
  // Cloudflare rejects at module global scope. Keep the verifier lazy so it is
  // evaluated only inside a request handler.
  const {
    Environment: AppStoreEnvironment,
    SignedDataVerifier,
  } = await import('@apple/app-store-server-library')
  if (!signedAppTransaction) throw new Error('Catalyst requires a signed App Transaction.')
  const environment = configuredEnvironment(env.APP_STORE_ENVIRONMENT, AppStoreEnvironment)
  const appAppleId = Number(env.APPLE_APP_ID)
  if (!Number.isSafeInteger(appAppleId) || appAppleId <= 0) {
    throw new Error('APPLE_APP_ID is not configured.')
  }
  const usesLocalStoreKit = environment === AppStoreEnvironment.XCODE
    || environment === AppStoreEnvironment.LOCAL_TESTING
  const roots = usesLocalStoreKit ? [] : rootCertificates(env.APPLE_ROOT_CERTIFICATES_BASE64)
  if (!usesLocalStoreKit && roots.length === 0) {
    throw new Error('Apple root certificates are not configured.')
  }
  const verifier = new SignedDataVerifier(
    roots,
    environment === AppStoreEnvironment.PRODUCTION || environment === AppStoreEnvironment.SANDBOX,
    environment,
    env.APPLE_CATALYST_BUNDLE_ID,
    environment === AppStoreEnvironment.PRODUCTION ? appAppleId : undefined,
  )
  return validateEvidence(await verifier.verifyAndDecodeAppTransaction(signedAppTransaction))
}
