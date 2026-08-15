import type OpenAI from 'openai'
import { EvaHttpError } from '../http/errors.js'

export interface ModerationDecision {
  allowed: boolean
  selfHarm: boolean
}

export async function moderateText(client: OpenAI, text: string): Promise<ModerationDecision> {
  if (!text.trim()) return { allowed: true, selfHarm: false }
  const result = await client.moderations.create({ model: 'omni-moderation-latest', input: text })
  const assessment = result.results[0]
  if (!assessment) throw new EvaHttpError(503, 'provider_unavailable', 'Safety checks are unavailable.', { retryable: true })
  const categories = assessment.categories as unknown as Record<string, boolean>
  const selfHarm = Object.entries(categories).some(([key, value]) => value && key.startsWith('self-harm'))
  return { allowed: !assessment.flagged, selfHarm }
}

export const supportiveSafetyResponse = `I’m really sorry you’re carrying this right now. You deserve immediate human support. If you may act on these thoughts or are in immediate danger, call your local emergency number now. Otherwise, contact a trusted person who can stay with you, and reach a crisis service in your country. If you can, move away from anything you could use to hurt yourself and tell me whether you’re in immediate danger.`
