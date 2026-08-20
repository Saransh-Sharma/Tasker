import {
  authenticatedJSON,
  inference,
  requiredEnvironment,
  verifyPublicStaging,
} from './staging-client.mjs'

const baseURL = requiredEnvironment('EVA_STAGING_BASE_URL').replace(/\/$/u, '')
const publicJwk = requiredEnvironment('EVA_CONFIG_PUBLIC_JWK')
const { config } = await verifyPublicStaging(baseURL, publicJwk)

const accessToken = process.env.EVA_STAGING_ACCESS_TOKEN?.trim()
if (!accessToken) {
  process.stdout.write(`Staging health and signed config passed (cloud=${config.cloudState}, tts=${config.ttsEnabled}).\n`)
  process.exit(0)
}

const installationId = requiredEnvironment('EVA_STAGING_INSTALLATION_ID')
const platform = process.env.EVA_STAGING_PLATFORM?.trim() ?? 'catalyst'
if (platform !== 'catalyst') {
  throw new Error('CLI authenticated smoke supports Catalyst sessions; iOS App Attest smoke runs on a physical device.')
}
const credits = await authenticatedJSON(baseURL, '/v1/eva/credits', accessToken)
const consent = await authenticatedJSON(baseURL, '/v1/eva/consent', accessToken)
if (config.cloudState === 'enabled' && config.routes?.debugSmoke?.enabled) {
  await inference(baseURL, accessToken, {
    requestId: crypto.randomUUID(),
    route: 'debugSmoke',
    contractVersion: 1,
    locale: 'en-US',
    timeZone: 'UTC',
    messages: [{ role: 'user', content: 'Reply with the single word ready.' }],
    context: [],
    clientVersion: '1.0.0',
    platform,
    installationId,
    consentRevision: consent.revision,
    providerCapabilities: { streaming: true, structuredOutput: true, spokenOutput: true },
  })
}
process.stdout.write(`Authenticated staging smoke passed (credits=${credits.balance}, consent=${consent.revision}).\n`)

