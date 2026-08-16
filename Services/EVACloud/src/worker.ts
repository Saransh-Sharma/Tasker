import { Hono } from 'hono'
import type { AppVariables, Env } from './environment.js'
import { authRoutes } from './auth/routes.js'
import { attestationRoutes } from './attestation/routes.js'
import { accountRoutes } from './routes/account.js'
import { responseRoutes } from './routes/responses.js'
import { speechRoutes } from './routes/speech.js'
import { signedRuntimeConfig } from './config/runtime-config.js'
import { EvaHttpError, jsonError } from './http/errors.js'
import { recordTelemetry } from './telemetry/events.js'
import { assertBodyWithinLimit } from './http/body.js'

export { AuthChallengeDO } from './durable-objects/AuthChallengeDO.js'
export { EvaAccountDO } from './durable-objects/EvaAccountDO.js'
export { GlobalBudgetDO } from './durable-objects/GlobalBudgetDO.js'

const app = new Hono<{ Bindings: Env; Variables: AppVariables }>()

app.use('*', async (context, next) => {
  const suppliedRequestId = context.req.header('X-Request-ID')
  const requestId = suppliedRequestId && /^[0-9a-f-]{36}$/iu.test(suppliedRequestId)
    ? suppliedRequestId
    : crypto.randomUUID()
  context.set('requestId', requestId)
  await assertBodyWithinLimit(context.req.raw)
  if (context.req.header('Origin')) {
    throw new EvaHttpError(403, 'input_rejected', 'Browser-originated requests are not accepted.')
  }
  if (context.req.method === 'OPTIONS') {
    throw new EvaHttpError(405, 'input_rejected', 'Cross-origin preflight requests are not supported.')
  }
  const limiter = limiterForPath(context.env, context.req.path)
  const limited = await limiter.limit({
    key: `${context.req.header('CF-Connecting-IP') ?? 'unknown'}:${new URL(context.req.url).pathname}`,
  })
  if (!limited.success) {
    throw new EvaHttpError(429, 'rate_limited', 'Too many requests. Try again shortly.', {
      retryable: true, retryAfter: 60, recoveryAction: 'wait',
    })
  }
  const startedAt = Date.now()
  await next()
  context.header('X-Request-ID', requestId)
  context.header('X-Content-Type-Options', 'nosniff')
  context.header('Referrer-Policy', 'no-referrer')
  context.header('Permissions-Policy', 'camera=(), microphone=(), geolocation=()')
  context.header('Cache-Control', context.req.path === '/health' ? 'no-cache' : 'no-store')
  recordTelemetry(context.env, {
    event: 'http_request',
    requestId,
    status: String(context.res.status),
    route: context.req.path,
    durationMs: Date.now() - startedAt,
  })
})

app.get('/health', (context) => context.json({
  status: 'ok',
  service: 'eva-cloud',
  apiVersion: context.env.EVA_API_VERSION,
  environment: context.env.ENVIRONMENT,
}))

app.get('/v1/eva/config', async (context) => context.json({
  format: 'compact-jws',
  signedConfiguration: await signedRuntimeConfig(context.env),
}))

app.route('/v1/auth', authRoutes)
app.route('/v1/attestation', attestationRoutes)
app.route('/v1', accountRoutes)
app.route('/v1/eva', responseRoutes)
app.route('/v1/eva', speechRoutes)

app.notFound(() => {
  throw new EvaHttpError(404, 'schema_invalid', 'The requested EVA endpoint does not exist.')
})

app.onError((error, context) => {
  const requestId = context.get('requestId') ?? crypto.randomUUID()
  const safeError = error instanceof EvaHttpError
    ? error
    : new EvaHttpError(500, 'provider_unavailable', 'Cloud EVA encountered an unexpected error.', { retryable: true })
  if (safeError.code === 'schema_invalid' && safeError.options.rejectedFields?.length) {
    recordTelemetry(context.env, {
      event: 'contract_rejection',
      requestId,
      route: context.req.path,
      status: safeError.code,
      detail: safeError.options.rejectedFields.join(','),
    })
  }
  recordTelemetry(context.env, {
    event: 'http_error',
    requestId,
    route: context.req.path,
    status: safeError.code,
  })
  const response = jsonError(safeError, requestId)
  response.headers.set('X-Request-ID', requestId)
  response.headers.set('Cache-Control', 'no-store')
  response.headers.set('X-Content-Type-Options', 'nosniff')
  return response
})

export default app

function limiterForPath(env: Env, path: string): Env['EDGE_RATE_LIMITER'] {
  if (path === '/v1/eva/config') return env.CONFIG_RATE_LIMITER
  if (path === '/v1/auth/challenge') return env.AUTH_CHALLENGE_RATE_LIMITER
  if (path === '/v1/auth/apple/exchange') return env.APPLE_EXCHANGE_RATE_LIMITER
  return env.EDGE_RATE_LIMITER
}
