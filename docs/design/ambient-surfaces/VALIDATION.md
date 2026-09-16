# Feature header artwork

## Scope and priorities

The user requested unique artwork and aesthetics for every key feature header. This adds 17 dedicated panoramic families (34 appearance variants), separate from the original 44 Home card illustrations and 228-entry Home prompt catalog. Normal-size design and efficient runtime loading take priority; exhaustive XXXL and widget-preset testing is deferred.

## Feature identities and integration

| Feature | Visual identity | Native integration |
|---|---|---|
| Home | Welcoming architectural horizon | Root header |
| Track | Balanced ceramics, sage and clay | Root header and tracker area header |
| Plan | Blank paper and pencil | Root header |
| Insights | Winding landscape path | Root header |
| Eva | Violet reading alcove; no replacement persona | Root header |
| Journal | Blank notebook and soft rose linen | Unlocked Journal header/section selector |
| Care | Terracotta botanical alcove | Care area header |
| Routines | Garden stepping stones | Routines collection header |
| Goals | Distant summit | Goals collection header |
| Fasting | Quiet ceramic still life | Fasting hero and Track section |
| Body metrics | Neutral balanced forms | Body metric hero |
| Workouts | Unbranded equipment and trail | Workout hero |
| Sleep | Gauzy window and folded blanket | Sleep hero |
| Movement | Meadow path and bench | Movement hero |
| Nutrition | Kitchen ceramics and garden ingredients | Nutrition daily hero |
| Life Moments | Ribbon, envelope and floral keepsake | Focused moment detail |
| Capture | Blank sketchbook and pencil | Root capture tray |

No illustration asserts recorded activity, completion or a health outcome. Native text, data, controls, source identity and existing privacy state remain authoritative. Appearance remains independent of daypart. The Home scenic atmosphere is preserved behind the local header treatment.

## Geometry and loading

- Sources request 1536×512 PNG with genuine alpha. Actual generation dimensions are recorded per entry; canonical exports preserve the aspect ratio and all paint.
- Runtime exports: 512×171, 1024×342, 1536×513. Subpixel vertical padding preserves the source's exact aspect ratio. Only complete accepted appearance pairs are exposed.
- The existing header determines width and intrinsic height. Background geometry never adds a row, a column, or a minimum height.
- Root header paint is attached to `AppRootHeader`; expanding Capture no longer stretches the root header artwork across the tray.
- Header and card assets have separate cache keys. Both use the same asynchronous preparation and coalescing path. The NSCache budget is 32 MiB / 48 entries, an eviction policy rather than a hard cap on total app memory. Sources are never loaded at runtime.
- No artwork animation, blur, synchronous file processing, or new timer was added.

## Verification checkpoint

- 34 generated production variants accepted; dark Body metrics was revised once and its previous source archived.
- 17 complete runtime pairs / 102 scale files pass the read-only source, dimension, alpha and hash validator. See [asset validation](asset-validation.json).
- Simulator build and four focused tests passed on 15 September 2026 at 11:17 PM IST: no added card height, coalesced image preparation, independent card/header cache identities, and header asset loading/geometry.
- 34 default-size `AppRootHeader` captures were exported; every fixture is 353×52 points with and without decoration. Five representative samples were inspected for native title/control readability. These fixtures exercise the shared header component; they do not establish complete feature-route acceptance.
- [Browse the artwork and native header gallery](index.html). [Measured component bounds](native/measurements.json).
- Result bundle: `/tmp/LifeBoardFeatureHeaders.xcresult`. Log: `/tmp/lifeboard-feature-headers.log`.
- Post-integration animation-enabled Home scrolling passed three cycles at 11:20 PM IST: 12.155s average scripted duration, 1.838s CPU time, and 116,384kB average peak physical memory. Result: `/tmp/LifeBoardFeatureHeaderScroll.xcresult`; log: `/tmp/lifeboard-feature-header-scroll.log`. The runtime emitted no hitch metric. Compared with the earlier checkpoint (12.114s / 1.842s / 122,320kB), these are similar duration/CPU observations, not a controlled causal speedup claim.
- The full widget reference catalog, exhaustive accessibility/preset matrix and all feature-route interactions remain outside this focused pass. Existing broad-suite/documentation blockers are still tracked in the Home validation report.

## Reproduction

```sh
python3 scripts/package_ambient_surfaces.py
python3 scripts/ambient_surface_review.py
```

The packager rebuilds only its owned `AmbientSurfaces` asset-catalog directory. Generated originals and rejected revisions remain in `DesignAssets/Sources/AmbientSurfaces`. Exact submitted prompts and tool-output paths are retained in the manifest.
