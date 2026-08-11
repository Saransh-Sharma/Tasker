# Signature effect deployment

> Classification: Canonical design implementation reference
> Audience: Design, engineering, accessibility, performance, and QA
> Capability status: Current workspace
> Source authority: Metal shader registry, wrappers, and design tests
> Last verified: 2026-08-11

Where each Metal effect in the sanctioned vocabulary actually fires, and the rule
that keeps it from becoming decoration.

The vocabulary itself is defined in `DESIGN.md` ("Motion and delight"). The
shaders live in `LifeBoard/View/Effects/LifeBoardSignatureEffects.metal`; their
SwiftUI wrappers and the uniform degradation contract live in
`LifeBoard/DesignSystem/LifeBoardSignatureEffects.swift`.

## The registry is an atomic contract

`LifeBoardSignatureShaders.functionNames`, the `[[stitchable]]` declarations in
the `.metal`, and DESIGN.md's approved list are **one contract**, pinned by
`LifeOSFoundationTests.testSignatureShaderRegistryMatchesMetalDeclarations`.
`warmUp()` is all-or-nothing: a single name mismatch silently disables *every*
signature effect at runtime with nothing logged at the UI layer.

Current count: **20**.

## Deployment map

| Effect | Fires on | Boundary | Guard against ambience |
|---|---|---|---|
| `paperGrain` | static, on every Track / composer / Notes-editor canvas | — | No time input. The only sanctioned static effect. Sits *behind* content, never over it. |
| `contextLens` | any Track composer being presented | capture | One lens per presentation, driven by `onChange` of "is a composer up", not by `onAppear`. |
| `clayPressBloom` | selection on a weighty option rail (tracker kind, mood, goal type) | capture | Opt-in per rail via `pressBloomTint`. Deliberately **not** on toggles, field focus or bead ticks — those are microinteractions and get haptics only. |
| `valueDrumWarp` | while a value tape is under the finger | capture | Takes no `time`; amplitude is `grip`, a pure function of whether a finger is down. No `TimelineView`. Identity at the centre detent and at rest. |
| `liquidGlassRefract` | lens picker thumb travel, all roots | navigation | Implemented *inside* `LifeBoardLensPicker`, so it cannot be applied to something that is not a lens. `strength` returns to 0. |
| `fastingEmberRing` | elapsed/target while a fast is recorded running | commitment | Stops when the fast does. |
| `vitalOrbWarp` | the day's hydration total first crossing target | commitment | `claimOneShot("track.hydration.target.<dayKey>")`. Explicitly **not** per +250 mL. |
| `completionBurst` | inside the `if await save(...)` success arm | commitment | Structurally unable to fire before persistence. |
| `firstLight` | the first successful composer commit of the calendar day | commitment | `claimOneShot("lifeboard.firstLight.<dayKey>")`. |
| `memoryDevelopReveal` | a Life Moment card first arriving | reflection | `claimOneShot` per card per window session, so it never replays on scroll. |
| `dissolveAway` | after a delete resolves in the repository | commitment | Never before persistence — a card that erodes ahead of a failing write lies about the data. |
| `chartRevealSweep` | valid chart data appearing, and on range change | reflection | Empty and denied states never reach the branch, so a sweep can never imply data that is not there. |
| `healthSyncPulse` | a wellness measurement being recorded | commitment | Recorded state change only. |
| `LiquidMetalBezel` (`.pill`, copper) | every composer commit control | chrome | `.staticIdle` only. `.slowLoop` is a literal ambient loop and stays confined to the two sites that already justify it. |

## Deliberately not deployed

- Nothing on `LifeBoardClayToggleStyle` flips, `LifeBoardComposerField` focus, or
  `LifeBoardBeadStepper` ticks. Microinteractions get haptics and a 120–280 ms
  surface change.
- No `daypartCrossDissolve` inside a composer. A composer is not an atmosphere
  change.
- No `lifeBoardScrollEntrance` inside composer scroll views. Ordinary scrolling
  and reading stay quiet.
- Nothing on repeated history-row appearance.
- `cardMorphWarp` on the Track module rail was **considered and dropped**: it
  needs a push trigger the rail cannot reach without threading a callback through
  three structs. The rows use the sanctioned zoom transition
  (`lifeBoardTransitionSource`) instead, which gives the same source → travel →
  settle continuity with no invented state.

## Degradation

Every wrapper reads `accessibilityReduceMotion`, `accessibilityReduceTransparency`
and `scenePhase`, and consults `LifeBoardSignatureShaders.isReadyForRendering`
(which folds in Low Power Mode, thermal pressure, Catalyst and shader
availability). Fallbacks are opacity/scale/tint changes — never removal of
content, never a delay to input.

If a shader is unavailable the texture simply never arrives. Paper is still
paper.
