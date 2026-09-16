# Continuation prompt: finish LifeBoard’s artwork reference catalog and validation

**Classification:** Agent execution handoff

**Audience:** The next agentic coding/design session

**Capability status:** Work in progress; not release accepted

**Source authority:** Current working tree, manifests, explicit native exports, and recorded test evidence

**Checkpoint:** 16 September 2026, approximately 01:56 IST

**Repository:** `/Users/saransh1337/Developer/Projects/Tasker`

**Checkpoint HEAD:** `30afaec8bc31f2278623414cad619f36b3236426`

---

## Prompt to the next agent

You are continuing an existing implementation as an expert iOS app designer, product manager, and SwiftUI engineer. **Continue the work in this repository; do not restart, merely re-plan, or replace suitable existing artwork.** Ground decisions in runtime code, product documentation, actual images, and test evidence. Read this handoff and its linked files before editing.

The user wants you to finish **LifeBoard’s 184 generated Home card references, representative native/feature-route validation, and deep design documentation**. Most artwork and ambient rendering are implemented, but the reference catalog and release gates are incomplete. The user has explicitly deprioritized **XXXL, Dynamic Type sweeps, and exhaustive preset behavioral testing**. Do not bring those back. Explicit geometry/specification exports across the reference catalog remain in scope.

The user is frustrated by long stalls and repeated audits without implementation. Give concise progress updates at least about once per minute, save successful generation outputs immediately, and continue independent work if generation or a build is blocked. Do not claim a complete redesign from a passing small test suite or attractive images.

### Working-tree precautions

- Use markdown TODOs. Root `AGENTS.md` requires markdown task tracking.
- Preserve the entire dirty working tree, including unrelated project, localization, onboarding, and Eva changes. **Do not reset, clean, stash everything, or restore whole files to HEAD.**
- Other work appeared concurrently during this session. Recheck current diffs before touching shared files. No commit was created for this task.
- Original task-start evidence is under `docs/design/home-cards/checkpoints/2026-09-16/`, including `starting.diff` and `checkpoint.json`. The handoff checkpoint records the later state.
- Two minimal compiler fixes were made in concurrently changed files: `return switch` in `HealthConnectionSheet.actionTitle`, and `_Concurrency.Task<Never, Never>.yield()` in new Eva activation tests to avoid the domain `Task` alias. Preserve the surrounding unrelated changes; do not claim their features as part of this redesign.
- The previous session did not spawn agents. Follow the new session’s actual delegation instructions; do not assume permission to create user-owned tasks.

## 1. Verified current state

| Deliverable | Current state | Interpretation |
|---|---|---|
| Home catalog | 22 kinds, 92 supported kind/size pairs, 228 stable manifest entries | 184 UI references + 44 production scenes |
| Home production artwork | **44 accepted variants**, packaged as 22 light/dark pairs | 132 runtime PNGs; originals preserved |
| Feature-header artwork | **34 accepted variants across 17 families**, packaged | 102 runtime PNGs |
| Current generated UI reference acceptance | **22 of 184 accepted** | 162 remain to be accepted |
| Reference entries with generated originals | **46** | Includes accepted, superseded, rejected, and unresolved originals; not 46 accepted references |
| Native reference specifications | **184 exported and marked ready** | Exact fixture copy, typography, numeric value/unit geometry, controls, and progress fractions; card-local geometry, not production safe areas |
| Representative native images | **68 live-adapter + 68 preview images = 136** | Existing exports predate the last ring/progress/capture-retention refinements; refresh them |
| Historical structural samples | 368 isolated sample images | Historical/supporting evidence, not exhaustive native behavior acceptance |
| Feature-header evidence | 34 shared-header component captures | Actual feature routes still need validation |
| Packaging reproducibility | **275/275 runtime files byte-identical** after both packagers | Includes PNGs and catalog metadata; no additions/removals/stale outputs |
| Exporter regressions | **3 tests passed** | Explicit padding, excessive aspect rejection, out-of-bounds rejection |
| Generation-recording regressions | **3 tests passed** | Late-result protection, late-failure protection, fresh inspection on replacement |
| Broad representative suite | **2,524 total: 2,513 passed, 7 failed, 4 skipped** | Seven failed methods remain unclassified; eight assertions |
| Documentation checks | **Pass for 45 living documents** | Rerun after final edits; docs do not certify release |
| All-target membership | App build completed; Watch build blocked | watchOS 26.5 platform is not installed |

### Exact currently accepted references

All are internal preset `compact` (**user-facing Glance**), in both light and dark:

1. `care`
2. `quickCapture`
3. `progressReflection`
4. `fasting`
5. `bodyMetric`
6. `sleep`
7. `movement`
8. `lifeMoment`
9. `nutritionSummary`
10. `recentMeal`
11. `logMeal`

IDs follow `kind-preset-appearance`, for example `bodyMetric-compact-dark`.

**Journal Wide light/dark were previously visually accepted but are now superseded.** The Write/Search typography alignment metadata was corrected to `center`, changing the specification hash. Their native composition did not materially change. The pipeline deliberately does not count their old accepted outputs against the new specification. Preserve original submissions/inspections and generate/inspect current replacements; do not silently rewrite the historical submitted prompt or generated hash.

**Tasks Compact (`tasks-standard`) remains a framing design-review issue.** Light is `inspection_status=design-review`, currently superseded; dark is rejected/superseded. See generation details below.

## 2. Required design direction and compatibility

### Ambient artwork

The user rejected small corner thumbnails and extra artwork rows, especially in the smallest cards. The current direction is:

- Artwork fills **existing card bounds behind native content**.
- No extra illustration row, footer, reserved text column, or height caused by decoration.
- Intrinsic content height remains authoritative; preset minimums are floors.
- Proportional scaling/fill, clipping, soft directional masks, and restrained opacity protect reading.
- Reduce decoration before compromising data or controls.
- All text, values, charts, progress, states, and actions remain native. Generated UI references are **never runtime flattened cards**.
- Main feature headers have their own subject and aesthetic; shared navigation, section-header typography, and spacing remain consistent.

### Palette, atmosphere, privacy

- Light: warm paper/cocoa. Dark: indigo/parchment. Resolve actual semantic tokens; do not resurrect obsolete historical palettes.
- Appearance and daypart remain independent. Night-themed subject matter is not a substitute for dark-mode token selection.
- Preserve the existing Home atmosphere and Eva persona. Assistant-associated violet stays in the assistant context.
- Decoration must not fabricate completion, health outcomes, recorded memories, measurements, or recommendations.
- Suitable existing people-containing artwork was explicitly approved for reuse.
- Suppress scenes for unresolved, degraded, unavailable, and redacted content, and where actual user media has priority.
- Keep artwork static. No new per-card animation loops, ambient timers, blur pipelines, or source-resolution image loading.

### Persistence and interactions

Keep registry kinds, supported presets, placement IDs, source IDs, multiplicity, projection payloads, storage format, and canonical handlers compatible. No migration is planned. Preserve:

- Transactional customization, Save/Cancel, pin, resize, reorder, removal, persistence.
- Pinned ownership, Smart Slots, singleton restrictions and source-specific multiple instances.
- Task completion, Undo, recovery, date selection, Show more/less, detail navigation.
- Care/routine actions, fasting lifecycle, capture routes, journal actions, evidence routes, recorded-source navigation.
- Defaulted `HomeCardBody` presentation input and selected-size placement command.

### Size mapping

| Visible size | Internal preset | Grid semantics | Minimum height |
|---|---|---|---:|
| Glance | `compact` | 2×1 | 104 pt |
| Compact | `standard` | 2×2 | 178 pt |
| Wide | `wide` | 4×2 | 178 pt |
| Story | `tall` | 4×3 | 260 pt |
| Expanded | `expanded` | 4×4 | 340 pt |

Grid spans do not imply pixel aspect ratios. Canonical paired narrow phone cards are 170.5 pt wide; full-span phone cards are 353 pt. Heights vary with actual content. The reference viewports are 393×852 pt and 834×1194 pt, but card-local captures do not establish real safe areas or full-route placement.

Row budgets: Tasks four collapsed, six initially in Expanded, two Low Energy; Show more reveals matching rows/date controls. Care/Routines three in Compact/Wide, four Story, five Expanded, one Low Energy. Generic queues use explicit size limits capped by available records. Larger cards must not invent history.

## 3. Read these files first

All paths below are relative to `/Users/saransh1337/Developer/Projects/Tasker` unless shown absolute.

### Current status and operating documents

- `docs/design/home-cards/VALIDATION.md` — **current** evidence and limitations, recently rewritten.
- `docs/design/home-cards/COMPLETION_TODO.md` — active task checklist.
- `docs/design/home-cards/TODO.md` — original 92-pair tracker; still needs reconciliation with current evidence levels.
- `docs/design/home-cards/image-generation-manifest.json` — authoritative per-entry status, prompts, hashes, revisions, submissions, outputs, inspections.
- `docs/design/home-cards/IMAGE_GENERATION_PROMPTS.md` — generated human-readable prompt catalog; do not hand-edit against the builder.
- `docs/design/home-cards/index.html` — browsable generated/live/preview/structural comparison gallery with filters.
- `docs/design/home-cards/HISTORICAL_VALIDATION.md` — explicitly historical audit, not current status.
- `docs/design/home-cards/AMBIENT_ART_DIRECTION.md` — ambient design mapping/history.
- `docs/design/ambient-surfaces/manifest.json` — separate 34-entry feature-header manifest; confirm exact filename if changed.
- `docs/design/ambient-surfaces/VALIDATION.md`, `index.html`, `IMAGE_GENERATION_PROMPTS.md` — feature artwork evidence and prompts.
- `/Users/saransh1337/Downloads/PLAN (8).md` — earlier attached plan, historical context. The later scope summarized here supersedes its exhaustive-testing requirements.

### Canonical design/product documentation

- `DESIGN.md`
- `docs/design/LIFEBOARD_PRODUCT_UI_UX_GUIDE.md`
- `docs/product/HOME.md`
- `docs/design/DARK_MODE_ASSET_BRIEF.md`
- `docs/product/FEATURE_CATALOG.md`
- `docs/README.md`
- `docs/design/home-cards/IMPLEMENTED_DESIGN_SYSTEM.md` — substantial new guide covering rationale, size intent, motifs, architecture, privacy, appearance, operations, extension rules, and evidence limits.
- `docs/design/home-cards/FUTURE_CREATIVE_DIRECTIONS.md` — substantial new **unimplemented** research chapter with six directions, experiments, constraints, dependencies, risks, and priorities.

The deep docs are already written. Reconcile them against final code/evidence instead of rewriting from scratch or marking proposals implemented.

## 4. Runtime implementation map

### Shared artwork and card presentation

Directory: `LifeBoard/DesignSystem/HomeCards/`

- `HomeCardPresentationStyle.swift`: dimensions, row budgets, scene policy, size-aware title helpers, preview width resolver. Glance labels now use `Progress`, `Nutrition`, and `Workout` to avoid truncation; registry names remain unchanged.
- `HomeCardIllustratedSurface.swift`: applies card chrome once, intrinsic minimums, ambient background.
- `HomeCardScene.swift`: proportional fill, trailing crop, RTL mask direction, opacity, async image loading, decorative accessibility/hit-testing behavior.
- `HomeSceneImageCache.swift`: shared `NSCache`, 32 MiB/48-image eviction budget, appearance-specific keys, coalesced in-flight preparation, preparation count.
- `HomeAmbientArtwork.swift`: reusable surface modifiers and `FeatureHeaderScene` mapping for 17 dedicated header identities.
- `HomeCardSamplePreview.swift`: shared native content, synthetic records, inert callbacks and hit testing; selected-card rendering.
- `HomeCardPreviewFixtures.swift`: fixed synthetic strings/records/IDs and 15 September 2026 date; no user stores.
- `HomeCardGeometryRecorder.swift`: optional element IDs/rectangles/typography/progress fractions and retained prepared image for explicit captures. Normal production does not install it.
- Shared content files: `HomeGlanceCardContent`, `HomeTasksCardContent`, `HomeActionQueueCardContent`, `HomeCardQueueRow`, `HomeFocusCardContent`, `HomeLifeSnapshotCardContent`, `HomeCapacityCardContent`, `HomeJournalCardContent`, `HomeTimelineCardContent`, `HomeQuickCaptureCardContent`, `HomeProgressCardContent`, `HomeFastingCardContent`.

Other important runtime files:

- `LifeBoard/DesignSystem/LifeBoardHomeCardBodies.swift`: meaningful generic archetype fallback; exact native hooks; numeric readout adapter; Setup/Goals ring layout now uses a 130-pt minimum reading block beside the ring and stacks if that cannot fit.
- `LifeBoard/DesignSystem/LifeBoardCardPrimitives.swift`: `ProgressRing`; when an evidence recorder is installed it draws the fixture fraction directly, avoiding `onAppear` animation state in offscreen exports.
- `Packages/LifeBoardUI/Sources/LifeBoardUI/NumericRoll.swift`: DEBUG-only `DesignEvidence` SPI captures actual value/unit subview rectangles and typography roles. Released initializer unchanged.
- `Packages/LifeBoardTokens/Sources/LifeBoardTokens/SemanticTypographyTokens.swift`: canonical point sizes/weights/designs. Metric is 28-pt bold rounded; heroDisplay is 34-pt bold default at phone/default text.
- `LifeBoard/Foundation/Design/LifeBoardFoundationGallery.swift`: `AdaptiveHome`, `AdaptiveHomeStore`, `HomeDashboardWidget`, production adapters, shared titles/metrics, section rendering, production layout integration. Large file; read focused ranges.
- `LifeBoard/Features/DailyLoop/Data/HomeLifeOSProjectionStore.swift`: DEBUG fixture installation.
- `LifeBoard/Foundation/Design/HomeFastingWidget.swift`: live timing adapter; shared content is clock-free.
- `LifeBoard/Foundation/Navigation/HomeCardPlacementSheet.swift`: supported size choices, selected size, actual renderer, outer-container width measurement (previous Wide feedback loop fixed).
- `LifeBoard/Foundation/Navigation/ScreenRootHeader.swift`: root feature header artwork.
- `LifeBoard/DesignSystem/ComposerScaffold.swift`: Capture header integration; verify expansion on the actual route.
- `Packages/LifeBoardDomain/Sources/LifeBoardDomain/HomeDashboardContracts.swift`: domain kinds/registry contracts; confirm registry implementation via `rg`.

Feature integrations also touch:

- `LifeBoard/Features/Journal/UI/LifeBoardTrackAndJournalViews.swift`
- `LifeBoard/Features/Track/UI/LifeBoardTrackFoundationViews.swift`
- `LifeBoard/Features/Track/UI/TrackFastingViews.swift`
- `LifeBoard/Features/Health/UI/WellnessPresentationComponents.swift`
- `LifeBoard/Features/Health/UI/LifeBoardPhaseVIViews.swift`
- `LifeBoard/Features/Health/UI/LifeMomentsViews.swift`
- `LifeBoard/Features/Plan/UI/PlanOrientationBar.swift`, `PlanCapacityCard.swift`, `PlanActiveFocusCard.swift`

### Recent verified native fixes

1. Source transparent padding is cropped out for runtime exports with transparent edge clearance. Originals remain untouched.
2. The explicit capture recorder retains its prepared image. An assertion reproduced cache eviction between preload and ImageRenderer (Sleep light appeared blank). Subsequent captures show the scene correctly. Live views already retain loaded state; cache budgets were not increased.
3. Setup/Goals narrow ring text now stacks instead of truncating. The final light native captures were visually inspected with complete text.
4. `HomeCardLinearProgressStyle` in `HomeProgressCardContent.swift` draws a 4-pt SwiftUI track. It replaces platform flattening warnings in ImageRenderer while keeping a native ProgressView. The final Progress Wide light capture shows the correct 40% track. Also used by shared Fasting content.
5. Progress fractions are numeric metadata, not visible-copy strings, so generated prompts must not print a stray `0.4` or `40%` label.
6. Tasks dark scene was regenerated to remove baked-in checklist-like marks. Canonical source passes alpha/safe-bound audit; runtime bytes were rebuilt reproducibly.

## 5. Asset locations and generation pipeline

### Files and directories

- `DesignAssets/Sources/HomeCards/`: 44 canonical scene PNGs, originals, revisions.
- `DesignAssets/Sources/AmbientSurfaces/`: 34 feature-header sources and originals.
- `LifeBoard/Assets.xcassets/HomeCardScenes/`: optimized 22 appearance-paired image sets.
- `LifeBoard/Assets.xcassets/AmbientSurfaces/`: optimized 17 appearance-paired header sets.
- `docs/design/home-cards/references/`: current generated UI exports, `.source.png` originals, `.transform.json` files, `revisions/`.
- `docs/design/home-cards/submissions/`: immutable exact submitted JSON and content-hashed `inputs/` snapshots.
- `docs/design/home-cards/native-specifications/`: 184 current 4× native PNGs plus JSON elements and source signatures.
- `docs/design/home-cards/live/`, `preview/`, `live-preview-measurements.json`: representative adapter/preview evidence.
- `docs/design/home-cards/implementation/`, `history/`, `ambient-review/`: earlier supporting native captures.
- `docs/design/home-cards/packaging-reproducibility.json`: 275-file matching-byte result.

### Scripts

- `scripts/home_card_design_catalog.py`: builds 228 stable manifest prompts; preserves provenance/revisions; reads native specs; resolves integer canvas/card/export geometry; computes prompt hashes.
- `scripts/home_card_prompt_content.py`: legacy fallback content interpretation. Native exported copy now takes precedence for all ready entries. Do not return to approximate independent Python copy.
- `scripts/home_card_manifest_io.py`: shared lock + atomic writes + hashes + source-built Swift helper binaries under `build/design-tools/`.
- `scripts/prepare_home_card_generation.py ID --revision-reason TEXT`: freezes exact submission/input images before tool dispatch. For a design-review entry it now requires explicit `--design-review-hypothesis TEXT`.
- `scripts/prepare_home_card_batch.py ID...`: freezes several submissions and prints orchestration JSON; makes no generation calls.
- `scripts/record_home_card_generation.py ID SOURCE --submission FILE`: preserves originals/revisions immediately, exports, records results. Use `--failure TEXT` for failure. Late submissions are archived without overwriting a newer current result. Replacements always reset inspection.
- `scripts/inspect_home_card_reference.py ID accepted|rejected|design-review --notes TEXT`: records actual visual inspection; refuses stale spec/reference acceptance.
- `scripts/export_home_card_reference.swift`: explicit canvas/card transform, proportional scaling, intentional padding separated from <=4% unintended aspect correction.
- `scripts/normalize_home_card_scene.swift`, `audit_home_card_images.swift`: production normalization/alpha/safe-area checks.
- `scripts/package_home_card_scenes.py`, `package_ambient_surfaces.py`, `export_ambient_surface.swift`: deterministic runtime packaging from accepted complete appearance pairs.
- `scripts/sign_home_card_specifications.py`: run immediately after successful explicit capture; records renderer files, typography, fixture, artwork and capture hashes. It currently signs all exported JSON, so do not use it to falsely sign stale partial captures.
- `scripts/capture_home_card_evidence.sh`: build-for-testing + explicit test export. Normalizes `HomeCardPresentationTests/method` shorthand to `LifeBoardTests/...`. Default command is the old exhaustive geometry export; always provide the intended filter.
- `scripts/validate_home_card_design.py`, `validate_ambient_surfaces.py`: read-only integrity. `--complete` intentionally fails until completion gates pass.
- `scripts/home_card_review_report.py`: gallery export; never changes manifest acceptance.
- `scripts/test_home_card_export.py`, `test_home_card_manifest.py`: three meaningful tests each; both passed at handoff.

### Built-in generation only

Read the available imagegen skill. Prior path was `/Users/saransh1337/.codex/skills/.system/imagegen/SKILL.md`. Use the **built-in image-generation tool exclusively**, one call per requested reference. Do not switch to CLI/API generation or fabricate references from screenshots. Deterministic native captures and deterministic cropping/resampling are allowed for their stated evidence/export roles.

Use two concurrent generation requests, save each successful result immediately, inspect every generated reference, and record failures. No quota failure occurred during the latest batches; the old September 15 reset timestamp is historical and not a current blocker.

Suggested sequence:

1. Rebuild/validate the catalog if sources or native specs changed.
2. Prepare stable IDs via `prepare_home_card_batch.py` or individual prepare command.
3. Read the frozen submission and inspect its structural reference before dispatch.
4. Pass `submitted_prompt` and the frozen input paths to built-in imagegen. Resolve paths against the repository root.
5. Save each successful tool output immediately with `record_home_card_generation.py` and its **matching frozen submission**.
6. Visually inspect source/export against native geometry and copy, then record acceptance/rejection with specific notes.
7. Refresh the gallery and tracker. Skip only truly current accepted entries.

Built-in outputs in the previous session were saved under `/Users/saransh1337/.codex/generated_images/01a0a4fd-322d-7363-b61d-768a7ff90039/`. The repository copies and frozen submissions are authoritative; do not depend on a previous REPL store or `/tmp` binary. There is no generation request left running at handoff.

### Proven generation direction

**Native structural input first, accepted scene second** works much better than the reverse. The useful prefix is:

> Precise UI reconstruction: reproduce Image 1 with its exact native framing, typography, buttons, and barely visible background paint. Image 2 documents the painting subject only; it must not increase the paint contrast. No external border, no additional top or bottom space.

The catalog supports persisted `native_first`, `prompt_prefix`, `prompt_appendix`, `canvas_override`, and `card_rect_override`. Some newly ready generic entries have not yet received the native-first settings; set them deliberately before freezing submissions. Preserve existing accepted entries and their hashes. The builder swaps Image 1/Image 2 references and wording when `native_first` is enabled.

### Tasks Compact framing problem

- Logical sample: 170.5×476.75 pt; final export 682×1907 px; normal requested canvas 688×1920 px.
- Built-in output repeatedly came back 919×1711, exceeding the 4% aspect-correction allowance.
- A 2048-square padded attempt with card rectangle `[683,70,682,1907]` passed numeric canvas mapping but drew a wider card; crop clipped task checkboxes. It was visually rejected.
- Native-first retry still had the wrong tall aspect. Light was flagged for design review after unsuccessful targeted hypotheses.
- Do not stretch, loosen crop limits, silently reinterpret card proportions, or repeatedly retry unchanged prompts.
- **Untested possible new hypothesis:** provide an explicit padded native structural canvas with a strongly contrasting matte outside the exact card rectangle, so the model sees the intended narrow card within a square. This has not been implemented or accepted. If exploring it, preserve provenance, use a new design-review hypothesis, and verify every checkbox/control survives the export.

Exemplar goal remains Journal Wide L/D, Tasks Compact L/D, Body Metric Glance L/D. Only Body Metric is currently accepted against the latest spec; Journal needs current replacements, Tasks needs framing resolution.

## 6. Remaining native/route validation

### Representative card matrix

Phone, both appearances:

- Glance: Body Metric, Log Meal.
- Compact: Setup, Care, Routines, Goals, Workout, Sleep, Movement, Life Moment.
- Wide: Focus Now, Life Snapshot, Tasks, Capacity, Quick Capture, Day Shape, Journal, Progress, Fasting, Saved Eva Insight, Nutrition Summary, Recent Meal.
- Extra six cases: Tasks Compact and Expanded; Journal Story; Quick Capture Glance; Care Glance; Body Metric Wide.

Tablet, both appearances, six cases:

- Tasks Wide, Journal Story, Care Compact, Body Metric Glance, Life Snapshot Wide, Recent Meal Wide.

Total: 68 configurations / 136 matching adapter and preview images. Refresh after recent native refinements. These remain card adapters until measured in production Home.

### Full Home and actual routes

Implement/use a DEBUG deterministic entry point through **production `AdaptiveHome` and `DashboardFlowLayout`**, not a separate imitation. Fixed Sep 15 2026, UTC, `en_US`, morning, default text size, stable IDs, explicit feature flags/sources, isolated seeded repositories. Record actual safe areas, content bounds, gaps, placement frames, source IDs, and renderer revision.

Capture 16 full-Home arrangements: paired narrow, solitary narrow widening, mixed heights/sizes, Low Energy × phone/tablet × light/dark. Confirm scroll reachability and placement.

Validate these 17 actual feature screens in light/dark on phone:

Home, Track, Plan, Insights, Eva, Journal, Care, Routines, Goals, Fasting, Body Metrics, Workouts, Sleep, Movement, Nutrition, Life Moments, Capture.

Spot-check Home, Journal, Nutrition, Capture on tablet. Verify correct unique art, owning-header clipping, readable native titles/actions, no duplicate decoration/added height, privacy/degraded suppression, and Capture expansion bounds. Existing 34 component screenshots are not substitutes.

### Functional and state checks

- Pin/resize/reorder/remove, Save/Cancel, relaunch persistence.
- Selected size persists; singleton and source-specific multiple instances; existing-placement handling.
- Smart Slot ownership and feedback.
- Tasks complete/Undo/refresh failure-recovery/date selection/Show more-less/detail route.
- Care and Routines source destinations/actions/recovery.
- Fasting start/active/finish/cancel/completed receipt.
- Capture composers, Day route, Journal write/search/reflection, progress evidence, recorded-source detail routes.
- Preview spies and repository/router snapshots: zero attributable mutation/navigation/haptic/timer/network side effects; separate startup activity.
- Representative empty/loading/degraded/unavailable/redacted/deleted-source/missing-image states, completed sessions, long text/large values, user-media precedence, protected Journal/Eva.
- Default-size VoiceOver order/labels/values, 44-point targets, contrast, keyboard dismissal; sample RTL, Bold Text, Increase Contrast, Reduce Transparency/Motion. **No XXXL or Dynamic Type sweep.**

## 7. Tests, known blockers, and performance

### Main tests and commands

- `LifeBoardTests/HomeCardPresentationTests.swift`
- `LifeBoardUITests/LifeBoardUITests.swift`
- `scripts/run-baseline-aware-tests.sh`
- `scripts/check-documentation-current.sh`
- `scripts/check-xcode-target-membership.sh`

```sh
python3 scripts/validate_home_card_design.py
python3 scripts/validate_ambient_surfaces.py
python3 scripts/test_home_card_export.py
python3 scripts/test_home_card_manifest.py
LIFEBOARD_CAPTURE_TEST_FILTER=LifeBoardTests/HomeCardPresentationTests/testExportInstrumentedElementSpecifications bash scripts/capture_home_card_evidence.sh
LIFEBOARD_CAPTURE_TEST_FILTER=LifeBoardTests/HomeCardPresentationTests/testProductionAdapterAndPreviewGeometryParity bash scripts/capture_home_card_evidence.sh
LIFEBOARD_TEST_PROFILE=representative-redesign bash scripts/run-baseline-aware-tests.sh
python3 scripts/home_card_review_report.py
bash scripts/check-documentation-current.sh
bash scripts/check-xcode-target-membership.sh
python3 scripts/validate_home_card_design.py --complete
```

Use `LIFEBOARD_CAPTURE_KINDS=tasks` to filter representative adapter captures. The instrumented specification export currently exports all 184. Ordinary tests do not write docs. The baseline script’s default behavior remains unchanged; its explicit representative profile excludes eight named accessibility/export/typography sweep methods and does not expand the failure baseline.

### Latest final native export

- `/tmp/lifeboard-final-native-specs-compile-sep16.log`
- `/Users/saransh1337/Library/Developer/Xcode/DerivedData/LifeBoard-bwsbwhskioltifbmbqawesubbvsl/Logs/Test/Test-LifeBoard-2026.09.16_01-53-13-+0530.xcresult`
- Simulator test build succeeded; one explicit export test passed; 184 specifications signed; read-only manifest validator zero integrity errors.
- Light Setup Compact, Goals Compact, and Progress Wide final captures were visually checked after the fixes.
- Do not treat this explicit export as all behavior passing.

### Broad suite

Result: `build/test-results/HomeCardsRepresentativeSep16.xcresult`; log `/tmp/lifeboard-baseline-representative-sep16.log`.
Durable summaries:

- `docs/design/home-cards/checkpoints/2026-09-16/representative-suite-summary.json`
- `docs/design/home-cards/checkpoints/2026-09-16/failure-source-comparison.json`

Seven failed methods remain **unclassified**:

1. `ArchitectureBoundaryTests/testViewLayerDoesNotUseSingletonDependencyContainers` — `CompositionRoot.shared` literal in TaskDetailScreen; two assertions.
2. `AssistantPlannerServiceTests/testEvaTurnRouterKeepsNormalChatOutOfProposalPlanner` — dayPlanning versus readOnlyReview.
3. `FeatureFlagPromotionTests/testEveryStagedFlagHasAPromotedDefault` — `feature.onboarding.seamless_v1` missing.
4. `FeatureFlagPromotionTests/testReachableStagedSurfacesArePromotedForRelease` — same missing promotion.
5. `HabitCoreDataSchemaRegressionTests/testTaskModelCurrentVersionPointsToAnExistingSourceModel` — TaskModelV3_EvaDecisionLoops versus BehaviorFlagship expectation.
6. `LifeOSFoundationContractTests/testEveryPreviousModelMigratesToCurrentModelWithoutChangingStableIDs` — 23 predecessors versus 22.
7. `TaskListWidgetSourceContractTests/testWidgetTargetLinksTheSharedTokenPackage` — package reference assertion.

Three previously failed methods passed in that run. No isolated causal comparison build has established origins. Source equality to HEAD alone is not sufficient classification. Concurrent edits may change present failures; rerun appropriately and preserve unrelated work in any comparison checkout. Do not widen the baseline to manufacture success.

### Care compound UI test

`testFoundationHomePrimaryActionsUseTypedNativeDestinations` changed obsolete `Overview` assertion to `track.medication.new` because source routing takes `.careLibrary` to the medication area. The typed Care route/control passed, but the compound test then failed finding `home.capacity.openDay`. A follow-up setting morning atmosphere failed earlier on a non-hittable Home button. Thus the test still does not pass.

- `/tmp/LifeBoardCareRoutesSep16.xcresult`
- `/tmp/LifeBoardCareRoutesMorningSep16.xcresult`
- `/tmp/lifeboard-care-routes-attachments/`

Resolve deterministic launch/daypart/scroll state and verify Capacity. Do not claim navigation is fixed from replacing an assertion. These runs used an available 402×874 simulator surface, not canonical 393×852 evidence.

### Membership blocker

`/tmp/lifeboard-membership-sep16.log`: app build-for-testing completed; LifeBoardWatch could not build because **watchOS 26.5 is not installed**. Obtain the platform/compiler evidence if feasible; do not extend the visual redesign to Watch. Keep this blocker visible until resolved.

### Performance still required

Matching simulator, fixture, configuration, and animation settings: three cold and three warm scrolling cycles, CPU, peak memory, preparation counts/cache reuse, available hitch metrics; repeat once if variance >10%; investigate repeatable CPU/memory regressions >10%. Check repeated root switching and Capture expansion for retained-image growth. No source-resolution runtime loads or repeated decoding from view recomputation.

Prior supporting runs only:

- `/tmp/LifeBoardAmbientScroll.xcresult`: 12.114 s scripted cycle, 1.842 s CPU, 122,320 kB average peak physical memory.
- `/tmp/LifeBoardFeatureHeaderScroll.xcresult`: 12.155 s scripted cycle, 1.838 s CPU, 116,384 kB memory.

No hitch metric was emitted. These are not FPS or a controlled speedup claim. Cache limits are eviction budgets, not a total application memory cap.

## 8. Documentation and final acceptance

The new deep guide and creative chapter already cover:

- Ambient rationale and five size intents.
- 22 Home motifs and 17 header identities.
- Native layering, image crop/mask/opacity, shared typography, privacy/media precedence.
- Appearance/daypart independence and motion budget.
- Generation provenance, exact dimensions, originals/runtime distinction, reproducible packaging and cache behavior.
- Direct versus shared-component versus untested evidence.

The separate creative chapter develops six **unimplemented hypotheses**:

1. More distinctive feature environments.
2. Composition-aware narrow/wide/dense scene variants.
3. Connected visual storytelling across related screens.
4. User-controlled botanical/architectural/landscape collections.
5. Meaningful restrained transition moments within the existing motion budget.
6. Media and illustration coexistence with clear ownership/privacy.

Each has benefits, screen examples, subjects/palettes, invariants, constraints, required assets/engineering, a small prototype, acceptance criteria, rejection risks, and priority. Do not turn these into additional implementation commitments.

Before final handoff, reconcile canonical docs with final code, update counts and durable links, run metadata/link/doc checks, refresh gallery/tracker, and clearly label remaining blockers. Correct contradictory current rules instead of appending competing descriptions. Preserve shared section-header typography.

## 9. Recommended immediate next steps

1. Read current diff, this handoff, `VALIDATION.md`, manifests, and the deep guide. Verify current status since other work is concurrent.
2. Refresh the 136 representative adapter/preview images after the final ring/progress/retention changes. Do not run XXXL/exhaustive behavioral tests.
3. Review remaining structural input quality, set native-first generation settings for newly ready entries, and resolve current Journal Wide replacements plus a genuinely new Tasks Compact framing hypothesis.
4. Generate the remaining catalog in resumable two-request batches. Inspect every output and preserve failed/superseded originals. Group by behavior: orientation; queues; planning/capture; progress/sessions; recorded sources; media/insights/meal capture.
5. In parallel with tool waits, implement deterministic production-Home and actual-route evidence and remaining functional/state checks.
6. Complete controlled regression classification, membership/compiler evidence, performance, then final docs/gallery/report reconciliation.

**Completion means:** 184 accepted current references; preserved valid production/header art; representative native and actual-route evidence; passed functional scenarios and honest regression classifications; reproducible assets and controlled performance evidence; reconciled canonical docs plus separate unimplemented creative directions. Until then, report progress truthfully and continue useful authorized work.
