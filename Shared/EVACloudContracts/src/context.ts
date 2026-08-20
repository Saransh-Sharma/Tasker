import { type Static, Type } from '@sinclair/typebox'
import { Value } from '@sinclair/typebox/value'
import { EvaUUIDSchema } from './primitives.js'

/**
 * Typed payloads for the contract-v2 context envelope.
 *
 * Contract v1 carried `payload: unknown`, which meant the projection could drift
 * on the client without anything on the server noticing until a prompt started
 * reading a field that was no longer there. Each category now declares its
 * shape, so a drifted projection fails at the request boundary with
 * `schema_invalid` instead of silently degrading answer quality.
 *
 * Two rules hold across every schema below:
 *
 * 1. **Minutes, not seconds, and never wall-clock strings for durations.** The
 *    model reasons about capacity arithmetic far more reliably in one unit.
 * 2. **Identifiers are always present on anything the model may reference in a
 *    structured result.** `semanticValidationError` authorizes a returned
 *    `taskID`/`projectID` by scanning this envelope; an identifier that never
 *    crossed the wire here cannot be named in an answer.
 */

const ISODateTimePattern = '^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}(?:\\.\\d+)?(?:Z|[+-]\\d{2}:\\d{2})$'
const ISODateTime = Type.String({ pattern: ISODateTimePattern })
const ShortText = (maxLength: number) => Type.String({ minLength: 1, maxLength })

/**
 * Absent and null mean the same thing here: not known.
 *
 * Swift's synthesized `Encodable` uses `encodeIfPresent` for optionals, so a nil
 * property is omitted from the JSON rather than written as `null`. A schema that
 * demanded an explicit null would reject every request the client actually
 * sends, while `additionalProperties: false` still keeps the shape closed.
 */
const Nullable = <T extends ReturnType<typeof Type.String>>(schema: T) =>
  Type.Optional(Type.Union([schema, Type.Null()]))
const NullableISODateTime = Type.Optional(Type.Union([ISODateTime, Type.Null()]))
const NullableShortText = (maxLength: number) => Nullable(ShortText(maxLength))
const NullableInteger = (options: Parameters<typeof Type.Integer>[0]) =>
  Type.Optional(Type.Union([Type.Integer(options), Type.Null()]))
const NullableFraction = Type.Optional(Type.Union([Type.Number({ minimum: 0, maximum: 1 }), Type.Null()]))

export const EvaPrioritySchema = Type.Union([
  Type.Literal('none'), Type.Literal('low'), Type.Literal('high'), Type.Literal('max'),
])
export const EvaEnergySchema = Type.Union([
  Type.Literal('low'), Type.Literal('medium'), Type.Literal('high'),
])

/**
 * One task as EVA sees it.
 *
 * `deferredCount` and `replanCount` are the fields that change the character of
 * an answer: they are the difference between listing work back to someone and
 * being able to say "you have moved this four times, it is not going to happen
 * this week." v1 dropped both.
 */
export const EvaTaskRecordSchema = Type.Object({
  id: EvaUUIDSchema,
  title: ShortText(200),
  project: NullableShortText(120),
  projectID: Type.Optional(Type.Union([EvaUUIDSchema, Type.Null()])),
  lifeArea: NullableShortText(120),
  priority: EvaPrioritySchema,
  energy: Type.Optional(Type.Union([EvaEnergySchema, Type.Null()])),
  estimatedMinutes: NullableInteger({ minimum: 0, maximum: 1_440 }),
  actualMinutes: NullableInteger({ minimum: 0, maximum: 1_440 }),
  due: NullableISODateTime,
  scheduledStart: NullableISODateTime,
  scheduledEnd: NullableISODateTime,
  bucket: Type.Union([
    Type.Literal('overdue'), Type.Literal('today'), Type.Literal('tomorrow'),
    Type.Literal('thisWeek'), Type.Literal('unscheduled'), Type.Literal('completed'),
  ]),
  /** How many times the person has pushed this to a later day. */
  deferredCount: Type.Integer({ minimum: 0 }),
  /** How many times its schedule has been rewritten by a planning mutation. */
  replanCount: Type.Integer({ minimum: 0 }),
  ageDays: Type.Integer({ minimum: 0 }),
  notesExcerpt: NullableShortText(400),
  blockedBy: Type.Array(EvaUUIDSchema, { maxItems: 8 }),
  /** Why the deterministic ranker placed this where it did, when it ranked it. */
  rankReasons: Type.Array(ShortText(120), { maxItems: 4 }),
}, { additionalProperties: false })
export type EvaTaskRecord = Static<typeof EvaTaskRecordSchema>

export const EvaPlanningContextSchema = Type.Object({
  generatedAt: ISODateTime,
  summary: Type.Object({
    overdue: Type.Integer({ minimum: 0 }),
    today: Type.Integer({ minimum: 0 }),
    tomorrow: Type.Integer({ minimum: 0 }),
    thisWeek: Type.Integer({ minimum: 0 }),
    unscheduled: Type.Integer({ minimum: 0 }),
    completedToday: Type.Integer({ minimum: 0 }),
  }, { additionalProperties: false }),
  tasks: Type.Array(EvaTaskRecordSchema, { maxItems: 200 }),
  projects: Type.Array(Type.Object({
    id: EvaUUIDSchema,
    name: ShortText(120),
    lifeArea: NullableShortText(120),
    openTaskCount: Type.Integer({ minimum: 0 }),
    motivationWhy: NullableShortText(400),
  }, { additionalProperties: false }), { maxItems: 40 }),
  lifeAreas: Type.Array(Type.Object({
    id: EvaUUIDSchema,
    name: ShortText(120),
    openTaskCount: Type.Integer({ minimum: 0 }),
  }, { additionalProperties: false }), { maxItems: 20 }),
  /** Sections the client could not build in time, so absence reads as unknown
   *  rather than as zero. */
  partialSections: Type.Array(ShortText(40), { maxItems: 12 }),
  /** The plain-text overview, carried alongside the records so the model gets a
   *  rendered summary without having to reduce 200 objects itself.
   *
   *  It is also the whole payload on the degraded path: when the rich projection
   *  is unavailable the client still emits this shape with an empty `tasks`
   *  array, so the envelope never changes shape depending on how well the
   *  projection went. */
  renderedOverview: NullableShortText(8_000),
  /** Fourteen-day operating summary, when the client built one. */
  executiveState: NullableShortText(4_000),
  /** Pinned slash-command context, when any pins are active. */
  slashCommandState: NullableShortText(4_000),
  /** Which projection produced this section, for route-specific prompting. */
  kind: NullableShortText(40),
}, { additionalProperties: false })

/**
 * What actually fits. Without this EVA has no way to distinguish an ambitious
 * day from an impossible one, which is how "capacity before ambition" degrades
 * into a denser plan.
 */
export const EvaCapacityContextSchema = Type.Object({
  day: ISODateTime,
  workingMinutes: Type.Integer({ minimum: 0 }),
  fixedCalendarMinutes: Type.Integer({ minimum: 0 }),
  bufferMinutes: Type.Integer({ minimum: 0 }),
  usableMinutes: Type.Integer({ minimum: 0 }),
  plannedMinutes: Type.Integer({ minimum: 0 }),
  /** Positive means committed beyond what the day holds. */
  overloadMinutes: Type.Integer(),
  confidence: Type.Union([Type.Literal('low'), Type.Literal('medium'), Type.Literal('high')]),
  freeWindows: Type.Array(Type.Object({
    start: ISODateTime,
    end: ISODateTime,
    minutes: Type.Integer({ minimum: 0 }),
  }, { additionalProperties: false }), { maxItems: 24 }),
}, { additionalProperties: false })

export const EvaGoalsContextSchema = Type.Array(Type.Object({
  id: EvaUUIDSchema,
  title: ShortText(200),
  whyItMatters: NullableShortText(400),
  status: ShortText(40),
  confidence: NullableShortText(40),
  targetDate: NullableISODateTime,
  progressFraction: NullableFraction,
  riskReason: NullableShortText(200),
}, { additionalProperties: false }), { maxItems: 30 })

export const EvaHabitsContextSchema = Type.Array(Type.Object({
  id: EvaUUIDSchema,
  title: ShortText(200),
  lifeArea: NullableShortText(120),
  dueToday: Type.Boolean(),
  isOverdue: Type.Boolean(),
  currentStreak: Type.Integer({ minimum: 0 }),
  bestStreak: Type.Integer({ minimum: 0 }),
  /** Completed-eligible over eligible-due across the grading window. */
  adherenceFraction: NullableFraction,
  /** Oldest day first, so index order is chronological. */
  last14Days: Type.Array(
    Type.Union([Type.Literal('hit'), Type.Literal('miss'), Type.Literal('skip'), Type.Literal('offDay'), Type.Literal('unknown')]),
    { maxItems: 14 },
  ),
  bestTimeMinutesFromMidnight: NullableInteger({ minimum: 0, maximum: 1_439 }),
}, { additionalProperties: false }), { maxItems: 40 })

/** Whether the person is actually running the day loop, and how yesterday ended. */
export const EvaDayLoopContextSchema = Type.Object({
  eligibleDays: Type.Integer({ minimum: 0 }),
  closedDays: Type.Integer({ minimum: 0 }),
  openedDays: Type.Integer({ minimum: 0 }),
  currentRunLength: Type.Integer({ minimum: 0 }),
  reversals: Type.Integer({ minimum: 0 }),
  lastClose: Type.Optional(Type.Union([Type.Object({
    day: ISODateTime,
    plannedMinutes: Type.Integer({ minimum: 0 }),
    focusedMinutes: Type.Integer({ minimum: 0 }),
    completedCount: Type.Integer({ minimum: 0 }),
    unfinishedCount: Type.Integer({ minimum: 0 }),
    focusRatio: Type.Number({ minimum: 0, maximum: 1 }),
  }, { additionalProperties: false }), Type.Null()])),
}, { additionalProperties: false })

/** The person's own words about the week — never paraphrased on the client. */
export const EvaRetrospectiveContextSchema = Type.Object({
  weekStart: NullableISODateTime,
  focusStatement: NullableShortText(400),
  outcomes: Type.Array(Type.Object({
    title: ShortText(200),
    whyItMatters: NullableShortText(400),
    successDefinition: NullableShortText(400),
    status: ShortText(40),
  }, { additionalProperties: false }), { maxItems: 10 }),
  wins: NullableShortText(1_000),
  blockers: NullableShortText(1_000),
  lessons: NullableShortText(1_000),
  perceivedWeekRating: NullableInteger({ minimum: 0, maximum: 10 }),
}, { additionalProperties: false })

/** Read-only and title-optional: a busy block constrains the day even when its
 *  title is withheld. */
export const EvaCalendarContextSchema = Type.Array(Type.Object({
  title: NullableShortText(200),
  start: ISODateTime,
  end: ISODateTime,
  isAllDay: Type.Boolean(),
  isBusy: Type.Boolean(),
}, { additionalProperties: false }), { maxItems: 60 })

export const EvaConversationSummaryContextSchema = Type.Object({
  summarizedTurnCount: Type.Integer({ minimum: 0 }),
  summary: ShortText(4_000),
}, { additionalProperties: false })

/** Versioned statements, each tagged with where it came from. An inference must
 *  never be indistinguishable from something the person actually said. */
export const EvaPersonalMemoryContextSchema = Type.Array(Type.Object({
  id: EvaUUIDSchema,
  section: Type.Union([
    Type.Literal('preferences'), Type.Literal('routines'),
    Type.Literal('currentGoals'), Type.Literal('capacity'), Type.Literal('boundaries'),
  ]),
  text: ShortText(400),
  provenance: Type.Union([Type.Literal('userStated'), Type.Literal('inferred')]),
  confidence: NullableFraction,
  effectiveFrom: NullableISODateTime,
}, { additionalProperties: false }), { maxItems: 60 })

/** Unchanged from v1: already-authorized, already-redacted evidence events. */
export const EvaEvidenceContextSchema = Type.Array(Type.Object({
  reference: ShortText(40),
  domain: ShortText(40),
  kind: ShortText(40),
  occurredAt: ISODateTime,
  freshness: ShortText(40),
  source: Type.Optional(ShortText(1_000)),
  value: Type.Optional(Type.Number()),
}, { additionalProperties: false }), { maxItems: 120 })

export const EvaContextPayloadSchemas = {
  planning: EvaPlanningContextSchema,
  capacity: EvaCapacityContextSchema,
  goals: EvaGoalsContextSchema,
  habits: EvaHabitsContextSchema,
  dayLoop: EvaDayLoopContextSchema,
  retrospective: EvaRetrospectiveContextSchema,
  calendar: EvaCalendarContextSchema,
  conversationSummary: EvaConversationSummaryContextSchema,
  personalMemory: EvaPersonalMemoryContextSchema,
  journal: EvaEvidenceContextSchema,
  health: EvaEvidenceContextSchema,
  lifeMoments: EvaEvidenceContextSchema,
} as const

export type EvaContextCategoryName = keyof typeof EvaContextPayloadSchemas

/**
 * Validates each section against its category's schema.
 *
 * Applied only to contract v2. A v1 client sends the older free-form payloads
 * and must keep working unchanged through its deprecation window, so validating
 * it here would reject requests that were valid when that build shipped.
 */
export function contextPayloadError(
  contractVersion: number,
  context: readonly { category: string; payload: unknown }[],
): string | undefined {
  if (contractVersion < 2) return undefined
  const seen = new Set<string>()
  for (const section of context) {
    if (seen.has(section.category)) return `Duplicate context section: ${section.category}`
    seen.add(section.category)
    const schema = EvaContextPayloadSchemas[section.category as EvaContextCategoryName]
    if (!schema) return `Unknown context category: ${section.category}`
    if (!Value.Check(schema, section.payload)) {
      const first = [...Value.Errors(schema, section.payload)][0]
      return `Context section ${section.category} does not match its schema${first ? ` at ${first.path || '/'}` : ''}.`
    }
  }
  return undefined
}
