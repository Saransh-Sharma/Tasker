import assert from 'node:assert/strict'

const maximumSignedAgeMilliseconds = 7 * 86_400_000

export function assertLivePolicy(actual, expected, now = Date.now()) {
  const issuedAt = Date.parse(actual.issuedAt)
  assert.ok(Number.isFinite(issuedAt), 'Live runtime configuration has an invalid issuedAt timestamp.')
  assert.ok(Math.abs(now - issuedAt) <= maximumSignedAgeMilliseconds, 'Live runtime configuration is stale.')

  // The Worker intentionally reissues the durable KV policy with a fresh
  // signed timestamp. Every other field must exactly match the checked-in
  // environment policy so a missing guestAccess block or disabled route cannot
  // silently reach clients again.
  assert.deepStrictEqual(
    { ...actual, issuedAt: expected.issuedAt },
    expected,
    'Live signed runtime configuration differs from the checked-in policy.'
  )
}
