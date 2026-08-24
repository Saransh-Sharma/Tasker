import { mkdirSync, readFileSync, writeFileSync } from 'node:fs'
import { dirname, resolve } from 'node:path'
import process from 'node:process'

const environment = process.argv[2]
if (environment !== 'staging' && environment !== 'production') {
  throw new Error('Usage: prepare-runtime-config-rollback.mjs <staging|production>')
}

const serviceRoot = resolve(import.meta.dirname, '..')
const sourcePath = resolve(serviceRoot, 'config', `runtime-config.${environment}.json`)
const outputPath = resolve(serviceRoot, '..', '..', '.eva-provisioning', `runtime-config.${environment}.rollback.json`)
const source = JSON.parse(readFileSync(sourcePath, 'utf8'))

const rollback = {
  ...source,
  version: source.version + 1,
  issuedAt: new Date().toISOString(),
  cloudState: 'disabled',
  ttsEnabled: false,
  maintenanceMessage: 'Cloud EVA is temporarily unavailable. Offline EVA and ordinary LifeBoard remain available.',
  guestAccess: {
    ...source.guestAccess,
    bootstrapEnabled: false,
    inferenceEnabled: false,
    appleLinkingEnabled: false,
    rolloutPercent: 0,
  },
  routes: Object.fromEntries(
    Object.entries(source.routes).map(([name, policy]) => [name, { ...policy, enabled: false }]),
  ),
}

mkdirSync(dirname(outputPath), { recursive: true })
writeFileSync(outputPath, `${JSON.stringify(rollback, null, 2)}\n`, { mode: 0o600 })
console.log(`Prepared ${environment} rollback policy v${rollback.version} at ${outputPath}`)
