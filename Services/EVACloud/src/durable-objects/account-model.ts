import type { EvaConsentPolicy, EvaCreditState } from '@lifeboard/eva-contracts'

export interface EvaDeviceState {
  installationId: string
  platform: 'ios' | 'catalyst'
  createdAt: number
  adultEligibleAt?: number
  adultEligibleExpiresAt?: number
  ageDeclaration?: string
  attestationKeyId?: string
  attestationPublicKey?: string
  attestationCounter?: number
  catalystRisk?: {
    appTransactionIdHash: string
    receiptEnvironment: string
    originalPlatform?: string
    verifiedAt: number
  }
}

export interface RefreshFamilyState {
  familyId: string
  currentTokenHash: string
  usedTokenHashes: string[]
  installationId: string
  authenticatedAt: number
  expiresAt: number
  revokedAt?: number
}

export interface CreditReservation {
  requestId: string
  amount: number
  createdAt: number
  expiresAt: number
  status: 'reserved' | 'running' | 'committed' | 'released' | 'expired'
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
  encryptedAppleRefreshToken?: string
  appleClientId?: string
  credits: {
    balance: number
    capacity: number
    refillAmount: number
    refillPeriodMs: number
    refillAnchor: number
  }
  consent: EvaConsentPolicy
  devices: Record<string, EvaDeviceState>
  refreshFamilies: Record<string, RefreshFamilyState>
  creditReservations: Record<string, CreditReservation>
  speechTickets: Record<string, SpeechTicketState>
  cost: {
    hourlyCommittedMicroUsd: Record<string, number>
    reservations: Record<string, CostReservation>
  }
}

export interface AccountAuthorization {
  authorized: boolean
  reason?: 'session' | 'age' | 'attestation' | 'deleted'
  credits?: EvaCreditState
  consent?: EvaConsentPolicy
}
