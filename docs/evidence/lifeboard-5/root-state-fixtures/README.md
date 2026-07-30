# LifeBoard root-state visual evidence

> **Classification: Evidence.** These fixtures document one captured simulator state and do not constitute current device approval.

The original fixture set was generated on 2026-07-22 from the Debug simulator
build. Individual files may be refreshed by later targeted UI journeys; each
refresh remains non-shipping QA evidence and must be interpreted with the test
and environment that produced it.

## Deterministic contract

`LifeBoardVisualFixture.catalog` defines five roots (`home`, `plan`, `track`, `insights`, `eva`) across nine release states (`populated`, `empty`, `loading`, `stale`, `offline`, `denied`, `recoverable-error`, `locked`, `destructive-confirmation`). Launch with:

```sh
-LIFEBOARD_VISUAL_FIXTURE=<root>:<state>
```

The fixture gate is opt-in and can never be entered implicitly by production data.

## Captured evidence

- `iphone-17-pro/`: Home populated/empty/loading/denied/recoverable-error plus representative Plan stale, Track offline, Insights locked, and Eva destructive-confirmation states.
- `iphone/home-compact-chrome-capture.png`: refreshed on 2026-07-30 by
  `testFoundationCompactChromeRemainsReadableAcrossScrollAndCapture`. It records
  the shared Life Thread tool chips inside the measured compact chrome after Home
  scroll. The composer is the single Home capture entry; the screenshot must not
  be used to justify restoring a duplicate header capture button.
- `iphone/home-compact-chrome-keyboard.png`: the repaired floating Home composer/dock after scrolling with the keyboard presented. The chrome remains above the keyboard and the scenic canvas continues behind it without an opaque footer band.
- `ipad/`: regular Dynamic Type, accessibility XXXL, and `home-atomic-edit-wide.png` expanded-layout evidence.

The wide atomic-edit capture exposed and verified the responsive span correction: presets authored against the canonical four-column grid now scale proportionally into 8/12-column layouts. Its edit toolbar occupies a dedicated row above each card, so ownership and menu controls no longer obscure card identity or content.

## Phase 1/2 overhaul evidence boundaries

The 2026-07-30 targeted UI pass also exercised focused Home customization and the
Track habit-resilience editor at accessibility XXXL. Those journeys passed, but
their temporary simulator recordings are not retained as canonical fixtures in
this directory.

This evidence set does not establish complete approval for:

- VoiceOver rotor/order and custom actions;
- right-to-left layout;
- every revised root in dark appearance;
- device haptics or Low Power Mode;
- lifecycle termination during Focus or a Routine;
- Instruments frame pacing, offscreen rendering, SwiftUI update cost, or Metal
  performance.

See
[`LIFEBOARD_UI_UX_OVERHAUL_HANDOFF.md`](../../../todos/LIFEBOARD_UI_UX_OVERHAUL_HANDOFF.md)
for the exact automated verification record and remaining promotion QA.

## Catalyst resize gate

The shared Catalyst layout resolver is exercised deterministically at 640, 900, and 1280 pt and maps those windows to compact, regular, and expanded presentation respectively. The Catalyst app build and focused contrast/typography/navigation tests pass on the host. XCUI does not expose a supported API for assigning exact Catalyst window frames, so exact-width Catalyst screenshots remain a manual host review gate; the same adaptive shell code is covered by the iPad expanded screenshot and the width-policy tests.
