import type { EvaConsentPolicy, EvaCreditState, EvaIdentityKind, EvaQuotaStateV1 } from '@lifeboard/eva-contracts'

export interface EvaDeviceState {
  installationId: string
  platform: 'ios' | 'catalyst'
  createdAt: number
  adultEligibleAt?: number
  adultEligibleExpiresAt?: number
  ageDeclaration?: string
  ageLowerBound?: number
  agePolicyRequired?: boolean
  trustTier?: 'high' | 'low'
  attestationKeyId?: string
  attestationPublicKey?: string
  attestationCounter?: number
  catalystRisk?: {
    appTransactionIdHash: string
    receiptEnvironment: string
    originalPlatform?: string
    verifiedAt: number
  }
  deviceCheckRisk?: {
    bit0: boolean
    bit1: boolean
    lastUpdatedAt?: string
    verifiedAt: number
  }
}

export interface RefreshFamilyState {
  familyId: string
  currentTokenHash: string
  currentGeneration?: number
  usedTokenHashes: string[]
  installationId: string
  authenticatedAt: number
  expiresAt: number
  revokedAt?: number
  identityKind?: EvaIdentityKind
}

export interface CreditReservation {
  requestId: string
  amount: number
  createdAt: number
  expiresAt: number
  status: 'reserved' | 'running' | 'committed' | 'released' | 'expired'
}

export interface QuotaReservation {
  requestId: string
  kind: 'billable' | 'helper'
  createdAt: number
  expiresAt: number
  status: 'reserved' | 'running' | 'committed' | 'released' | 'expired'
  committedAt?: number
}

export interface CostReservation {
  requestId: string
  globalRequestId: string
  amountMicroUsd: number
  actualMicroUsd?: number
  globalSettled?: boolean
  createdAt: number
  expiresAt: number
  status: 'reserved' | 'running' | 'committed' | 'released' | 'expired'
}

export interface SpeechTicketState {
  ticketId: string
  responseRequestId: string
  textHash: string
  expiresAt: number
  state: 'unused' | 'generating' | 'consumed'
  paidReservationId?: string
  generationExpiresAt?: number
}

export interface EvaAccountState {
  accountId: string
  status: 'active' | 'deleted'
  createdAt: number
  identityKind: EvaIdentityKind
  guestBootstrapId?: string
  mergeFrozenForAccountId?: string
  encryptedAppleRefreshToken?: string
  appleClientId?: string
  credits: {
    balance: number
    capacity: number
    refillAmount: number
    refillPeriodMs: number
    refillAnchor: number
  }
  quota: {
    limit: number
    helperLimit: number
    windowMs: number
    reservations: Record<string, QuotaReservation>
  }
  consent: EvaConsentPolicy
  devices: Record<string, EvaDeviceState>
  attestationChallenges: Record<string, { installationId: string; expiresAt: number }>
  refreshFamilies: Record<string, RefreshFamilyState>
  creditReservations: Record<string, CreditReservation>
  speechTickets: Record<string, SpeechTicketState>
  cost: {
    hourlyCommittedMicroUsd: Record<string, number>
    reservations: Record<string, CostReservation>
  }
  completedMergeIds?: string[]
}

export interface AccountAuthorization {
  authorized: boolean
  reason?: 'session' | 'age' | 'attestation' | 'deleted'
  credits?: EvaCreditState
  quota?: EvaQuotaStateV1
  consent?: EvaConsentPolicy
  identityKind?: EvaIdentityKind
  trustTier?: 'high' | 'low'
}
