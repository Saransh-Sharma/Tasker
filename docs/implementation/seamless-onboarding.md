# Seamless onboarding implementation

- [x] Shared Health state, read-only connection and separate write-back
- [x] Shared EVA disclosure, safe activation and pending-send recovery
- [x] Four-screen onboarding with independently presented connections
- [x] Contextual invitations, focused Connections entry, nonblocking restoration
- [x] Regression tests and simulator build
- [x] Saved-task journey at accessibility XXXL
- [ ] Physical-device Health and live Cloud EVA acceptance checks
- [x] iPad saved-task journey at accessibility XXXL
- [x] iPad connection-dismissal regression verification
- [ ] VoiceOver and Reduce Motion manual acceptance checks
- [ ] Collect baseline and rollout conversion measurements

All four optional EVA categories default on for new unconfirmed users and are visible before confirmation. Existing opt-outs are preserved. Cloud EVA, Apple Health read access and Health write-back remain separate choices. Core setup works locally. Uninterpreted capture text and interrupted activation drafts survive interruption; restored chat drafts require explicit sending.

## Release control

Connection correctness fixes apply independently. The shortened presentation uses `feature.onboarding.seamless_v1`: enabled by default in Debug, disabled by default in Release. Use `-LIFEBOARD_ENABLE_SEAMLESS_ONBOARDING` / `-LIFEBOARD_DISABLE_SEAMLESS_ONBOARDING` for deterministic validation. Promote only after device acceptance and a measured baseline. Disabling the presentation retains consent receipts, connection authorities, write preferences and committed tasks; legacy step raw values remain decodable.

## Automated validation

Xcode 26.5, dedicated iPhone simulator on iOS 26.5. The final broad run passed 138 unit tests across EVA activation, Health sync, LifeWeave onboarding, seamless migration/draft behavior and Connections status. The final follow-up after telemetry and direct write-back changes passed 77 targeted tests. Both new UI journeys passed: skip capture and independently open/dismiss Health; capture/save a real task and find it on Home at accessibility XXXL. A subsequent run passed all 52 App onboarding recovery and Health sync tests. The recovery run exposed an overly short timer assertion and shared notification leakage in a fixture; those fixtures now use a bounded wait and isolated notification hub. Background Health notifications also require observed aggregates before marking data as received.

Tests validate empty Health results and authorization/sync recovery labels without claiming read permission. The simulator journeys do not exercise Apple's actual permission decision or live EVA infrastructure.

## Device acceptance and measurement

Before release, exercise native Health authorization, denied/partial read results, denied write permission, locked-device import and foreground recovery. Verify real cloud guest activation, App Attest, expired Apple sessions and recovery without repeated consent. Complete iPad, VoiceOver, Reduce Motion and modal dismissal checks.

Invitation displays and declines now emit content-free events. `healthDataFirstObserved` records actual data availability once, separately from the authorization result. Settings opens write-back choices directly. Live readiness also outranks old deferrals in connector analytics.

Use existing content-free event timestamps for onboarding presentation → confirmed capture/commit, EVA first prompt → first answer, connector results and later Connections completion. Separate Health authorization completion from observed data availability. Establish a baseline before cohort promotion and compare completion time and repeat invitation rates. Automated tests establish correctness, not conversion impact.

## Follow-up validation

Read-only and write-back authorization requests now retain distinct intents when they overlap. Identical requests coalesce; a different request waits for the active system request to finish before presenting its own types. A gate-controlled regression test verifies this ordering. Health access instructions scroll at large text sizes.

The Health suite passed all 27 tests, including overlapping authorization intents. The iPad saved-task journey passed at accessibility XXXL. A regular-size iPad assertion originally looked for the compact navigation button; the failure screenshot and accessibility hierarchy showed Home correctly, including the first-task action. The assertion now checks that product payoff across both layouts.

The corrected iPad independent-connection journey passed (22 seconds, zero failures). Both iPad journeys are now verified; VoiceOver, Reduce Motion, physical Health permission decisions and live cloud acceptance remain outstanding.
