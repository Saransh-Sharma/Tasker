import type { MiddlewareHandler } from 'hono'
import type { AppVariables, Env } from '../environment.js'
import { EvaHttpError } from '../http/errors.js'
import { verifyAccessToken } from './session.js'

export const requireSession: MiddlewareHandler<{ Bindings: Env; Variables: AppVariables }> = async (context, next) => {
  const authorization = context.req.header('Authorization')
  if (!authorization?.startsWith('Bearer ')) {
    throw new EvaHttpError(401, 'unauthenticated', 'Sign in to use Cloud EVA.', {
      recoveryAction: 'signIn',
    })
  }
  try {
    context.set('principal', await verifyAccessToken(context.env, authorization.slice('Bearer '.length)))
  } catch {
    throw new EvaHttpError(401, 'session_expired', 'Your EVA session has expired.', {
      recoveryAction: 'signIn',
    })
  }
  await next()
}
