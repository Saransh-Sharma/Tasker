import { compactVerify, importJWK } from 'jose'

export function requiredEnvironment(name) {
  const value = process.env[name]?.trim()
  if (!value) throw new Error(`${name} is required.`)
  return value
}

export function percentile(values, fraction) {
  const sorted = [...values].sort((left, right) => left - right)
  return sorted[Math.min(sorted.length - 1, Math.floor(sorted.length * fraction))] ?? 0
}

export async function verifyPublicStaging(baseURL, publicJwkText) {
  const healthResponse = await fetch(`${baseURL}/health`)
  if (!healthResponse.ok) throw new Error(`Health failed with ${healthResponse.status}.`)
  const health = await healthResponse.json()
  if (health.status !== 'ok' || health.environment !== 'staging') throw new Error('Unexpected staging health document.')

  const configResponse = await fetch(`${baseURL}/v1/eva/config`)
  if (!configResponse.ok) throw new Error(`Config failed with ${configResponse.status}.`)
  const envelope = await configResponse.json()
  const key = await importJWK(JSON.parse(publicJwkText), 'EdDSA')
  const verified = await compactVerify(envelope.signedConfiguration, key)
  if (verified.protectedHeader.kid !== 'eva-config-v2') throw new Error('Unexpected config signing key ID.')
  const config = JSON.parse(new TextDecoder().decode(verified.payload))
  if (config.schemaVersion !== 2 || config.environment !== 'staging') throw new Error('Unexpected runtime configuration.')
  const issuedAt = Date.parse(config.issuedAt)
  if (!Number.isFinite(issuedAt) || Math.abs(Date.now() - issuedAt) > 7 * 86_400_000) throw new Error('Runtime configuration is stale.')
  return { health, config }
}

export async function authenticatedJSON(baseURL, path, accessToken) {
  const response = await fetch(`${baseURL}${path}`, { headers: { Authorization: `Bearer ${accessToken}` } })
  if (!response.ok) throw new Error(`${path} failed with ${response.status}: ${await response.text()}`)
  return response.json()
}

export async function inference(baseURL, accessToken, request) {
  const response = await fetch(`${baseURL}/v1/eva/responses`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${accessToken}`, 'Content-Type': 'application/json' },
    body: JSON.stringify(request),
  })
  if (!response.ok) throw new Error(`Inference failed with ${response.status}: ${await response.text()}`)
  const events = []
  const text = await response.text()
  for (const block of text.split('\n\n')) {
    const line = block.split('\n').find((value) => value.startsWith('data: '))
    if (line) events.push(JSON.parse(line.slice(6)))
  }
  const failure = events.find((event) => event.type === 'response.failed')
  if (failure) throw new Error(`Inference stream failed: ${failure.error?.code ?? 'unknown'}`)
  if (!events.some((event) => event.type === 'response.completed')) throw new Error('Inference stream did not complete.')
  return events
}

