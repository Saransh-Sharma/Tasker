import type OpenAI from 'openai'
import { EvaHttpError } from '../http/errors.js'

export interface ModerationDecision {
  allowed: boolean
  selfHarm: boolean
}

/**
 * Below the moderation endpoint's input ceiling, with headroom.
 *
 * Contract v2 raised the context envelope from roughly 1.5K tokens to the
 * route's real input cap — up to 32K on `plan`. A single moderation call at that
 * size fails outright, and the failure mode is the worst kind: safety checks
 * error, so the request is refused, and it looks like a provider outage rather
 * than an input that outgrew one call.
 */
const maximumModerationChunkCharacters = 30_000

export function moderationChunks(text: string): string[] {
  if (text.length <= maximumModerationChunkCharacters) return [text]
  const chunks: string[] = []
  for (let offset = 0; offset < text.length; offset += maximumModerationChunkCharacters) {
    chunks.push(text.slice(offset, offset + maximumModerationChunkCharacters))
  }
  return chunks
}

export async function moderateText(client: OpenAI, text: string): Promise<ModerationDecision> {
  if (!text.trim()) return { allowed: true, selfHarm: false }
  // Chunks are evaluated together rather than in sequence: this sits on the
  // request's critical path before any model work begins.
  const assessments = await Promise.all(
    moderationChunks(text).map(async (chunk) => {
      const result = await client.moderations.create({ model: 'omni-moderation-latest', input: chunk })
      const assessment = result.results[0]
      if (!assessment) {
        throw new EvaHttpError(503, 'provider_unavailable', 'Safety checks are unavailable.', { retryable: true })
      }
      return assessment
    }),
  )
  // Any flagged chunk fails the whole input; splitting must not create a gap a
  // long payload could hide in.
  const selfHarm = assessments.some((assessment) => Object
    .entries(assessment.categories as unknown as Record<string, boolean>)
    .some(([key, value]) => value && key.startsWith('self-harm')))
  return { allowed: !assessments.some((assessment) => assessment.flagged), selfHarm }
}

export const supportiveSafetyResponse = `I’m really sorry you’re carrying this right now. You deserve immediate human support. If you may act on these thoughts or are in immediate danger, call your local emergency number now. Otherwise, contact a trusted person who can stay with you, and reach a crisis service in your country. If you can, move away from anything you could use to hurt yourself and tell me whether you’re in immediate danger.`
