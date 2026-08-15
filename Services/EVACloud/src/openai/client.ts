import OpenAI from 'openai'
import type { Env } from '../environment.js'

export function openAIClient(env: Env): OpenAI {
  if (!env.OPENAI_API_KEY) throw new Error('OPENAI_API_KEY is not configured.')
  return new OpenAI({ apiKey: env.OPENAI_API_KEY })
}
