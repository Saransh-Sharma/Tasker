import { Value } from '@sinclair/typebox/value'
import type { TSchema } from '@sinclair/typebox'
import { EvaHttpError } from './errors.js'

export const maximumBodyBytes = 256 * 1024

/** Runs before auth/attestation so oversized bodies cannot trigger expensive security work. */
export async function assertBodyWithinLimit(request: Request): Promise<void> {
  const declaredLength = Number(request.headers.get('content-length') ?? '0')
  if (Number.isFinite(declaredLength) && declaredLength > maximumBodyBytes) {
    throw new EvaHttpError(413, 'schema_invalid', 'The request is too large.')
  }
  if (request.method === 'GET' || request.method === 'HEAD' || !request.body) return
  const reader = request.clone().body?.getReader()
  if (!reader) return
  let bytes = 0
  try {
    while (true) {
      const chunk = await reader.read()
      if (chunk.done) break
      bytes += chunk.value.byteLength
      if (bytes > maximumBodyBytes) {
        await reader.cancel()
        throw new EvaHttpError(413, 'schema_invalid', 'The request is too large.')
      }
    }
  } finally {
    reader.releaseLock()
  }
}

export async function readJson<T>(request: Request, schema: TSchema): Promise<T> {
  const declaredLength = Number(request.headers.get('content-length') ?? '0')
  if (declaredLength > maximumBodyBytes) {
    throw new EvaHttpError(413, 'schema_invalid', 'The request is too large.')
  }
  const raw = await request.text()
  if (new TextEncoder().encode(raw).byteLength > maximumBodyBytes) {
    throw new EvaHttpError(413, 'schema_invalid', 'The request is too large.')
  }
  let value: unknown
  try {
    value = JSON.parse(raw)
  } catch {
    throw new EvaHttpError(400, 'schema_invalid', 'The request body is not valid JSON.')
  }
  if (!Value.Check(schema, value)) {
    throw new EvaHttpError(400, 'schema_invalid', 'The request does not match the EVA API contract.', {
      rejectedFields: rejectedContractFields(schema, value),
    })
  }
  return value as T
}

function rejectedContractFields(schema: TSchema, value: unknown): string[] {
  const fields = new Set<string>()
  for (const error of Value.Errors(schema, value)) {
    const topLevelField = error.path.split('/').find(Boolean)
    fields.add(topLevelField ?? '$body')
    if (fields.size >= 16) break
  }
  return [...fields].sort()
}
