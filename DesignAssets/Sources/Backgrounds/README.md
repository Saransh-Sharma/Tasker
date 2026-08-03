# Scenic background sources

- `HomeScenicNoSun.source.png` is the user-supplied `HomeBGCanvas_withoutSun.png`.
- `PlanScenicNoSun.source.png` is the user-supplied `PlanBGCanvas_withoutSun.png`.
- Both are opaque scenic canvases. The transparent `SunDay` and `SunDayPlan` assets are layered separately so motion and accessibility fallbacks never require image masking at runtime.
- Runtime copies live in `Assets.xcassets/ScenicBackgrounds` and are decorative only.
