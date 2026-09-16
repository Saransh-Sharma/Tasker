# Historical validation log — superseded checkpoint descriptions

This file preserves earlier observations verbatim. Use [the current report](VALIDATION.md) for active status. Statements below describe their dated checkpoints.

# Home card redesign validation

## Dedicated feature headers — 15 September 2026, 11:20 PM IST

Added 34 accepted panoramic variants for 17 main-tab and feature headers. All 102 runtime scale files pass source/dimension/alpha/hash checks. Four focused tests and the simulator build passed; 34 normal-size component captures are saved. The three-cycle Home scrolling check also passed. See [feature-header validation](../ambient-surfaces/VALIDATION.md) and [visual gallery](../ambient-surfaces/index.html). This completes the focused header-art pass; the full original reference and release-validation gates below remain open.

## Ambient design update — 15 September 2026, 10:55 PM IST

The user changed the art direction to ambient backgrounds and deprioritized exhaustive accessibility/preset testing. The current normal-size work supersedes the separated scene-region geometry below.

- Native artwork now fills existing card bounds, with directional reading protection. It adds no height or reserved text column. Body Metric Glance measures 170.5×104 points in the new capture.
- All 22 scene families are connected to matching app surfaces; see [the surface map](AMBIENT_ART_DIRECTION.md).
- Prepared pixels use a shared 32 MiB / 48-image cache with appearance-specific identities and coalesced asynchronous preparation. No animation, blur, or original generation-file loading was introduced.
- Three targeted tests passed: artwork never increases native card height; simultaneous image requests prepare once and reuse the same result; twelve default-text-size exemplar renders were captured.
- [Native ambient visual review](ambient-review/index.html): Body Metric Glance/Wide, Journal Compact/Wide, Tasks Compact/Wide in both appearances. These are implementation captures, not generated references.
- Production-adapter/preview geometry parity passed across the existing fixture matrix immediately before the ambient change. No new exhaustive matrix was run after the user's prioritization change.
- The placement-sheet Wide feedback-loop fix passed the actual Add-to-Home/Undo-receipt UI test. Task expansion UI passed. A separate primary-navigation test reached the typed Care route but failed to find an `Overview` button at the destination; this remains an investigated-later check, not a claimed pass.
- Scrolling benchmark passed three animation-enabled cycles: 12.114s average scripted duration, 1.842s CPU time, 122,320kB average peak physical memory (4.4% relative standard deviation). The runtime did not emit a hitch metric. No before/after improvement or device-wide frame-rate claim is made. Result bundle: `/tmp/LifeBoardAmbientScroll.xcresult`; log: `/tmp/lifeboard-ambient-scroll.log`.

- The final simulator build succeeded (`/tmp/lifeboard-ambient-final-build.log`).
- An explicit geometry-only export refreshed 368 shared-content captures, 184 card-local measurements, and 184 composition records for prompt generation. This is not a full-dashboard or accessibility acceptance matrix.
- Prompt compositions now specify ambient placement and include the accepted scene plus measured native structure as named, hashed references. There remain 26 distinct generated UI-reference entries. Two new ambient attempts preserve the requested aspect ratio but were rejected on inspection: both use overly strong paint; Body Metric adds an unwanted outer margin. Exact submissions and originals are preserved.

Generated references from the earlier composition remain historical. Current card-local geometry is refreshed; production Home safe-area evidence and complete reference acceptance remain open.

## Active implementation checkpoint — 15 September 2026, 10:20 PM IST

The redesign remains in progress. This section supersedes the historical audit below.

- All **44 production scenes** now exist, were inspected, and are packaged as **22 complete appearance pairs / 132 runtime PNGs**. The 13 missing scenes and five rejected replacements were generated with the built-in tool; previous originals remain archived.
- All 44 canonical exports passed the alpha, 1024×1024 dimensions, and numeric safe-bounds audit. Runtime exports crop transparent padding proportionally with edge clearance; original generation files are not loaded by the app.
- **26 distinct UI-reference entries have generated outputs**, with three geometry-guided revisions. These are not all accepted: eleven initial outputs exceeded the safe crop allowance; additional layout review is pending. Exact generation attempts are retained in the manifest.
- **368 refreshed shared-content captures**, 184 size measurements, and 184 native content/scene rectangle measurements exist. They are not full-Home/live-adapter acceptance evidence.
- All specialized card content is extracted into shared views, including Glance, Tasks, Care/Routines, Focus, Life Snapshot, Progress, and the clock-free Fasting content. Domain handlers remain in live adapters.
- A focused Home regression run passed **51 tests / zero failures** at 10:03 PM IST. A subsequent focused run passed **eight presentation tests / zero failures**, including all 92 presets at accessibility XXXL and RTL composition mirroring.
- The customization Cancel/composer UI test passed. The Add-to-Home UI test exposed a width feedback loop when selecting Wide. The measurement was moved to the outer sheet container; the fix is being re-tested.
- Evidence export now requires the explicit `scripts/capture_home_card_evidence.sh` command. Ordinary presentation tests no longer rewrite design documentation.
- The browsable gallery reads the manifest without changing acceptance statuses.

### Current blockers to release acceptance

Remaining generated references and inspection; complete production Home fixture captures and preview parity; all source/action/state flows; accessibility inspection beyond measurability; performance measurements; current broad-suite and documentation/target membership gates. No pair is marked end-to-end accepted yet.

### Current commands and logs

```sh
python3 scripts/package_home_card_scenes.py
python3 scripts/validate_home_card_design.py
python3 scripts/validate_home_card_design.py --complete
scripts/capture_home_card_evidence.sh
python3 scripts/home_card_review_report.py
```

Integrity checks deliberately fail for generated outputs whose dimensions do not match their specification; rejected originals remain available for revision. `--complete` additionally requires all acceptance evidence.

Local execution logs: `/tmp/lifeboard-home-cards-regression.log`, `/tmp/lifeboard-home-cards-interactions.log`, `/tmp/lifeboard-home-cards-interactions-fixed.log`.

## Historical audit before this implementation session


This is an incomplete implementation. No generated UI references are present. Do not treat the sample captures as completed live-card design validation.

- Catalog: 22 kinds, 92 supported size combinations, 228 prompt entries.
- Saved production artwork: 31 of 44; all 31 normalized with preserved originals; 26 scenes accepted, five rejected after visual review. Runtime catalogs exclude rejected variants.
- Normalized output: 1024×1024 PNG with genuine transparency. Pixel audit verifies visible bounds within x=384..960, y=128..896 (one-pixel antialias tolerance).
- Generated UI references: 0 of 184. Image generation returned `usage_limit_reached`; reported reset 2026-09-15 22:44:17 Asia/Kolkata.
- Five focused tests passed after the size-specific composition changes. All five also passed in the full suite after the Journal shared-content extraction.
- 368 sample captures and 184 sample measurements exist. These are shared sample-renderer outputs at phone/tablet content widths, not full device screenshots or measurements of specialized live cards.

## Implemented behavior

- Selected-size addition uses the existing transactional draft; unsupported sizes are rejected.
- Placement sheet and gallery offer inert native sample previews.
- Live bodies and generic samples use the same illustration composition modifier; Journal now shares its exact native content and controls; other specialized live bodies still differ from generic sample content.
- Artwork does not intercept interactions, and is suppressed at accessibility text sizes, increased contrast, or reduced transparency.
- Live illustrations are suppressed for unavailable/protected snapshots and snapshots with actual moment media.
- Original handlers remain responsible for task, care, routine, fasting, and navigation actions.

## Evidence commands

```sh
python3 scripts/package_home_card_scenes.py
swift scripts/audit_home_card_images.swift DesignAssets/Sources/HomeCards/*-light.png DesignAssets/Sources/HomeCards/*-dark.png > docs/design/home-cards/asset-audit.json
python3 scripts/home_card_design_catalog.py
python3 scripts/home_card_review_report.py
```

The focused `HomeCardPresentationTests` suite checks registry coverage, deterministic samples, all sample renderer dimensions, accessibility measurability, draft cancellation, and unsupported-size rejection. It does not establish VoiceOver quality, live action correctness, or visual-reference fidelity.

## Remaining acceptance work

- Inspect all scene subjects visually; normalized geometry alone is not art-direction approval.
- Generate 13 missing scene variants and all 184 design references when the tool becomes available.
- Extract shared native content from specialized cards so gallery samples accurately preview live controls and hierarchy.
- Measure specialized live cards in deterministic full-Home fixtures, including solitary-card widening and iPad layouts.
- Compare every final implementation with its generated reference.
- Exercise live actions, pinning, resizing, ordering, removal, persisted layouts, multiple-instance identity, and Smart Slots.
- Verify VoiceOver, RTL, long localized text, all availability states, and full-dashboard performance.
- Run baseline-aware regression tests and documentation/target-membership checks.

No external generation API fallback was used or requested. Existing image outputs were not regenerated.

## Visual inspection

All 31 saved scenes were inspected together in `scene-contact-sheet.png`. Five were rejected and preserved for revision: both Body Metric variants (body-measurement imagery), both Life Snapshot variants (invented symbolic bubbles), and dark Progress & Reflection (assistant violet outside assistant identity). The remaining 26 are accepted as illustrations, not as UI-reference approval.

## Documentation check

`check-documentation-current.sh` reports 10 issues in the living-document count, metadata for `docs/design/DARK_MODE_ASSET_BRIEF.md`, and four promoted feature flags. These are outside the Home card files changed here; no unrelated documentation was rewritten to silence them.

## Target membership

The membership guardrail found no Home-card source omissions. It could not verify LifeBoardWatch, LifeBoardWatchWidgets, and a Watch capture package test because compiler lists for those targets were absent from this iOS simulator build. This is not a passing all-target membership check.

## Full regression result

The baseline-aware run compiled the app and executed 2,511 XCTest tests, with four skipped and 12 assertion failures across 10 failed methods. The checked-in failure baseline is empty, so the baseline guard failed. All five HomeCardPresentationTests passed, including refreshed evidence generation.

Failed methods:

- ArchitectureBoundaryTests/testViewLayerDoesNotUseSingletonDependencyContainers — TaskDetailScreen references CompositionRoot.shared.
- AssistantPlannerServiceTests/testEvaTurnRouterKeepsNormalChatOutOfProposalPlanner — dayPlanning versus readOnlyReview.
- FeatureFlagPromotionTests/testEveryStagedFlagHasAPromotedDefault — seamless onboarding flag.
- FeatureFlagPromotionTests/testReachableStagedSurfacesArePromotedForRelease — seamless onboarding flag.
- HabitCoreDataSchemaRegressionTests/testPausedHabitsAreExcludedFromSignalQueries — asynchronous timeout.
- HabitCoreDataSchemaRegressionTests/testTaskModelCurrentVersionPointsToAnExistingSourceModel — model-version expectation.
- HomeCalendarIntegrationTests/testHomeViewModelRefreshesCalendarContextManuallyAndOnStoreChanges — asynchronous timeout.
- LifeOSFoundationContractTests/testEveryPreviousModelMigratesToCurrentModelWithoutChangingStableIDs — predecessor count 23 versus 22.
- TaskListWidgetSourceContractTests/testWidgetTargetLinksTheSharedTokenPackage — package-reference expectation.
- TaskNotificationOrchestratorTests/testQuietHoursCanDeferDailySummaryWhenEnabledForDailyNotifications — asynchronous timeout.

These failures concern paths or contracts outside the redesigned card bodies, but an unchanged-code comparison run has not established that every failure predates this work. The failure baseline was not modified. Result bundle: `build/test-results/HomeCardsBaseline.xcresult`.

## Remaining work is explicit

The task is not complete: generation quota prevents completing the 13 missing scenes, five rejected scene revisions, and 184 UI references. Other specialized cards still need exact live/preview content sharing, full-Home measurements, interaction testing, and visual/accessibility acceptance. The current code and evidence are a resumable checkpoint, not release approval.
