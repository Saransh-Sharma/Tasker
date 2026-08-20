export interface RateLimitBinding {
  limit(options: { key: string }): Promise<{ success: boolean }>
}

export interface Env {
  AUTH_CHALLENGES: DurableObjectNamespace
  EVA_ACCOUNTS: DurableObjectNamespace
  GLOBAL_BUDGET: DurableObjectNamespace
  EVA_CONFIG: KVNamespace
  EDGE_RATE_LIMITER: RateLimitBinding
  CONFIG_RATE_LIMITER: RateLimitBinding
  AUTH_CHALLENGE_RATE_LIMITER: RateLimitBinding
  APPLE_EXCHANGE_RATE_LIMITER: RateLimitBinding
  EVA_ANALYTICS: AnalyticsEngineDataset

  ENVIRONMENT: 'development' | 'staging' | 'production'
  EVA_API_VERSION: string
  MINIMUM_CLIENT_VERSION: string
  MIN_RUNTIME_CONFIG_VERSION: string
  DAILY_BUDGET_MICRO_USD: string
  ACCOUNT_COST_FUSE_MICRO_USD: string
  APPLE_BUNDLE_IDS: string
  APPLE_CATALYST_BUNDLE_ID: string
  APPLE_APP_ID: string
  APP_STORE_ENVIRONMENT: 'Production' | 'Sandbox' | 'Xcode' | 'LocalTesting'

  OPENAI_API_KEY: string
  APPLE_TEAM_ID: string
  APPLE_KEY_ID: string
  APPLE_PRIVATE_KEY_P8: string
  APPLE_CLIENT_IDS: string
  APPLE_ROOT_CERTIFICATES_BASE64: string
  ACCOUNT_HMAC_KEY: string
  SESSION_SIGNING_PRIVATE_KEY: string
  TOKEN_ENCRYPTION_KEY: string
  CONFIG_SIGNING_PRIVATE_KEY: string
  APP_ATTEST_ENVIRONMENT: 'development' | 'production'
}

export interface SessionPrincipal {
  accountId: string
  sessionFamilyId: string
  installationId: string
  platform: 'ios' | 'catalyst'
  authenticatedAt: number
}

export type AppVariables = {
  requestId: string
  principal: SessionPrincipal
}
