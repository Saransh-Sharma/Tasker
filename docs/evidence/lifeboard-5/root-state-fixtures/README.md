# LifeBoard root-state visual evidence

> **Classification: Evidence.** These fixtures document one captured simulator state and do not constitute current device approval.

Generated on 2026-07-22 from the Debug simulator build. These screenshots are non-shipping QA evidence.

## Deterministic contract

`LifeBoardVisualFixture.catalog` defines five roots (`home`, `plan`, `track`, `insights`, `eva`) across nine release states (`populated`, `empty`, `loading`, `stale`, `offline`, `denied`, `recoverable-error`, `locked`, `destructive-confirmation`). Launch with:

```sh
-LIFEBOARD_VISUAL_FIXTURE=<root>:<state>
```

The fixture gate is opt-in and can never be entered implicitly by production data.

## Captured evidence

- `iphone-17-pro/`: Home populated/empty/loading/denied/recoverable-error plus representative Plan stale, Track offline, Insights locked, and Eva destructive-confirmation states.
- `iphone/home-compact-chrome-keyboard.png`: the repaired floating Home composer/dock after scrolling with the keyboard presented. The chrome remains above the keyboard and the scenic canvas continues behind it without an opaque footer band.
- `ipad/`: regular Dynamic Type, accessibility XXXL, and `home-atomic-edit-wide.png` expanded-layout evidence.

The wide atomic-edit capture exposed and verified the responsive span correction: presets authored against the canonical four-column grid now scale proportionally into 8/12-column layouts. Its edit toolbar occupies a dedicated row above each card, so ownership and menu controls no longer obscure card identity or content.

## Catalyst resize gate

The shared Catalyst layout resolver is exercised deterministically at 640, 900, and 1280 pt and maps those windows to compact, regular, and expanded presentation respectively. The Catalyst app build and focused contrast/typography/navigation tests pass on the host. XCUI does not expose a supported API for assigning exact Catalyst window frames, so exact-width Catalyst screenshots remain a manual host review gate; the same adaptive shell code is covered by the iPad expanded screenshot and the width-policy tests.
