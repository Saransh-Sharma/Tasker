# Phase 1 — Life OS Foundation

This document is the implementation handoff for the additive, internal-only Life OS foundation.

## Activation

- Debug builds now open the Life OS shell by default so ordinary Xcode runs exercise the current product path.
- Use `-LIFEBOARD_DISABLE_LIFE_OS_FOUNDATION` to force the legacy shell during rollback testing.
- `-LIFEBOARD_ENABLE_LIFE_OS_FOUNDATION` remains supported for explicit CI/test configuration.
- Add `-LIFEBOARD_FOUNDATION_REFERENCE_DASHBOARD` to use the screenshot-calibrated executable dashboard in Home.
- A debug-only local preference, `debug.life_os_foundation_v1`, can override the default.
- Release builds do not inherit the Debug default. Phase II surfaces remain independently promotable through typed staged flags.

## Stable contracts

- `LifeBoardAppRouter` owns typed destination paths and safe restoration.
- `CaptureRouter` arbitrates shell, widget, App Intent, Spotlight, share-extension, and deep-link requests.
- `LifeBoardPresentationPreferences` persists device-specific daypart, comfort, and rendering choices in App Group preferences.
- `CoreDataDashboardLayoutRepository` stores versioned value types in the `CloudSync` configuration.
- Unknown widget kinds and their versioned configuration payloads are preserved during migration.
- Sensitive content and managed objects are excluded from navigation restoration.

## Data policy

- `privateSensitive`: journal, mood, health, and biometric data.
- `privateStandard`: tasks, habits, goals, and layouts.
- `shareEligible`: explicit planning projections only.
- Collaboration phases must create whitelist-based projections; private records are never shared directly.
- Diagnostics, capture drafts, derived indexes, and embeddings remain device-local.

## Design reference

`LifeBoardTokenGallery` and `LifeBoardReferenceDashboard` are the executable specification. Morning and afternoon use the approved screenshot values exactly. Evening and night extend the same warm-paper language. Comfort profiles change motion and depth only; semantic colors and information remain stable.

## Validation checklist

- [x] Existing production shell remains the default.
- [x] Firebase and CocoaPods project integration removed.
- [x] iOS/iPadOS and watchOS deployment baselines moved to 26.0.
- [x] Typed five-destination shell, restoration, and capture arbitration implemented.
- [x] Screenshot-calibrated token matrix and adaptive atmosphere implemented.
- [x] Additive `TaskModelV3_LifeOSFoundation` model and dashboard layout repository implemented.
- [x] Privacy manifest and dependency guardrails added.
- [ ] Physical-device upgrade fixture with production-style CloudKit data.
- [ ] Week 1 launch/memory/hitch baselines repeated on the same physical devices.
- [ ] Internal screenshot baselines approved by product/design.

The unchecked items require signing, populated devices, and iCloud accounts; they are release gates, not simulator substitutes.

Phase I is now the stable substrate for Phase II. The current shipping model source advances beyond this version, but every migration fixture still traverses and validates the Life OS Foundation model.
