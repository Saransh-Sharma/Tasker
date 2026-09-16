# Home artwork and reference validation

- **Classification:** implementation evidence / active validation report
- **Audience:** product, design, iOS engineering, release review
- **Capability status:** implemented artwork system; incomplete catalog and release validation
- **Source authority:** runtime code, manifests, native exports, and named test results
- **Verified date:** 16 September 2026, Asia/Kolkata

## Current outcome

The ambient artwork implementation is present. **The complete redesign is not accepted for release.** Generated-reference acceptance, production-route evidence, functional scenarios, broader regression classification, and controlled performance measurements remain open.

The live source of per-image status is the [Home manifest](image-generation-manifest.json). Use the [comparison gallery](index.html) to distinguish current generated concepts, native adapter captures, preview captures, and historical attempts. Earlier audit statements—including missing production scenes and the historical generation quota—are preserved in [historical validation](HISTORICAL_VALIDATION.md); they are not current status.

| Deliverable | Evidence at this checkpoint | Meaning and limit |
|---|---|---|
| Registry and prompt identities | 22 kinds, 92 supported combinations, 228 stable entries | Count coverage; not proof every specification is ready |
| Home production artwork | 44 accepted variants, 22 complete appearance pairs | Originals preserved; 132 optimized runtime PNGs |
| Feature-header artwork | 34 accepted variants across 17 families | 102 runtime PNGs; actual-route acceptance remains open |
| Generated UI references | 22 accepted current; 46 entries have generated originals | Goal remains 184 accepted current references; never count superseded attempts as accepted |
| Native element specifications | 184 ready specifications with copy, typography, numeric value/unit rectangles, controls, and progress fractions | Final explicit export passed; comprehensive production-route safe areas still not established |
| Representative native evidence | 68 configurations, 136 live-adapter/preview images | Card-local production adapters; **not full AdaptiveHome route captures** |
| Historical structural evidence | 368 isolated samples | Supporting composition evidence; not exhaustive behavior verification |
| Feature-header component evidence | 34 shared-header captures | Does not establish behavior on 17 actual feature screens |
| Asset reproducibility | 275 of 275 owned runtime files identical after rebuilding both catalogs | Includes catalog metadata; no stale additions or removals |

## Implemented design and compatibility

Artwork fills the existing card surface behind native content. It does not add a footer, an illustration row, a reserved reading column, or card height. Native intrinsic content and the existing size minimums determine geometry. A directional mask and low opacity protect reading. Scene loading is coalesced and prepared asynchronously through an appearance-specific cache; original generation sources do not enter runtime loading paths.

The shared live and preview content includes Glance, Tasks, Care/Routines, Focus, Life Snapshot, Capacity, Journal, Day Shape, Quick Capture, Progress, and Fasting. Canonical live adapters retain domain callbacks. Gallery adapters provide synthetic records and inert callbacks. The defaulted `HomeCardBody` presentation input and selected-size placement command remain compatible; no persistence migration was introduced.

Glance uses the shorter visible labels **Progress**, **Nutrition**, and **Workout** to avoid truncation at the measured narrow width. The registry and pinning catalog retain their full names. Production Tasks dark artwork was revised to remove checklist-like marks from the notebook; only native task controls communicate completion.

See [the implemented design system](IMPLEMENTED_DESIGN_SYSTEM.md) for composition, privacy, appearance, operations, and extension rules, and [future creative directions](FUTURE_CREATIVE_DIRECTIONS.md) for explicitly unimplemented proposals.

## Generation and inspection gates

- Exact submitted prompts, source-reference hashes, timestamps, tool output paths, originals, and export transforms are retained per attempt.
- New submissions freeze their input images under `submissions/inputs/`; early historical submissions predate this freeze mechanism. Their archived originals remain available, but they must not be described as having used immutable copies.
- Manifest mutations share a lock and use atomic replacement.
- Export helpers compile reproducibly from repository Swift sources. The exporter maps the explicit card rectangle through the actual output dimensions, separates intentional padding from unintended aspect correction, and rejects corrections exceeding 4%.
- Three exporter contract tests pass: explicit padding, rejected excessive aspect correction, and rejected out-of-bounds placement.
- Native-first visual input is the current generation hypothesis: the structural fixture controls framing, text, and artwork strength; the scene source supplies subject and paint treatment.
- Visual review is mandatory even when numeric dimensions pass. One Tasks Compact attempt placed a wider card inside a square canvas; its mathematically valid crop clipped checkboxes and was rejected.
- Three manifest-recording regression tests also pass: late results cannot overwrite a newer accepted output, late failures cannot downgrade it, and every replacement resets inspection while preserving the prior accepted export.
- Tasks Compact needs design review after unsuccessful targeted aspect/framing revisions. Preserve those attempts; do not stretch the output, weaken the clipping gate, or repeatedly retry the same hypothesis.
- A current accepted concept does not certify native actions or production-route behavior.

## Native export defects found and addressed

The explicit all-reference specification export passed for 184 entries. This is geometry/specification generation, not an exhaustive preset behavior test. `NumericRoll` exposes value and unit rectangles through a DEBUG-only SPI; its released initializer and behavior are unchanged. Generic bodies export exact fixture strings, action labels, and typography. Progress rings settle directly to fixture values only while the evidence recorder is installed.

The export revealed three issues:

1. A prepared Sleep scene could be evicted by `NSCache` before offscreen rendering. The new assertion reproduced this. The explicit recorder now holds the prepared image for its render; production cache budgets stay unchanged. The subsequent 98-entry export passed and the Sleep scene was visually confirmed.
2. Narrow Setup and Goals cards truncated essential copy beside their rings. Their shared native composition now uses a readable horizontal minimum and a stacked fallback. The final native export passed, and both narrow light-appearance compositions were visually checked with complete copy.
3. The platform-backed linear ProgressView cannot be flattened by ImageRenderer and showed a warning stripe. The native SwiftUI progress style passed the final export, and Progress Wide light was visually checked with the correct 40% track instead of the placeholder.

Final capture result: `/tmp/lifeboard-final-native-specs-compile-sep16.log`; xcresult at `/Users/saransh1337/Library/Developer/Xcode/DerivedData/LifeBoard-bwsbwhskioltifbmbqawesubbvsl/Logs/Test/Test-LifeBoard-2026.09.16_01-53-13-+0530.xcresult`. One explicit export test passed, 184 specifications were signed, and the read-only Home validator reported zero integrity errors. The 136 representative adapter/preview images predate these last ring/progress/retention refinements and need refreshing.

Journal Wide light/dark were previously visually accepted but are now superseded after correcting the Write/Search alignment metadata to center. Their original prompts, images, and inspections remain preserved. This explains why the current count is 22 rather than 24 historically accepted entries. No superseded output is counted as current.

## Representative native evidence

The explicit `testProductionAdapterAndPreviewGeometryParity` profile passed all **68 configurations**: 28 selected phone cases in two appearances and six selected tablet cases in two appearances. Matching adapter and preview heights were checked, producing **136 images**. The test also checks the isolated router remains on Home and no capture route is set. A Tasks-only refresh passed after its dark scene revision.

This establishes shared-renderer parity for the selected fixtures. It does **not** prove absence of every attributable haptic, timer, network request, or repository mutation. Additional spies and application-level checks remain required.

The geometry export is a separate explicit command. Ordinary tests do not rewrite design documentation. Native specification JSON identifies its renderer as `shared-native-content-preview`, and explicitly states that isolated cards have no measured production-route safe areas. Source, fixture, typography, artwork, and capture hashes are recorded immediately after export.

Outstanding production evidence:

- 16 full-Home arrangements through `AdaptiveHome` and `DashboardFlowLayout`: paired narrow, solitary widening, mixed sizes, and Low Energy across both devices and appearances.
- Actual feature routes: 34 phone captures and eight tablet spot checks.
- Relevant empty, unavailable, degraded, redacted, deleted-source, user-media, long-text, and large-value states.
- Default-size VoiceOver, touch targets, contrast, keyboard, and selected RTL/appearance-preference checks.

**Excluded by user priority:** XXXL, full Dynamic Type sweeps, exhaustive preset behavioral matrices. Geometry exports across the reference catalog are specifications, not a reintroduction of exhaustive behavioral testing.

## Functional UI findings

Previous focused runs passed customization Cancel/composer behavior, selected-size Add/Undo, and task expansion. These are supporting historical results, not a substitute for the remaining functional table in the execution plan.

The Care navigation assertion was updated from the legacy `Overview` control to the actual medication destination control `track.medication.new`. Source routing sends `.careLibrary` to the medication area. In the new compound UI run, typed Track navigation and that medication control passed. The test subsequently failed to locate the Home Capacity action after scrolling. Thus **the compound test still fails**. A follow-up morning-atmosphere run failed earlier because the Home navigation control was not hittable; it does not establish a Capacity fix.

These runs used the available 402×874 simulator surface and are not canonical 393×852 visual evidence. Capture startup and daypart determinism must be resolved before collecting actual-route acceptance images.

Local results: `/tmp/LifeBoardCareRoutesSep16.xcresult`, `/tmp/LifeBoardCareRoutesMorningSep16.xcresult`. Attachment exports are under `/tmp/lifeboard-care-routes-attachments`. These local bundles are not durable repository artifacts; the named outcomes above remain explicit limitations.

## Regression and build gates

The baseline-aware script retains its default behavior and adds an explicit `representative-redesign` profile. The profile excludes the large accessibility/presentation export matrix and seven additional explicit export/typography sweep methods; the script lists the exact exclusions. It does not expand the checked-in failure baseline.

The representative broad run reported **2,524 total tests: 2,513 passed, seven failed, four skipped** in xcresult summary. Eight assertions occur across seven failed methods. Durable summary: [suite result](checkpoints/2026-09-16/representative-suite-summary.json).

| Failed method | Observed issue | Classification |
|---|---|---|
| `ArchitectureBoundaryTests/testViewLayerDoesNotUseSingletonDependencyContainers` | `CompositionRoot.shared` in TaskDetailScreen | Unclassified; no isolated comparison build |
| `AssistantPlannerServiceTests/testEvaTurnRouterKeepsNormalChatOutOfProposalPlanner` | Day-planning versus read-only review route | Unclassified |
| `FeatureFlagPromotionTests/testEveryStagedFlagHasAPromotedDefault` | `feature.onboarding.seamless_v1` missing | Unclassified |
| `FeatureFlagPromotionTests/testReachableStagedSurfacesArePromotedForRelease` | Same missing promotion | Unclassified |
| `HabitCoreDataSchemaRegressionTests/testTaskModelCurrentVersionPointsToAnExistingSourceModel` | Model version expectation differs | Unclassified |
| `LifeOSFoundationContractTests/testEveryPreviousModelMigratesToCurrentModelWithoutChangingStableIDs` | 23 compiled predecessors versus 22 expected | Unclassified |
| `TaskListWidgetSourceContractTests/testWidgetTargetLinksTheSharedTokenPackage` | Package reference assertion | Unclassified |

Three previously failing methods passed in this run. That alone does not establish their origin or a redesign fix. The [source comparison](checkpoints/2026-09-16/failure-source-comparison.json) records matching/differing source files but explicitly is not a controlled causal build comparison. No failure is silently relabeled as preexisting.

Concurrent onboarding/Eva edits appeared in the shared working tree during later captures. Two minimal compiler fixes were applied while preserving those changes: an explicit `return switch` in `HealthConnectionSheet.actionTitle`, and qualification of `_Concurrency.Task<Never, Never>.yield()` in newly added Eva activation tests to avoid the domain `Task` alias. These are build unblockers, not part of the artwork redesign or evidence of unrelated functional correctness.

App simulator builds succeeded in the focused capture and regression runs. The all-target membership script completed the app build-for-testing but could not build LifeBoardWatch because **watchOS 26.5 is not installed**. Membership remains blocked by that missing platform; the app build is not all-target compiler evidence.

## Performance and packaging

[Packaging reproducibility](packaging-reproducibility.json) records identical bytes for all 275 owned runtime files after the Tasks scene revision and both packagers. Originals, normalized source files, and runtime scale variants are counted separately.

Prior three-cycle scrolling runs provide supporting measurements only:

| Run | Scripted cycle duration | CPU | Average peak physical memory |
|---|---:|---:|---:|
| Ambient Home | 12.114 s | 1.842 s | 122,320 kB |
| Dedicated feature headers | 12.155 s | 1.838 s | 116,384 kB |

No hitch/FPS metric was emitted. These are not a controlled before/after performance improvement claim. The agreed three cold and three warm cycles, cache/preparation counts, repeated root switching, Capture expansion, and retained-image growth comparison remain open. Cache limits are eviction budgets, not a bound on all app image memory.

## Documentation gates

Canonical design rules, the Product UI/UX Guide, Home chapter, dark-mode brief, and index were reconciled with ambient composition and shared typography. The deep implementation guide and separate creative-directions chapter now exist. Documentation guardrails pass for **45 living documents**. The dark-mode brief’s older prompts are explicitly labeled historical; current appearance rules precede them.

Documentation describes implementation and evidence at different levels. It does not promote unsampled behavior to verified or released. Final links, metadata, and evidence counts must be rerun after the remaining work.

## Reproducible commands

```sh
python3 scripts/package_home_card_scenes.py
python3 scripts/package_ambient_surfaces.py
python3 scripts/validate_home_card_design.py
python3 scripts/validate_ambient_surfaces.py
python3 scripts/test_home_card_export.py
LIFEBOARD_CAPTURE_TEST_FILTER=HomeCardPresentationTests/testExportInstrumentedElementSpecifications scripts/capture_home_card_evidence.sh
LIFEBOARD_CAPTURE_TEST_FILTER=HomeCardPresentationTests/testProductionAdapterAndPreviewGeometryParity scripts/capture_home_card_evidence.sh
LIFEBOARD_TEST_PROFILE=representative-redesign scripts/run-baseline-aware-tests.sh
python3 scripts/home_card_review_report.py
scripts/check-documentation-current.sh
scripts/check-xcode-target-membership.sh
python3 scripts/validate_home_card_design.py --complete
```

The final command is expected to fail while completion gates remain open. A passing integrity check is not completion.
