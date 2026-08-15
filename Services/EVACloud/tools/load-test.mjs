import { inference, percentile, requiredEnvironment } from './staging-client.mjs'

if (process.env.EVA_CONFIRM_LIVE_LOAD !== 'YES') throw new Error('Set EVA_CONFIRM_LIVE_LOAD=YES to acknowledge live staging traffic and model cost.')
const baseURL = requiredEnvironment('EVA_STAGING_BASE_URL').replace(/\/$/u, '')
const accessToken = requiredEnvironment('EVA_STAGING_ACCESS_TOKEN')
const installationId = requiredEnvironment('EVA_STAGING_INSTALLATION_ID')
const consentRevision = Number(requiredEnvironment('EVA_STAGING_CONSENT_REVISION'))
const requests = Math.min(600, Math.max(1, Number(process.env.EVA_LOAD_REQUESTS ?? 100)))
const concurrency = Math.min(20, Math.max(1, Number(process.env.EVA_LOAD_CONCURRENCY ?? 10)))
const latencies = []
let next = 0
let failures = 0

async function worker() {
  while (next < requests) {
    next += 1
    const startedAt = performance.now()
    try {
      await inference(baseURL, accessToken, {
        requestId: crypto.randomUUID(),
        route: 'universalInputClassification',
        contractVersion: 1,
        locale: 'en-US',
        timeZone: 'UTC',
        messages: [{ role: 'user', content: 'Capture a synthetic task for tomorrow morning.' }],
        context: [],
        clientVersion: '1.0.0',
        platform: 'catalyst',
        installationId,
        consentRevision,
        providerCapabilities: { streaming: true, structuredOutput: true, spokenOutput: false },
      })
      latencies.push(performance.now() - startedAt)
    } catch {
      failures += 1
    }
  }
}

await Promise.all(Array.from({ length: concurrency }, () => worker()))
const report = { requests, concurrency, successes: latencies.length, failures, p95Milliseconds: percentile(latencies, 0.95) }
process.stdout.write(JSON.stringify(report, null, 2) + '\n')
if (failures > 0) process.exitCode = 1

