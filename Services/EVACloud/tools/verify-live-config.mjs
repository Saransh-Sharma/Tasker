import { readFileSync } from 'node:fs'
import process from 'node:process'
import { compactVerify, importJWK } from 'jose'
import { assertLivePolicy } from './live-config-policy.mjs'

const target = process.argv[2]
if (target !== 'staging' && target !== 'production') {
  throw new Error('Usage: verify-live-config.mjs <staging|production>')
}

const expectedBuild = target === 'staging' ? 'Debug' : 'Release'
const project = readFileSync(new URL('../../../LifeBoard.xcodeproj/project.pbxproj', import.meta.url), 'utf8')
const buildBlocks = [...project.matchAll(/\/\* (Debug|Release) \*\/ = \{[\s\S]*?buildSettings = \{([\s\S]*?)\n\s*\};\n\s*name = \1;/gu)]
const buildSettings = buildBlocks
  .filter((match) => match[2]?.includes('EVA_CLOUD_BASE_URL'))
  .find((match) => match[1] === expectedBuild)?.[2]
if (!buildSettings) throw new Error(`Could not find the app's ${expectedBuild} EVA settings.`)

const setting = (name) => buildSettings.match(new RegExp(`\\b${name} = (?:"([^"]*)"|([^;]*));`, 'u'))
  ?.slice(1)
  .find((value) => value !== undefined)
  ?.trim()
const baseURL = setting('EVA_CLOUD_BASE_URL')?.replace(/\/$/u, '')
const publicKey = setting('EVA_CONFIG_SIGNING_PUBLIC_KEY')
if (!baseURL?.startsWith('https://')) throw new Error(`${expectedBuild} has no valid EVA cloud origin.`)
if (!publicKey || !/^[A-Za-z0-9_-]{43}$/u.test(publicKey)) throw new Error(`${expectedBuild} has no valid pinned config key.`)

const expected = JSON.parse(readFileSync(new URL(`../config/runtime-config.${target}.json`, import.meta.url), 'utf8'))
const healthResponse = await fetch(`${baseURL}/health`)
if (!healthResponse.ok) throw new Error(`Live ${target} health failed with ${healthResponse.status}.`)
const health = await healthResponse.json()
if (health.status !== 'ok' || health.environment !== target) {
  throw new Error(`Live ${target} health returned the wrong environment.`)
}

const configResponse = await fetch(`${baseURL}/v1/eva/config`)
if (!configResponse.ok) throw new Error(`Live ${target} config failed with ${configResponse.status}.`)
const envelope = await configResponse.json()
if (typeof envelope.signedConfiguration !== 'string') throw new Error(`Live ${target} config has no signed configuration.`)

const key = await importJWK({ kty: 'OKP', crv: 'Ed25519', x: publicKey }, 'EdDSA')
const verified = await compactVerify(envelope.signedConfiguration, key)
if (verified.protectedHeader.kid !== 'eva-config-v2') throw new Error(`Live ${target} config used the wrong key ID.`)
const actual = JSON.parse(new TextDecoder().decode(verified.payload))
assertLivePolicy(actual, expected)

process.stdout.write(
  `${target} live policy verified (version=${actual.version}, cloud=${actual.cloudState}, guest=${actual.guestAccess.bootstrapEnabled}, chat=${actual.routes.chat.enabled}).\n`
)
