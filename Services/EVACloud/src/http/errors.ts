import type { EvaCreditState, EvaErrorCode, EvaErrorEnvelope, EvaQuotaStateV1 } from '@lifeboard/eva-contracts'

export class EvaHttpError extends Error {
  constructor(
    readonly status: number,
    readonly code: EvaErrorCode,
    message: string,
    readonly options: {
      retryable?: boolean
      retryAfter?: number
      credits?: EvaCreditState
      quota?: EvaQuotaStateV1
      recoveryAction?: EvaErrorEnvelope['recoveryAction']
      /** Top-level schema field names only. Never include field values. */
      rejectedFields?: readonly string[]
    } = {},
  ) {
    super(message)
  }

  envelope(requestId: string): EvaErrorEnvelope {
    return {
      code: this.code,
      message: this.message,
      requestId,
      retryable: this.options.retryable ?? false,
      ...(this.options.retryAfter === undefined ? {} : { retryAfter: this.options.retryAfter }),
      ...(this.options.credits === undefined ? {} : { credits: this.options.credits }),
      ...(this.options.quota === undefined ? {} : { quota: this.options.quota }),
      ...(this.options.recoveryAction === undefined ? {} : { recoveryAction: this.options.recoveryAction }),
    }
  }
}

export function jsonError(error: EvaHttpError, requestId: string): Response {
  return Response.json(error.envelope(requestId), {
    status: error.status,
    headers: error.options.retryAfter === undefined
      ? undefined
      : { 'Retry-After': String(error.options.retryAfter) },
  })
}
