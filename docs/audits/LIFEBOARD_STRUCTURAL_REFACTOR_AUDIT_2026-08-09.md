# LifeBoard Structural Refactor Audit — 2026-08-09

## Audit state

This document deliberately preserves two views of the work:

- **Pre-fix baseline:** immutable findings for `master` (`83222f0f`) through refactor HEAD (`a5a6087a`).
- **Resolution record:** status, fixes, and verification evidence added as remediation proceeds.

The audit covers the 14 commits in `master...a5a6087a`, their aggregate diff, the working tree at review start, source and test membership, package boundaries, persisted and string contracts, CI/runtime guardrails, and Release reachability. A finding is not closed merely because a file moved or a gate exited successfully; closure requires evidence that the intended compiler or runtime boundary is operating.

## Anti-pattern verdict

The refactor improves discoverability substantially: phase-, generation-, and presentation-oriented folders were largely replaced by feature-oriented paths, and several oversized Home surfaces were consolidated. The reviewed UI changes do not establish a new generic dashboard aesthetic or an unrequested visual redesign. Existing card/glass/token vocabulary remains intentionally unchanged.

The structural implementation does, however, exhibit an architectural anti-pattern: **directory boundaries are presented as module boundaries even though the compiler still sees one app module for all 21 features**. That makes the architecture guide and execution ledger stronger than the enforcement actually delivered. The remediation target is therefore compiler-enforced packages without visual or behavioral change.

## Executive summary — pre-fix baseline

The branch contains 14 commits and changes 1,253 files: 48,813 insertions and 34,438 deletions. Git classifies 869 paths as renames at a 50% similarity threshold; 458 are byte-identical (`R100`) and 411 combine a move with semantic edits. The remaining aggregate change contains 134 additions, 162 deletions, and modified files. This is materially larger than a move-only reorganization and requires semantic review and full regression testing.

Four foundational products exist (`LifeBoardContracts`, `LifeBoardTokens`, `LifeBoardUI`, and `LifeBoardDomain`) and independently describe a sensible core dependency direction. Feature code has been relocated into 23 feature-like directories, but none of the approved 21 features is a SwiftPM target. `Calendar` is still feature-shaped rather than shared support, `Inbox` is not folded into Plan, persistence and the Core Data model remain app-owned, and route factories are absent. The stated end-state is therefore incomplete.

At audit start the only working-tree modification was `LifeBoard/Localizable.xcstrings`. It was produced by the planning build and removed four entries from the frozen 904-key catalog. This is review-tool drift, not an authored refactor change, and must be restored before remediation.

## Commit inventory

| Commit | Intent | Files | Insertions | Deletions | Audit note |
|---|---|---:|---:|---:|---|
| `50da3a55` | Contracts extraction | 6 | 64 | 41 | Package introduced; five moved files include access/API edits. |
| `a1105877` | Domain extraction | 90 | 896 | 561 | Package introduced; eight deletions and broad public-surface changes. |
| `2695d40c` | Token extraction | 20 | 652 | 298 | Package introduced; visual values require frozen-fixture checks. |
| `e7d75f88` | UI extraction | 20 | 617 | 1,071 | Package introduced; two source deletions and semantic component edits. |
| `0682b799` | Eva relocation | 133 | 3,045 | 979 | 131 renames, many with semantic/access-control changes. |
| `270fa2b7` | Onboarding relocation | 121 | 53 | 53 | Pure relocation at aggregate line level. |
| `1fa4a0f0` | Phase-folder dissolution | 203 | 43,077 | 7,854 | Largest semantic construction wave: 99 additions, four deletions. |
| `2188f082` | Presentation/Home consolidation | 409 | 8,032 | 45,675 | Largest deletion/consolidation wave: 216 deletions, 177 renames. |
| `118fc536` | Settings relocation | 65 | 2,020 | 314 | Mostly moves with access/import changes. |
| `53408f35` | App/runtime/persistence consolidation | 148 | 11,753 | 11,429 | 44 additions, four deletions, 25 modifications; high runtime risk. |
| `7b38dc9f` | Test/extension updates | 63 | 1,581 | 2,313 | Deletes nine test files and 37 test methods with no replacements found. |
| `36d22024` | Legacy controller removal | 1 | 0 | 28 | Must be supported by Release reachability evidence. |
| `060f93a5` | Guardrails | 34 | 9,448 | 1,863 | Several gates pass while omitting intended scope or missing files. |
| `a5a6087a` | Completion documentation | 22 | 5,657 | 41 | Claims completion before package/route/persistence goals are satisfied. |

## Detailed findings — pre-fix

### Critical

#### C-01 — The declared compiler-enforced feature architecture does not exist

All approved feature folders still compile as part of the `LifeBoard` application target. Only four core SwiftPM products exist. There are no products for `LifeBoardPersistence`, `LifeBoardCalendar`, or the 21 approved feature targets, and there is no compiler-level prohibition on feature-to-feature or feature-to-App references.

**Risk:** dependency cycles and cross-feature coupling remain possible while CI reports the directory convention as compliant.

**Required resolution:** one in-repo manifest, an acyclic declared adjacency graph, 21 feature products, Calendar support, Persistence, and independently compiling targets.

**Status:** Partially remediated. One manifest now declares six independently
buildable core/support products and Calendar has crossed the boundary. The 21
feature targets, feature route factories, and the remainder of Persistence have
not been extracted, so this critical finding remains open.

#### C-02 — Frozen localization contract was modified by the audit build

The working catalog dropped `%@ · %@–%@`, `focused`, `No focus\nrecorded`, and `Position %@ of %@`. HEAD and the frozen snapshot both contain exactly 904 keys.

**Risk:** missing runtime translations and a false-positive refactor diff.

**Required resolution:** restore the four entries exactly and prove the combined app/package catalog retains the exact key and translation set.

**Status:** Resolved. The four entries were restored, app and package catalogs
are aggregated, and the exact 904-key/translation snapshot passes.

### High

#### H-01 — Test coverage was deleted rather than migrated

Nine test files were removed and their methods are absent from the current tree: `AISuggestionServiceTests` (4), `AssistantCardPayloadTests` (4), `AssistantDiffPreviewBuilderTests` (5), `HomeBandLayoutPlannerTests` (3), `HomeSearchStateTests` (9), `TaskAgendaPresentationModelBuilderTests` (3), `TaskAgendaPresentationModelTests` (4), `AddTaskSuggestionFlowTests` (4), and `TaskBreakdownFlowTests` (1). Total: **37 deleted test methods**.

**Risk:** assistant payload/codec, Home search/layout, agenda presentation, task capture, and task-breakdown regressions are no longer covered.

**Required resolution:** restore or migrate all nine files to their owning module/integration suites without deleting assertions.

**Status:** Resolved. All nine files and 37 methods were restored. The seven
unit-test files were returned to target membership; the two UI files were
modernized where their deleted assertions targeted UI that was already absent
on `master` (the optional icon was never supplied and capture is now exposed as
dedicated Task/Habit entry points).

#### H-02 — Runtime guardrail is fail-open on missing inputs

`scripts/validate_legacy_runtime_guardrails.sh` references removed `PresentationDependencyContainer.swift` and `EnhancedDependencyContainer.swift` paths. `rg` reports missing files but the script exits successfully.

**Risk:** a missing guardrail input is interpreted as compliance.

**Required resolution:** centralize paths, make missing required inputs fatal, and inspect the App-tier `CompositionRoot`.

**Status:** Resolved. Required paths are centralized, missing inputs are fatal,
and the guard inspects `CompositionRoot`.

#### H-03 — CI references deleted DI paths

`.github/workflows/ios.yml` still greps the removed `LifeBoard/Presentation/DI/PresentationDependencyContainer.swift` and `LifeBoard/State/DI/EnhancedDependencyContainer.swift` files.

**Risk:** CI fails independently of product correctness, while local guardrails do not expose the mismatch.

**Required resolution:** update CI to the actual composition root and reuse repository scripts rather than duplicate path-sensitive grep logic.

**Status:** Resolved. CI invokes the repository guard rather than grepping the
removed DI paths.

#### H-04 — Core Data remains app-bundle/codegen coupled

`TaskModelV3.xcdatamodeld` remains in the app. Eleven entities in the shipped model chain use Class Definition generation, and the bootstrap constructs `NSPersistentCloudKitContainer(name:)` without an explicitly loaded package model.

**Risk:** moving the model into a package without manual managed-object classes and `Bundle.module` loading can change class lookup or make the model unreachable, threatening existing stores and CloudKit setup.

**Required resolution:** Manual/None for the 11 entities in all shipped versions, public classes/properties preserving Objective-C names, and explicit model/container factories with migration and store-contract tests.

**Status:** Resolved for model ownership and loading. The model is a
`LifeBoardPersistence` resource, every shipped version uses Manual/None for the
11 entities, public managed-object classes preserve Objective-C names, and app
bootstrap/tests load the explicit package model. Completion of the remaining
Persistence source extraction is tracked by C-01.

### Medium

#### M-01 — Target membership gate is PBX-text-derived

`scripts/check_xcode_target_membership.rb` walks `PBXBuildFile`, `PBXSourcesBuildPhase`, and `PBXNativeTarget` records. It does not derive source membership from compiler invocations and will not prove folder-implicit membership after filesystem-synchronized groups are adopted.

**Status:** Partially resolved and blocked by the local SDK set. The replacement
gate derives membership from Xcode-produced `.SwiftFileList` inputs and passes
for app, hosted tests, iOS widgets, and share extension. It correctly fails for
Watch and Watch widgets because watchOS 26.5 is not installed; no PBX upgrade is
performed without that proof.

#### M-02 — Module-boundary gate is regex-only and omits unified package sources

The gate checks a small set of imports by path but has no declared target adjacency graph, no syntax-aware import parsing, and no feature-to-feature enforcement because features are not modules.

**Status:** Resolved as a source-level transitional gate. Imports are parsed via
the Swift compiler syntax tree and checked against a declared adjacency graph
across app and package sources. Feature rows remain policy declarations until
the feature targets in C-01 exist.

#### M-03 — Guardrail coverage is split between app and package sources

File-size, shrapnel, localization, accessibility, SwiftLint, and token checks do not consistently aggregate `LifeBoard/`, extension targets, and every package target/resource catalog.

**Status:** Resolved. The file-size, directory-shrapnel, localization,
accessibility, frozen-contract, and SwiftLint gates aggregate app and package
sources/resources.

#### M-04 — Committed WIP patch artifacts break clean-diff validation

`docs/evidence/wip/adaptive-home-split.patch` and `docs/evidence/wip/foundation-shell-scaffolding.patch` contain trailing whitespace, so `git diff --check master...HEAD` fails. Their paths describe already-landed work and they are not executable evidence.

**Status:** Resolved. Both patch artifacts described already-landed content and
were removed. `git diff --check` passes.

#### M-05 — Completion documentation overstates architecture status

The execution ledger says the program is complete while Persistence, Calendar, every feature target, public route boundaries, naming completion, and synchronized-group migration are absent.

**Status:** Resolved. The architecture guide now describes the implemented six
product graph and transitional app module. The historical execution ledger has
a prominent correction linking to this audit.

### Low / follow-up

#### L-01 — Existing compiler/lint debt remains visible

The clean planning build surfaced a retroactive `Equatable` conformance warning in Insights and deprecated `Text + Text` usage in `AtmosphereSlider`. The recorded SwiftLint baseline is 349 findings. These are not evidence of a refactor regression unless changed-line attribution proves otherwise.

**Status:** Deferred to the post-refactor improvements ledger unless touched by remediation.

## Reachability baseline

The required Release analysis must retain application, every `AppRoute`, widgets, Watch app/widgets, share extension, Objective-C/storyboard roots, intent/shortcut declarations, and known string-reached surfaces. `periphery` is not installed at baseline. No production deletion will be accepted from reference counts alone. Candidate lists and deletion decisions will be appended here with exact paths and test reachability.

The only explicit production deletion commit in the reviewed sequence removes
`LifeBoard/ViewControllers/ColoredPillBackgroundView.swift` (28 lines). A
retained-root search on `master` found no Swift/Objective-C/storyboard/string,
route, extension, Watch, intent, or test reference beyond its own declaration
and PBX file records. Current Debug/Release compilation and the full hosted
suite succeed without it. This deletion is accepted as unreachable. No
additional production source was deleted during remediation.

## Architecture compliance matrix — pre-fix

| Requirement | Baseline | Evidence |
|---|---|---|
| One in-repo SwiftPM manifest | Fail | Four separate manifests under `Packages/`. |
| Core products through Calendar/Persistence | Partial | Contracts, Tokens, UI, Domain only. |
| 21 compiler-enforced feature targets | Fail | Feature folders remain in app target. |
| Inbox folded into Plan | Fail | `LifeBoard/Features/Inbox` exists. |
| No feature-to-feature imports | Unproven | No feature modules; regex gate cannot enforce target edges. |
| Feature-owned public route factories | Fail | App owns route enum/destination construction. |
| Core Data model package resource | Fail | Model remains under `LifeBoard/`. |
| Exact 904-key localization contract | Regressed in working tree | Four entries removed by build; HEAD snapshot was exact. |
| Accessibility contract retained | Pass at baseline | Existing snapshot gate reports 828 expressions. |
| Test coverage retained | Fail | 37 methods deleted without replacement. |
| Compilation-derived membership | Fail | PBX object parser. |
| Syntax-aware adjacency enforcement | Fail | Regex/path checks only. |
| Filesystem-synchronized project, objectVersion 77 | Fail | `objectVersion = 60`. |
| Clean aggregate diff | Fail | Two committed WIP patch artifacts trigger whitespace errors. |

## Positive findings

- The Contracts, Domain, Tokens, and UI packages establish a useful dependency spine and were buildable during the initial project build.
- Git recognizes 458 exact renames, showing a substantial portion of the reorganization preserved file contents byte-for-byte.
- The feature-oriented directory map is materially easier to navigate than the prior phase/generation layout.
- The branch added migration-chain coverage for all 23 Core Data model versions, including oldest-version row survival and configuration reachability.
- Accessibility, localization, file-size, shrapnel, SwiftLint-debt, Core Data, phase, and print guardrails exist and provide a strong base once their scope and failure behavior are corrected.
- The pre-fix generic Simulator build succeeded on Xcode 26.5, providing a useful compilation baseline before package extraction.

## Resolution log

| Finding | Resolution | Verification | Status |
|---|---|---|---|
| C-01 | Unified root manifest; added Persistence/Calendar products; folded Inbox into Plan | Six products Debug/Release green; features still app-owned | **Partial / open** |
| C-02 | Restored four catalog entries; aggregate catalog hashing | 904 keys and frozen translations pass | **Resolved** |
| H-01 | Restored nine files/37 methods; updated stale capture UI expectations | Full hosted suite green; focused restored UI smoke green with one data-dependent skip | **Resolved** |
| H-02 | Fail-closed centralized runtime paths; CompositionRoot scan | runtime guard passes and missing-input mutation fails | **Resolved** |
| H-03 | CI delegates to repository guard | workflow path scan clean | **Resolved** |
| H-04 | Package model resource, Manual/None chain, public classes, explicit factories | 23 migration checks and 316-test persistence focus pass | **Resolved** |
| M-01 | `.SwiftFileList`-derived membership | iOS/app/tests/extensions pass; Watch SDK unavailable | **Partial / environment-blocked** |
| M-02 | Compiler syntax-tree import parsing plus declared graph | 971 files across 28 declared modules pass | **Resolved as transitional gate** |
| M-03 | Extended structural scopes to package inputs | all scoped gates pass | **Resolved** |
| M-04 | Removed two obsolete WIP patch artifacts | clean diff check passes | **Resolved** |
| M-05 | Rewrote guide and corrected historical ledger | documents no longer claim feature extraction | **Resolved** |

## Final verification evidence

### Build and test evidence

- Unified core/support manifest: every one of the eight products builds
  independently in Debug and Release. Log:
  `/tmp/lifeboard-core-products-build.log`.
- Signed iOS Simulator hosted-unit run: **2,203 executed, 4 skipped, 0
  failures**. Retained result:
  `/tmp/lifeboard-full-unit-signed-final.xcresult`.
- Persistence/package focus: **316 tests, 0 failures**, including all inferred
  migrations, oldest-row survival, model/configuration compatibility, Health
  sync, planning, and foundation cases. Retained result:
  `/tmp/lifeboard-persistence-package-final.xcresult`.
- Package-linkage smoke: three migration tests pass without duplicate package
  runtime symbols. Retained result:
  `/tmp/lifeboard-package-linkage-smoke.xcresult`.
- App `build-for-testing` succeeds and compiles the app, hosted test bundles,
  iOS widgets, and share extension.
- Restored capture/task-breakdown UI smoke: four capture tests pass; the
  breakdown test is skipped when the seeded workspace exposes no task row.
  Retained result: `/tmp/lifeboard-restored-ui-final-pass.xcresult`.
- Watch/Watch-widget build is **not verified**: Xcode reports that watchOS 26.5
  is not installed. Logs: `/tmp/lifeboard-watch-build.log` and
  `/tmp/lifeboard-watch-membership.log`.

### Frozen and structural evidence

- Localization: exactly **904** keys and translations; content hash
  `bbc652304243775b091e94679af9646a489ad3481d13f3740ce02ffa86aab33d`.
- Accessibility: **828** frozen identifier expressions.
- Frozen contracts pass for storage/default keys (568), CodingKeys/raw values
  (250), Core Data names (3,953), App Group filenames (8), deep-link paths
  (18), and App-route literals (68).
- SwiftLint debt remains at the approved **349** findings; no ratchet increase.
- Syntax-aware module check passes **971 files / 28 declared modules**.
- All 23 compiled Core Data models retain their pre-change `momc` checksums.
- Project plist validation, runtime/Core Data guards, file-size, directory
  shrapnel, accessibility, localization, frozen-contract, and clean-diff checks
  pass.

## Architecture compliance matrix — final working tree

| Requirement | Final status | Evidence / remaining work |
|---|---|---|
| One in-repo SwiftPM manifest | Pass | Root `Package.swift`; nested manifests removed. |
| Core products through Calendar/Persistence | Partial | Eight products exist; feature targets remain open. |
| 21 compiler-enforced feature targets | **Fail / open** | Feature directories remain app-compiled. |
| Inbox folded into Plan | Pass | Inbox Domain/Data/UI now live under Plan. |
| No feature-to-feature/App imports | Policy pass, compiler-unproven | Syntax-aware graph passes; compiler proof awaits feature extraction. |
| Feature-owned public route factories | **Fail / open** | `AppRoute`/router construction remains App-owned without feature factories. |
| Core Data model package resource | Pass | `Bundle.module` API and explicit model/container factories. |
| Exact 904-key localization contract | Pass | Aggregated key and translation snapshot. |
| Accessibility contract retained | Pass | 828-expression frozen set. |
| Test coverage retained | Pass | Nine files/37 methods restored; full suite green. |
| Compilation-derived membership | Partial | iOS family passes; Watch runtime unavailable. |
| Syntax-aware adjacency enforcement | Pass | Compiler parse tree plus declared graph. |
| Filesystem-synchronized project, objectVersion 77 | Deferred by prerequisite | Remains objectVersion 60 until Watch proof succeeds. |
| Clean working diff | Pass | `git diff --check`; no WIP patch artifacts. |

## Acceptance verdict and unresolved risk

The remediation closes the verified localization, test-loss, guardrail,
package-resource, Core Data codegen/loading, Calendar ownership, naming, and
documentation regressions. The resulting branch is buildable and its complete
hosted unit suite is clean.

The requested compiler-enforced feature architecture is **not complete**. The
21 feature products, their public route boundaries, most Persistence
implementation extraction, and migration of 81 app-importing test files remain
substantive engineering work. Watch membership and the conditional PBX object
version/filesystem-group conversion are also unresolved until the matching
runtime is installed. Those items prevent a full acceptance verdict and are
prioritized in `docs/todos/LIFEBOARD_POST_REFACTOR_IMPROVEMENTS.md`.
