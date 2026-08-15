const encoder = new TextEncoder()
const decoder = new TextDecoder()

export function base64UrlEncode(value: ArrayBuffer | Uint8Array): string {
  const bytes = value instanceof Uint8Array ? value : new Uint8Array(value)
  let binary = ''
  for (const byte of bytes) binary += String.fromCharCode(byte)
  return btoa(binary).replaceAll('+', '-').replaceAll('/', '_').replace(/=+$/u, '')
}

export function base64UrlDecode(value: string): Uint8Array<ArrayBuffer> {
  const normalized = value.replaceAll('-', '+').replaceAll('_', '/')
  const padded = normalized.padEnd(Math.ceil(normalized.length / 4) * 4, '=')
  const binary = atob(padded)
  const bytes = new Uint8Array(binary.length)
  for (let index = 0; index < binary.length; index += 1) {
    bytes[index] = binary.charCodeAt(index)
  }
  return bytes
}

export async function sha256(value: string | Uint8Array): Promise<string> {
  const bytes = typeof value === 'string' ? encoder.encode(value) : value
  const copy = Uint8Array.from(bytes)
  return base64UrlEncode(await crypto.subtle.digest('SHA-256', copy.buffer))
}

export async function hmacSha256(key: string, value: string): Promise<string> {
  const cryptoKey = await crypto.subtle.importKey(
    'raw',
    encoder.encode(key),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  )
  return base64UrlEncode(await crypto.subtle.sign('HMAC', cryptoKey, encoder.encode(value)))
}

export function randomToken(byteCount = 32): string {
  return base64UrlEncode(crypto.getRandomValues(new Uint8Array(byteCount)))
}

export function parsePrivateJwk(value: string): JsonWebKey {
  const parsed: unknown = JSON.parse(value)
  if (!parsed || typeof parsed !== 'object' || !('d' in parsed) || !('x' in parsed)) {
    throw new Error('Signing key must be a private Ed25519 JWK.')
  }
  return parsed as JsonWebKey
}

export function publicJwk(privateJwk: JsonWebKey): JsonWebKey {
  const publicComponents = { ...privateJwk }
  delete publicComponents.d
  return publicComponents
}

export async function encryptString(keyMaterial: string, plaintext: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    'raw',
    base64UrlDecode(keyMaterial),
    { name: 'AES-GCM' },
    false,
    ['encrypt'],
  )
  const iv = crypto.getRandomValues(new Uint8Array(12))
  const ciphertext = await crypto.subtle.encrypt({ name: 'AES-GCM', iv }, key, encoder.encode(plaintext))
  return `${base64UrlEncode(iv)}.${base64UrlEncode(ciphertext)}`
}

export async function decryptString(keyMaterial: string, sealed: string): Promise<string> {
  const [ivValue, ciphertextValue] = sealed.split('.')
  if (!ivValue || !ciphertextValue) throw new Error('Malformed encrypted value.')
  const key = await crypto.subtle.importKey(
    'raw',
    base64UrlDecode(keyMaterial),
    { name: 'AES-GCM' },
    false,
    ['decrypt'],
  )
  const plaintext = await crypto.subtle.decrypt(
    { name: 'AES-GCM', iv: base64UrlDecode(ivValue) },
    key,
    base64UrlDecode(ciphertextValue),
  )
  return decoder.decode(plaintext)
}
