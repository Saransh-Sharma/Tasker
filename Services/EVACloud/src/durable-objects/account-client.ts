import type { EvaConsentPolicy, EvaCreditState } from '@lifeboard/eva-contracts'
import type { Env, SessionPrincipal } from '../environment.js'
import { durableJson, durableObjectStub } from './helpers.js'
import type { AccountAuthorization, EvaDeviceState } from './account-model.js'

export function accountStub(env: Env, accountId: string): DurableObjectStub {
  return durableObjectStub(env.EVA_ACCOUNTS, accountId)
}

export function authorizeAccount(
  env: Env,
  principal: SessionPrincipal,
  options: { requireAdult?: boolean; requireAttestation?: boolean } = {},
): Promise<AccountAuthorization> {
  return durableJson(accountStub(env, principal.accountId), '/authorize', {
    method: 'POST',
    body: JSON.stringify({
      familyId: principal.sessionFamilyId,
      installationId: principal.installationId,
      platform: principal.platform,
      requireAdult: options.requireAdult ?? true,
      requireAttestation: options.requireAttestation ?? true,
    }),
  })
}

export function getCredits(env: Env, accountId: string): Promise<EvaCreditState> {
  return durableJson(accountStub(env, accountId), '/credits')
}

export function getConsent(env: Env, accountId: string): Promise<EvaConsentPolicy> {
  return durableJson(accountStub(env, accountId), '/consent')
}

export function putConsent(
  env: Env,
  accountId: string,
  expectedRevision: number,
  grants: EvaConsentPolicy['grants'],
): Promise<EvaConsentPolicy> {
  return durableJson(accountStub(env, accountId), '/consent', {
    method: 'PUT',
    body: JSON.stringify({ expectedRevision, grants }),
  })
}

export function registerDeviceAge(
  env: Env,
  accountId: string,
  body: Pick<EvaDeviceState, 'installationId' | 'platform'> & {
    eligibleAdult: boolean
    declaration: string
  },
): Promise<{ eligibleAdult: boolean }> {
  return durableJson(accountStub(env, accountId), '/device/age', {
    method: 'POST',
    body: JSON.stringify(body),
  })
}
