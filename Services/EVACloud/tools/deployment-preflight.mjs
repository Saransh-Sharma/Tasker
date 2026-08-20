import { readFileSync } from 'node:fs'
import { spawnSync } from 'node:child_process'
import process from 'node:process'

const target = process.argv[2]
const checkRemoteSecrets = process.argv.includes('--remote-secrets')
if (target !== 'staging' && target !== 'production') {
  throw new Error('Usage: deployment-preflight.mjs <staging|production> [--remote-secrets]')
}

const requiredSecrets = [
  'OPENAI_API_KEY',
  'APPLE_TEAM_ID',
  'APPLE_KEY_ID',
  'APPLE_PRIVATE_KEY_P8',
  'APPLE_CLIENT_IDS',
  'APPLE_ROOT_CERTIFICATES_BASE64',
  'ACCOUNT_HMAC_KEY',
  'SESSION_SIGNING_PRIVATE_KEY',
  'TOKEN_ENCRYPTION_KEY',
  'CONFIG_SIGNING_PRIVATE_KEY',
  'APP_ATTEST_ENVIRONMENT',
]

const wrangler = readFileSync(new URL('../wrangler.toml', import.meta.url), 'utf8')
const project = readFileSync(new URL('../../../LifeBoard.xcodeproj/project.pbxproj', import.meta.url), 'utf8')
const sectionStart = wrangler.indexOf(`[env.${target}]`)
const nextEnvironment = target === 'staging' ? wrangler.indexOf('\n[env.production]', sectionStart + 1) : -1
if (sectionStart < 0) throw new Error(`Wrangler has no ${target} environment.`)
const environmentBlock = wrangler.slice(sectionStart, nextEnvironment < 0 ? undefined : nextEnvironment)

const kvMatch = environmentBlock.match(/kv_namespaces\]\][\s\S]*?\bid\s*=\s*"([0-9a-f]+)"/u)
const kvId = kvMatch?.[1]
if (!kvId || !/^[0-9a-f]{32}$/u.test(kvId) || /^([0-9a-f])\1{31}$/u.test(kvId)) {
  throw new Error(`${target} EVA_CONFIG must use a provisioned 32-character KV namespace ID.`)
}

const expected = target === 'production'
  ? {
      workerEnvironment: 'production', appStore: 'Production', build: 'Release', appAttest: 'production',
      origin: 'https://api.getlifeboard.app', workersDev: 'false',
    }
  : {
      workerEnvironment: 'staging', appStore: 'Sandbox', build: 'Debug', appAttest: 'development',
      origin: undefined, workersDev: 'true',
    }

for (const [name, value] of [
  ['ENVIRONMENT', expected.workerEnvironment],
  ['APP_STORE_ENVIRONMENT', expected.appStore],
]) {
  if (!environmentBlock.includes(`${name} = "${value}"`)) {
    throw new Error(`${target} ${name} must be ${value}.`)
  }
}
if (!environmentBlock.includes(`workers_dev = ${expected.workersDev}`)) {
  throw new Error(`${target} workers_dev must be ${expected.workersDev}.`)
}
if (expected.origin && !environmentBlock.includes(`pattern = "api.getlifeboard.app"`)) {
  throw new Error('Production must declare api.getlifeboard.app as its custom domain.')
}

const buildBlocks = [...project.matchAll(/\/\* (Debug|Release) \*\/ = \{[\s\S]*?buildSettings = \{([\s\S]*?)\n\s*\};\n\s*name = \1;/gu)]
const appBuildSettings = buildBlocks
  .filter((match) => match[2]?.includes('EVA_CLOUD_BASE_URL'))
  .find((match) => match[1] === expected.build)?.[2]
if (!appBuildSettings) throw new Error(`Could not find the app's ${expected.build} cloud build settings.`)

const setting = (name) => appBuildSettings.match(new RegExp(`\\b${name} = (?:"([^"]*)"|([^;]*));`, 'u'))?.slice(1).find((value) => value !== undefined)?.trim()
const origin = setting('EVA_CLOUD_BASE_URL')
const publicKey = setting('EVA_CONFIG_SIGNING_PUBLIC_KEY')
if (!origin || origin.endsWith('.invalid') || !origin.startsWith('https://')) {
  throw new Error(`${expected.build} EVA_CLOUD_BASE_URL must be a provisioned HTTPS origin.`)
}
if (expected.origin && origin !== expected.origin) {
  throw new Error(`Release EVA_CLOUD_BASE_URL must be ${expected.origin}.`)
}
if (setting('EVA_CLOUD_ENVIRONMENT') !== expected.workerEnvironment) {
  throw new Error(`${expected.build} EVA_CLOUD_ENVIRONMENT does not match ${target}.`)
}
if (setting('EVA_APP_ATTEST_ENVIRONMENT') !== expected.appAttest) {
  throw new Error(`${expected.build} EVA_APP_ATTEST_ENVIRONMENT does not match ${target}.`)
}
if (!publicKey || !/^[A-Za-z0-9_-]{43}$/u.test(publicKey)) {
  throw new Error(`${expected.build} EVA_CONFIG_SIGNING_PUBLIC_KEY must be a pinned 32-byte base64url key.`)
}

for (const secret of requiredSecrets) {
  if (!environmentBlock.includes(`"${secret}"`)) throw new Error(`${target} does not declare required secret ${secret}.`)
}

if (checkRemoteSecrets) {
  const listed = spawnSync('wrangler', ['secret', 'list', '--env', target, '--format', 'json'], {
    cwd: new URL('..', import.meta.url),
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'inherit'],
  })
  if (listed.status !== 0) throw new Error(`Could not list ${target} Worker secrets.`)
  const names = new Set(JSON.parse(listed.stdout).map((item) => item.name))
  const missing = requiredSecrets.filter((secret) => !names.has(secret))
  if (missing.length > 0) throw new Error(`${target} is missing Worker secrets: ${missing.join(', ')}`)
}

console.log(`${target} deployment preflight passed${checkRemoteSecrets ? ' with remote secret verification' : ''}.`)
