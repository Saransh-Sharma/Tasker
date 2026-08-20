import { Type } from '@sinclair/typebox'

export const EvaUUIDPattern = '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$'

/**
 * Canonical UUID schema for all EVA wire contracts. A pattern is used instead
 * of JSON Schema's `uuid` format because TypeBox does not register format
 * validators implicitly at runtime.
 */
export const EvaUUIDSchema = Type.String({ pattern: EvaUUIDPattern })

export const EvaPlatformSchema = Type.Union([
  Type.Literal('ios'),
  Type.Literal('catalyst'),
])
