import { importPKCS8, SignJWT } from 'jose'
import type { Env } from '../environment.js'

export interface DeviceCheckRisk {
  bit0: boolean
  bit1: boolean
  lastUpdatedAt?: string
  verifiedAt: number
}

let cachedKey: { keyId: string; key: ReturnType<typeof importPKCS8> } | undefined

async function deviceCheckJWT(env: Env): Promise<string> {
  if (!env.APPLE_DEVICECHECK_KEY_ID || !env.APPLE_DEVICECHECK_PRIVATE_KEY_P8) {
    throw new Error('DeviceCheck credentials are not configured.')
  }
  if (cachedKey?.keyId !== env.APPLE_DEVICECHECK_KEY_ID) {
    cachedKey = {
      keyId: env.APPLE_DEVICECHECK_KEY_ID,
      key: importPKCS8(env.APPLE_DEVICECHECK_PRIVATE_KEY_P8.replaceAll('\\n', '\n'), 'ES256'),
    }
  }
  let key: Awaited<ReturnType<typeof importPKCS8>>
  try {
    key = await cachedKey.key
  } catch (error) {
    cachedKey = undefined
    throw error
  }
  const now = Math.floor(Date.now() / 1_000)
  return new SignJWT({})
    .setProtectedHeader({ alg: 'ES256', kid: env.APPLE_DEVICECHECK_KEY_ID })
    .setIssuer(env.APPLE_TEAM_ID)
    .setIssuedAt(now)
    .setExpirationTime(now + 5 * 60)
    .sign(key)
}

export function deviceCheckBaseURL(env: Env): string {
  return env.APP_ATTEST_ENVIRONMENT === 'development'
    ? 'https://api.development.devicecheck.apple.com'
    : 'https://api.devicecheck.apple.com'
}

/** DeviceCheck is advisory: failure preserves low-trust guest access. */
export async function queryDeviceCheckRisk(env: Env, deviceToken: string): Promise<DeviceCheckRisk | undefined> {
  if (!deviceToken || !env.APPLE_DEVICECHECK_KEY_ID || !env.APPLE_DEVICECHECK_PRIVATE_KEY_P8) return undefined
  try {
    const response = await fetch(`${deviceCheckBaseURL(env)}/v1/query_two_bits`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${await deviceCheckJWT(env)}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ device_token: deviceToken, transaction_id: crypto.randomUUID(), timestamp: Date.now() }),
      signal: AbortSignal.timeout(4_000),
    })
    if (!response.ok) return undefined
    const value = await response.json<{ bit0?: boolean; bit1?: boolean; last_update_time?: string }>()
    return {
      bit0: value.bit0 === true,
      bit1: value.bit1 === true,
      lastUpdatedAt: value.last_update_time,
      verifiedAt: Date.now(),
    }
  } catch {
    return undefined
  }
}

/**
 * Bit 0 is reserved for "this Apple device has bootstrapped guest EVA before".
 * Bit 1 is left untouched for developer-team-wide compatibility. The query
 * must succeed before updating so an outage can never clear an existing bit.
 */
export async function markDeviceCheckGuestBootstrap(
  env: Env,
  deviceToken: string,
  observed: DeviceCheckRisk,
): Promise<void> {
  try {
    await fetch(`${deviceCheckBaseURL(env)}/v1/update_two_bits`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${await deviceCheckJWT(env)}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        device_token: deviceToken,
        transaction_id: crypto.randomUUID(),
        timestamp: Date.now(),
        bit0: true,
        bit1: observed.bit1,
      }),
      signal: AbortSignal.timeout(4_000),
    })
  } catch {
    // DeviceCheck remains an advisory abuse signal. Never affect allowance.
  }
}
