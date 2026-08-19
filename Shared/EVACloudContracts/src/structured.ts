import { type Static, type TSchema, Type } from '@sinclair/typebox'
import type { EvaInferenceRequestV1, EvaRoute } from './index.js'
import { EvaUUIDSchema } from './primitives.js'

const ISODateTimePattern = '^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}(?:\\.\\d+)?(?:Z|[+-]\\d{2}:\\d{2})$'

const UUID = EvaUUIDSchema
const NullableUUID = Type.Union([UUID, Type.Null()])
const NullableDate = Type.Union([Type.String({ pattern: ISODateTimePattern }), Type.Null()])
const NullableDuration = Type.Union([Type.Number({ minimum: 60, maximum: 86_400 }), Type.Null()])
const CreateScheduledTaskSchema = Type.Object({
  type: Type.Literal('createScheduledTask'),
  projectID: UUID,
  title: Type.String({ minLength: 1, maxLength: 120 }),
  scheduledStartAt: Type.String({ pattern: ISODateTimePattern }),
  scheduledEndAt: Type.String({ pattern: ISODateTimePattern }),
  estimatedDuration: NullableDuration,
  lifeAreaID: NullableUUID,
  priority: Type.Union([Type.Literal('none'), Type.Literal('low'), Type.Literal('high'), Type.Literal('max'), Type.Null()]),
  energy: Type.Union([Type.Literal('low'), Type.Literal('medium'), Type.Literal('high'), Type.Null()]),
  category: Type.Union([Type.String({ minLength: 1, maxLength: 40 }), Type.Null()]),
  context: Type.Union([Type.String({ minLength: 1, maxLength: 40 }), Type.Null()]),
  details: Type.Union([Type.String({ maxLength: 2_000 }), Type.Null()]),
  tagIDs: Type.Array(UUID, { maxItems: 20, uniqueItems: true }),
}, { additionalProperties: false })

const CreateInboxTaskSchema = Type.Object({
  type: Type.Literal('createInboxTask'),
  projectID: UUID,
  title: Type.String({ minLength: 1, maxLength: 120 }),
  estimatedDuration: NullableDuration,
  lifeAreaID: NullableUUID,
  priority: Type.Union([Type.Literal('none'), Type.Literal('low'), Type.Literal('high'), Type.Literal('max'), Type.Null()]),
  category: Type.Union([Type.String({ minLength: 1, maxLength: 40 }), Type.Null()]),
  details: Type.Union([Type.String({ maxLength: 2_000 }), Type.Null()]),
  tagIDs: Type.Array(UUID, { maxItems: 20, uniqueItems: true }),
}, { additionalProperties: false })

const UpdateTaskScheduleSchema = Type.Object({
  type: Type.Literal('updateTaskSchedule'),
  taskID: UUID,
  scheduledStartAt: NullableDate,
  scheduledEndAt: NullableDate,
  estimatedDuration: NullableDuration,
  dueDate: NullableDate,
}, { additionalProperties: false })

export const EvaPlanResultSchema = Type.Object({
  schemaVersion: Type.Literal(3),
  commands: Type.Array(Type.Union([
    CreateScheduledTaskSchema,
    CreateInboxTaskSchema,
    UpdateTaskScheduleSchema,
  ]), { maxItems: 8 }),
  rationaleText: Type.String({ minLength: 1, maxLength: 1_200 }),
}, { $id: 'EvaPlanResultV1', additionalProperties: false })

export const EvaFieldSuggestionResultSchema = Type.Object({
  priority: Type.Union([Type.Literal('none'), Type.Literal('low'), Type.Literal('high'), Type.Literal('max')]),
  energy: Type.Union([Type.Literal('low'), Type.Literal('medium'), Type.Literal('high')]),
  type: Type.Union([Type.Literal('morning'), Type.Literal('evening'), Type.Literal('upcoming'), Type.Literal('inbox')]),
  context: Type.Union([
    Type.Literal('anywhere'), Type.Literal('home'), Type.Literal('office'), Type.Literal('computer'),
    Type.Literal('phone'), Type.Literal('errands'), Type.Literal('outdoor'), Type.Literal('gym'),
    Type.Literal('commute'), Type.Literal('meeting'),
  ]),
  rationale: Type.String({ minLength: 1, maxLength: 96 }),
  confidence: Type.Number({ minimum: 0, maximum: 1 }),
}, { $id: 'EvaFieldSuggestionResultV1', additionalProperties: false })

export const EvaTopThreeResultSchema = Type.Object({
  items: Type.Array(Type.Object({
    task_id: UUID,
    rationale: Type.String({ minLength: 1, maxLength: 160 }),
    confidence: Type.Number({ minimum: 0, maximum: 1 }),
  }, { additionalProperties: false }), { minItems: 1, maxItems: 3 }),
}, { $id: 'EvaTopThreeResultV1', additionalProperties: false })

export const EvaTaskBreakdownResultSchema = Type.Array(
  Type.String({ minLength: 1, maxLength: 180 }),
  { $id: 'EvaTaskBreakdownResultV1', minItems: 3, maxItems: 6, uniqueItems: true },
)

/**
 * The brief is no longer one opaque paragraph.
 *
 * v1 returned `{ brief }` and the client rendered it whole, which meant the
 * product could not tell a stated fact from a suggestion, could not show the
 * tradeoff separately, and could not link a claim back to the record it came
 * from. The roadmap's Day Compass measure is "what fits, what does not, and
 * why", and that is three fields, not one string.
 *
 * `brief` stays first and required so an older client that reads only that key
 * keeps working.
 */
export const EvaDailyBriefResultSchema = Type.Object({
  brief: Type.String({ minLength: 1, maxLength: 1_200 }),
  /** What is already fixed today — deadlines, calendar. Facts, not advice. */
  fixedCommitments: Type.Optional(Type.Array(Type.String({ minLength: 1, maxLength: 200 }), { maxItems: 6 })),
  /** The single most useful next move, named specifically. */
  nextMove: Type.Optional(Type.String({ minLength: 1, maxLength: 300 })),
  /**
   * What is being left out and why. When the day is over-committed this is the
   * point of the brief, so it is modelled rather than buried in prose.
   */
  tradeoff: Type.Optional(Type.Object({
    drop: Type.String({ minLength: 1, maxLength: 200 }),
    because: Type.String({ minLength: 1, maxLength: 300 }),
  }, { additionalProperties: false })),
  /** Identifiers from the supplied context that the brief actually rests on. */
  evidenceTaskIDs: Type.Optional(Type.Array(UUID, { maxItems: 10, uniqueItems: true })),
  /** True only when the capacity section says planned exceeds usable. */
  isOvercommitted: Type.Optional(Type.Boolean()),
}, { $id: 'EvaDailyBriefResultV2', additionalProperties: false })

export const EvaUniversalInputClassificationResultSchema = Type.Object({
  intent: Type.Union([
    Type.Literal('captureTask'), Type.Literal('captureNote'), Type.Literal('captureJournal'),
    Type.Literal('startPlanning'), Type.Literal('weeklyPlanner'), Type.Literal('dayRescue'),
    Type.Literal('overdueRescue'), Type.Literal('showSchedule'), Type.Literal('clarify'), Type.Literal('conversation'),
  ]),
  rawText: Type.Union([Type.String({ minLength: 1, maxLength: 4_000 }), Type.Null()]),
  clarifyOptions: Type.Array(Type.String({ minLength: 1, maxLength: 120 }), { maxItems: 4, uniqueItems: true }),
  confidence: Type.Number({ minimum: 0, maximum: 1 }),
}, { $id: 'EvaUniversalInputClassificationResultV1', additionalProperties: false })

export const EvaDynamicChipsResultSchema = Type.Object({
  chips: Type.Array(Type.String({ minLength: 1, maxLength: 60 }), { minItems: 3, maxItems: 6, uniqueItems: true }),
}, { $id: 'EvaDynamicChipsResultV1', additionalProperties: false })

export const EvaStructuredRouteSchemas = {
  plan: EvaPlanResultSchema,
  planRepair: EvaPlanResultSchema,
  fieldSuggestion: EvaFieldSuggestionResultSchema,
  topThree: EvaTopThreeResultSchema,
  taskBreakdown: EvaTaskBreakdownResultSchema,
  dailyBrief: EvaDailyBriefResultSchema,
  universalInputClassification: EvaUniversalInputClassificationResultSchema,
  dynamicChips: EvaDynamicChipsResultSchema,
} satisfies Partial<Record<EvaRoute, TSchema>>

export type EvaPlanResult = Static<typeof EvaPlanResultSchema>

export function structuredSchemaForRoute(route: EvaRoute): TSchema | undefined {
  return EvaStructuredRouteSchemas[route as keyof typeof EvaStructuredRouteSchemas]
}

const identifierFields = new Set(['taskID', 'task_id', 'projectID', 'targetProjectID', 'lifeAreaID', 'evidenceTaskIDs'])

export function semanticValidationError(
  route: EvaRoute,
  value: unknown,
  request: Pick<EvaInferenceRequestV1, 'context'>,
): string | undefined {
  if (route !== 'plan' && route !== 'planRepair' && route !== 'topThree' && route !== 'dailyBrief') return undefined
  const allowed = identifiersIn(request.context)
  const referenced = referencedIdentifiers(value)
  for (const identifier of referenced) {
    if (!allowed.has(identifier.toLowerCase())) return `Structured output referenced an identifier outside supplied context: ${identifier}`
  }
  if ((route === 'plan' || route === 'planRepair') && value && typeof value === 'object') {
    const commands = (value as { commands?: unknown }).commands
    if (Array.isArray(commands)) {
      for (const command of commands) {
        if (!command || typeof command !== 'object') continue
        const start = (command as { scheduledStartAt?: unknown }).scheduledStartAt
        const end = (command as { scheduledEndAt?: unknown }).scheduledEndAt
        if (typeof start === 'string' && typeof end === 'string' && Date.parse(end) <= Date.parse(start)) {
          return 'A scheduled task must end after it starts.'
        }
      }
    }
  }
  return undefined
}

function identifiersIn(value: unknown): Set<string> {
  const identifiers = new Set<string>()
  const visit = (candidate: unknown): void => {
    if (typeof candidate === 'string') {
      for (const match of candidate.matchAll(/[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}/giu)) {
        identifiers.add(match[0].toLowerCase())
      }
    } else if (Array.isArray(candidate)) {
      for (const item of candidate) visit(item)
    } else if (candidate && typeof candidate === 'object') {
      for (const item of Object.values(candidate as Record<string, unknown>)) visit(item)
    }
  }
  visit(value)
  return identifiers
}

function referencedIdentifiers(value: unknown): string[] {
  const values: string[] = []
  const visit = (candidate: unknown, key?: string): void => {
    if (typeof candidate === 'string' && key && (identifierFields.has(key) || key === 'tagIDs')) values.push(candidate)
    else if (Array.isArray(candidate)) {
      for (const item of candidate) visit(item, key)
    } else if (candidate && typeof candidate === 'object') {
      for (const [childKey, item] of Object.entries(candidate as Record<string, unknown>)) visit(item, childKey)
    }
  }
  visit(value)
  return values
}
