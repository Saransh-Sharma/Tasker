import { importJWK, jwtVerify, SignJWT } from 'jose'
import type { Env } from '../environment.js'
import { parsePrivateJwk, publicJwk } from '../security/crypto.js'

export interface SpeechTicketClaims {
  accountId: string
  ticketId: string
  responseRequestId: string
  textHash: string
  expiresAt: number
}

export async function issueSpeechTicket(env: Env, claims: SpeechTicketClaims): Promise<string> {
  const key = await importJWK(parsePrivateJwk(env.SESSION_SIGNING_PRIVATE_KEY), 'EdDSA')
  return new SignJWT({ request_id: claims.responseRequestId, text_hash: claims.textHash })
    .setProtectedHeader({ alg: 'EdDSA', kid: 'eva-speech-v1' })
    .setIssuer('https://api.getlifeboard.app')
    .setAudience('lifeboard-eva-speech')
    .setSubject(claims.accountId)
    .setJti(claims.ticketId)
    .setIssuedAt()
    .setExpirationTime(Math.floor(claims.expiresAt / 1_000))
    .sign(key)
}

export async function verifySpeechTicket(env: Env, token: string): Promise<SpeechTicketClaims> {
  const key = await importJWK(publicJwk(parsePrivateJwk(env.SESSION_SIGNING_PRIVATE_KEY)), 'EdDSA')
  const { payload } = await jwtVerify(token, key, {
    issuer: 'https://api.getlifeboard.app',
    audience: 'lifeboard-eva-speech',
  })
  if (!payload.sub || !payload.jti || typeof payload.request_id !== 'string' || typeof payload.text_hash !== 'string' || !payload.exp) {
    throw new Error('Speech ticket claims are incomplete.')
  }
  return {
    accountId: payload.sub,
    ticketId: payload.jti,
    responseRequestId: payload.request_id,
    textHash: payload.text_hash,
    expiresAt: payload.exp * 1_000,
  }
}
