import { readFile } from 'node:fs/promises'
import { inference, percentile, requiredEnvironment } from './staging-client.mjs'

if (process.env.EVA_CONFIRM_LIVE_EVAL !== 'YES') throw new Error('Set EVA_CONFIRM_LIVE_EVAL=YES to acknowledge live staging model cost.')
const baseURL = requiredEnvironment('EVA_STAGING_BASE_URL').replace(/\/$/u, '')
const accessToken = requiredEnvironment('EVA_STAGING_ACCESS_TOKEN')
const installationId = requiredEnvironment('EVA_STAGING_INSTALLATION_ID')
const consentRevision = Number(requiredEnvironment('EVA_STAGING_CONSENT_REVISION'))
const corpusURL = new URL('../eval/privacy-safe-corpus.json', import.meta.url)
const corpus = JSON.parse(await readFile(corpusURL, 'utf8'))
const latencies = []
let structured = 0

for (const testCase of corpus.cases) {
  const startedAt = performance.now()
  const events = await inference(baseURL, accessToken, {
    requestId: crypto.randomUUID(),
    route: testCase.route,
    contractVersion: 1,
    locale: 'en-US',
    timeZone: 'UTC',
    messages: [{ role: 'user', content: testCase.prompt }],
    context: testCase.context,
    clientVersion: '1.0.0',
    platform: 'catalyst',
    installationId,
    consentRevision,
    providerCapabilities: { streaming: true, structuredOutput: true, spokenOutput: true },
  })
  latencies.push(performance.now() - startedAt)
  if (events.some((event) => event.type === 'response.structured')) structured += 1
}

process.stdout.write(JSON.stringify({ cases: corpus.cases.length, structured, p95Milliseconds: percentile(latencies, 0.95) }, null, 2) + '\n')

