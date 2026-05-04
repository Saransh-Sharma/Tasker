# LifeBoard Pulse + Progress Overhaul Audit

Date: 2026-04-20
Scope: Pulse widget, Pulse destination, Progress destination, FC/quest/pulse persistence, shell cutover
Verifier: Codex

## Verification Summary

- `xcodebuild -workspace 'LifeBoard.xcworkspace' -scheme 'LifeBoard' -destination 'generic/platform=iOS Simulator' build` passes.
- Home now inserts a compact `HomePulseWidgetCard` at the top of the existing Home content stack.
- Bottom shell now routes to `Home / Pulse / Progress / Chat` with Search removed from the bottom bar.
- iPad command map and keyboard shortcuts now align to `⌘1 Tasks / ⌘2 Pulse / ⌘3 Progress / ⌘4 Chat / ⌘F Search`.
- Core Data model now includes additive Pulse / FC / quest entities in `TaskModelV3_PulseProgress`.
- Repository and write-closed adapter layers compile with the extended gamification protocol.

## What Matches The Locked Plan

- Home was kept structurally intact except for the compact Pulse widget insertion.
- Pulse replaces the user-facing Analytics destination in the shell.
- Progress exists as a first-class destination with:
  - level identity
  - permanent XP
  - milestone track
  - FC balance and ledger
  - quests
  - XP by behavior
  - locked spend catalog
- Reward Preview exists as an Eva-branded sheet with:
  - deterministic line-item display
  - 300-second reservation window
  - inline refresh state on expiry
- Pulse state labels match the locked set:
  - `Strong Day`
  - `On Track`
  - `Recovery`
  - `At Risk`
  - `Low Signal`
- Attention fallback is implemented and reflected in the computed snapshot confidence/state path.

## Findings

### P1: Core scoring/economy logic is still concentrated in `InsightsViewModel`, not split into the planned service layer

The execution plan called for dedicated services:

- `ProductivityPulseEngine`
- `PulseExplainer`
- `PulseOpportunityRanker`
- `RewardQuoteService`
- `MotivationEconomyEngine`
- `FocusCreditEngine`
- `QuestGenerationService`
- `RewardGuardrails`

Current state:

- Pulse scoring, opportunity generation, quote reservation, FC derivation, and quest rebuilding live in large helper methods inside `InsightsViewModel`.
- The UI works, but this does not satisfy the architectural separation specified in the plan.

Risk:

- harder to unit test deterministically
- harder to reuse the logic outside the current Pulse view model
- future regression risk when FC / reward-grant rules evolve

### P1: No automated tests were added for the new Pulse / Progress behavior

The plan required migration, unit, integration, UI, and analytics QA coverage. Current state:

- no Pulse/FC/quest/reward-preview tests were added under `LifeBoardTests` or `LifeBoardUITests`
- no migration test currently verifies additive creation of the new Pulse/quest/FC entities
- no UI test asserts the new shell destinations or Home widget behavior

Risk:

- additive model changes can regress silently
- reward reservation drift and duplicate grant bugs would not be caught automatically
- Home/Pulse snapshot parity is unverified outside manual build success

### P2: Reward preview reservation exists, but full quote-to-grant guardrail flow from the plan is not yet implemented as a first-class engine

Current state:

- preview reservation is deterministic and time-boxed
- locked spend catalog is visible

Missing from the plan’s deeper economy core:

- separate grant/reconciliation service with explicit no-drift enforcement
- idempotent reward grant path as a dedicated engine/service boundary
- explicit guardrail layer enforcing quote/grant parity independently of the view model

Risk:

- the UI is in place, but production-hard economy logic is not yet isolated enough for safe extension

### P2: User-facing Pulse replacement is complete, but several internal analytics-named types and traces remain

Examples:

- `HomeAnalyticsSurfaceState`
- `openAnalytics(...)`
- `AnalyticsScrollSession`

This is acceptable internally for now, but it means the cutover is not yet semantically clean inside the codebase.

Risk:

- future contributors will read the wrong mental model
- internal telemetry names may stay inconsistent if not normalized

## Accessibility / Motion Audit

### Verified

- bottom-bar tappable items retain 44x44 sizing
- Pulse widget primary CTA uses 44pt minimum height
- Pulse tabs expose selected state via accessibility traits
- new widget actions now have explicit accessibility labels/hints
- reduced-motion handling remains in place for Pulse tab transitions and the shell
- visual tone stays restrained and avoids arcade-style celebration

### Residual Gaps

- Progress screen sections do not yet have deep accessibility labeling beyond container IDs
- no dedicated UI audit was run in Accessibility Inspector on device/simulator
- no explicit VoiceOver traversal audit was run for the new reward preview sheet

## Data / Migration Audit

### Verified

- additive model version created under `TaskModelV3.xcdatamodeld`
- bootstrap now migrates to `TaskModelV3_PulseProgress`
- repository supports fetch/save for:
  - `PulseSnapshot`
  - `FocusCreditLedgerEntry`
  - `QuestInstance`

### Residual Gaps

- migration behavior was build-verified only, not exercised with seeded pre-existing stores
- no regression test proves XP/achievement/focus-history preservation through migration

## Recommended Next Steps

1. Extract the Pulse/economy logic from `InsightsViewModel` into the planned service layer.
2. Add migration tests for existing stores and fresh installs.
3. Add unit tests for:
   - weighting/fallback
   - quote reservation expiry
   - FC derivation
   - quest generation bounds
4. Add UI tests for:
   - Home Pulse widget
   - bottom-bar Pulse/Progress routing
   - reward preview expiry refresh
   - low-signal state
5. Normalize remaining internal `Analytics` naming once the feature stabilizes.
