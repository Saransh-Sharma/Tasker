import { Buffer } from 'node:buffer'
import { describe, expect, it } from 'vitest'
import { verifyCatalystAppTransaction } from '../src/auth/app-transaction.js'

const testEnvironment = {
  APPLE_APP_ID: '1574046107',
  APPLE_CATALYST_BUNDLE_ID: 'com.saransh1337.To-Do-List.mac',
  APPLE_ROOT_CERTIFICATES_BASE64: '',
  APP_STORE_ENVIRONMENT: 'LocalTesting' as const,
}

function unsignedLocalTransaction(overrides: Record<string, unknown> = {}): string {
  const header = { alg: 'none' }
  const payload = {
    receiptType: 'LocalTesting',
    appAppleId: 1_574_046_107,
    bundleId: 'com.saransh1337.To-Do-List.mac',
    appTransactionId: '1000000000000000',
    deviceVerification: 'c3ludGhldGljLWRldmljZS12ZXJpZmljYXRpb24=',
    deviceVerificationNonce: '77777777-7777-4777-8777-777777777777',
    originalPlatform: 'macOS',
    ...overrides,
  }
  return `${base64url(header)}.${base64url(payload)}.`
}

function base64url(value: unknown): string {
  return Buffer.from(JSON.stringify(value))
    .toString('base64url')
}

describe('Catalyst App Transaction risk evidence', () => {
  it('validates bundle, environment, and required device fields', async () => {
    await expect(verifyCatalystAppTransaction(
      testEnvironment,
      unsignedLocalTransaction(),
    )).resolves.toEqual({
      appTransactionId: '1000000000000000',
      receiptEnvironment: 'LocalTesting',
      originalPlatform: 'macOS',
    })
  }, 15_000)

  it('fails closed when Catalyst omits the proof', async () => {
    await expect(verifyCatalystAppTransaction(testEnvironment, undefined))
      .rejects.toThrow('requires a signed App Transaction')
  })

  it('rejects an App Transaction for another bundle', async () => {
    await expect(verifyCatalystAppTransaction(
      testEnvironment,
      unsignedLocalTransaction({ bundleId: 'com.example.attacker' }),
    )).rejects.toThrow()
  })

  it('rejects another receipt environment and malformed device evidence', async () => {
    const invalidPayloads = [
      { receiptType: 'Sandbox' },
      { appTransactionId: undefined },
      { deviceVerification: undefined },
      { deviceVerificationNonce: undefined },
      { deviceVerificationNonce: 'not-a-uuid' },
    ]
    for (const overrides of invalidPayloads) {
      await expect(verifyCatalystAppTransaction(
        testEnvironment,
        unsignedLocalTransaction(overrides),
      )).rejects.toThrow()
    }
  })

  it('requires configured Apple identity and trust roots outside local StoreKit', async () => {
    await expect(verifyCatalystAppTransaction(
      { ...testEnvironment, APPLE_APP_ID: 'not-an-app-id' },
      unsignedLocalTransaction(),
    )).rejects.toThrow('APPLE_APP_ID is not configured')
    await expect(verifyCatalystAppTransaction(
      { ...testEnvironment, APP_STORE_ENVIRONMENT: 'Sandbox' },
      unsignedLocalTransaction({ receiptType: 'Sandbox' }),
    )).rejects.toThrow('Apple root certificates are not configured')
    await expect(verifyCatalystAppTransaction(
      { ...testEnvironment, APP_STORE_ENVIRONMENT: 'Production' },
      unsignedLocalTransaction({ receiptType: 'Production' }),
    )).rejects.toThrow('Apple root certificates are not configured')
  })
})
