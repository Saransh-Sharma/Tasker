import { base64UrlDecode, hmacSha256 } from '../security/crypto.js'

/**
 * Assigns an installation bootstrap to a stable, server-secret rollout cohort.
 *
 * The bootstrap identifier is intentionally client-generated so an interrupted
 * activation can resume. A keyed digest keeps the cohort unpredictable to the
 * client, preventing offline ID grinding, while the first four digest bytes
 * provide a uniform unsigned bucket without parsing base64url as hexadecimal.
 */
export async function guestRolloutBucket(secret: string, bootstrapId: string): Promise<number> {
  const digest = base64UrlDecode(await hmacSha256(secret, bootstrapId.toLowerCase()))
  const value = (
    (digest[0] ?? 0) * 0x1000000
    + (digest[1] ?? 0) * 0x10000
    + (digest[2] ?? 0) * 0x100
    + (digest[3] ?? 0)
  ) >>> 0
  return value % 100
}
