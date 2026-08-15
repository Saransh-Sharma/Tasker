import { generateKeyPairSync, randomBytes } from 'node:crypto'
import { mkdirSync, openSync, writeFileSync, closeSync } from 'node:fs'
import process from 'node:process'

const environment = process.argv[2]
if (!['development', 'staging', 'production'].includes(environment)) {
  throw new Error('Usage: generate-environment-keys.mjs <development|staging|production>')
}

const outputDirectory = new URL(`../../../.eva-provisioning/${environment}/`, import.meta.url)
mkdirSync(outputDirectory, { recursive: true, mode: 0o700 })

function ed25519Pair() {
  const { privateKey, publicKey } = generateKeyPairSync('ed25519')
  return {
    privateJwk: privateKey.export({ format: 'jwk' }),
    publicJwk: publicKey.export({ format: 'jwk' }),
  }
}

function base64url(byteCount) {
  return randomBytes(byteCount).toString('base64url')
}

function writePrivateFile(name, value) {
  const descriptor = openSync(new URL(name, outputDirectory), 'wx', 0o600)
  try {
    writeFileSync(descriptor, `${JSON.stringify(value, null, 2)}\n`, { encoding: 'utf8' })
  } finally {
    closeSync(descriptor)
  }
}

const session = ed25519Pair()
const configuration = ed25519Pair()
writePrivateFile('generated-secrets.json', {
  environment,
  ACCOUNT_HMAC_KEY: base64url(32),
  SESSION_SIGNING_PRIVATE_KEY: JSON.stringify(session.privateJwk),
  TOKEN_ENCRYPTION_KEY: base64url(32),
  CONFIG_SIGNING_PRIVATE_KEY: JSON.stringify(configuration.privateJwk),
})
writePrivateFile('public-pins.json', {
  environment,
  sessionSigningPublicJwk: session.publicJwk,
  configurationSigningPublicJwk: configuration.publicJwk,
  EVA_CONFIG_SIGNING_PUBLIC_KEY: configuration.publicJwk.x,
})

console.log(`Generated isolated ${environment} key material under .eva-provisioning/${environment}/.`)
console.log('Private values were not printed. Move them into your approved secret manager, then delete the local files.')
