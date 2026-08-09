# LifeBoard iOS — architecture guide

> **Classification: Canonical architecture reference.** Product and interaction behavior lives in the [LifeBoard 5.0 product handbook](../product/README.md); current completion is owned by the [Unified Completion Status](../life-os/LIFEBOARD_UNIFIED_COMPLETION_STATUS.md).

**iOS 26.0+ | Swift 6 | TaskDefinition-first runtime**

LifeBoard is V2-only for task domain and runtime flows. Legacy task contracts
(`Task`, `TaskRepositoryProtocol`, bridge adapters, legacy task use cases) are
gone from the production runtime.

## The module graph

Four in-repo SwiftPM packages sit under the app, in strict dependency order.
The graph is acyclic and the compiler enforces it.

```
App (LifeBoard.xcodeproj)
  AppDelegate · SceneDelegate · AppRouter · FoundationShell · App/DI
        │  maps AppRoute onto each feature's route factory
        ▼
LifeBoard/Features/<Feature>/{Domain,Data,UI}      23 features
        │
        ▼
LifeBoard/Persistence/          CoreData lives here and in feature Data/ only
        │
        ▼
LifeBoardDomain → LifeBoardUI → LifeBoardTokens → LifeBoardContracts
```

`LifeBoardDomain` builds independently as a package. That is the acceptance test
for the whole separation: if it stopped building alone, the layering would be
decorative.

### Where things live

| Layer | Holds | Never |
|---|---|---|
| `Features/<F>/Domain/` | models, use cases, services, ports | SwiftUI, UIKit, CoreData |
| `Features/<F>/Data/` | repositories, mappers | SwiftUI, another feature |
| `Features/<F>/UI/` | screens, sections, rows, stores | CoreData, the app router |
| `LifeBoard/Persistence/` | the Core Data stack, repositories, mappers | feature UI types |
| `LifeBoard/Shared/UI/` | chrome no single feature owns | feature models |
| `LifeBoard/App/` | composition roots | — |

Features never import other features. Cross-feature behavior goes through a
domain contract or App-tier coordination, and the App maps `AppRoute` onto each
feature's exported route factory — never the reverse.

## Naming

- No generational or phase prefix: `Sunrise`, `LifeOS`, `LB`, `PhaseII…VI` are gone
  from type names, and `LifeBoard` is dropped where it was redundant.
  675 types were renamed; `scripts/rename-manifest.tsv` is the record.
- One role per suffix: `…Repository` (port in `Domain/Ports/`, implementation in
  `Data/`), `…Store` (observable feature state), `…Service` (stateless
  operation), `…UseCase` (one user intent), `…Coordinator` (cross-feature, App
  tier only).
- Filename equals the file's primary exported type.

Names that could not be collapsed mechanically are listed in
`scripts/rename-collisions.tsv` with the reason — two different palettes cannot
both become `ColorTokens`, and that is a product decision, not a rename.

## Canonical task contracts

- Domain task model: `TaskDefinition`
- Read query contracts: `TaskReadQuery`, `TaskSliceResult`
- Read repository: `TaskReadModelRepositoryProtocol`
- Write repository: `TaskDefinitionRepositoryProtocol`
- View-layer alias: `DomainTask = TaskDefinition`

## Persistence

`TaskModelV3.xcdatamodeld`, 23 shipped versions, opened with lightweight
migration (`NSMigratePersistentStoresAutomaticallyOption` +
`NSInferMappingModelAutomaticallyOption`) across two configurations —
`CloudSync` and `LocalOnly` — one store each.

There are no hand-written mapping models. `CoreDataMigrationChainTests` is what
keeps that safe: it proves every shipped version can still infer a migration to
the current model, that data written at the oldest version survives the
migration, and that no entity sits outside a configuration the app opens.

`LifeBoardPersistence` is a directory rather than a package because eleven
entities use Core Data `class` codegen, and classes generated inside a package
are internal to it — the app would lose access to its own entity types. The
boundary is enforced instead by `check-module-boundaries.sh`, which bans
`import CoreData` outside `LifeBoard/Persistence/` and feature `Data/` folders.

- Store epoch key: `lifeboard.v3.store.epoch`
- CloudKit container: `iCloud.TaskerCloudKitV3`

## Local LLM / Eva

The local assistant architecture is documented in
`docs/architecture/LOCAL_LLM_EVA_ARCHITECTURE.md`.

Assistant-driven changes follow the same boundaries: UI routes intent, the
planner emits schema-validated commands, `AssistantActionPipelineUseCase`
validates and applies mutations, repositories persist. Chat and proposal UI
never write task state directly. Calendar and timeline projections may inform
answers, but external calendar events stay read-only.

## Guardrails

Thirteen scripts gate a change; run them before merge.

```bash
for s in check-accessibility-identifiers check-directory-shrapnel check-file-size-guardrails check-localization-keys check-module-boundaries check-no-print-logs check-swiftlint-baseline check-xcode-target-membership phase1-foundation-guardrails premium-ui-guardrails validate_coredata_codegen_guardrails validate_legacy_runtime_guardrails validate_legacy_test_guardrails; do bash "scripts/$s.sh" || echo "FAILED: $s"; done
```

Three of them are ratchets rather than pass/fail rules — file size, directory
shrapnel, and the SwiftLint token-law baseline. They record today's debt and
refuse to let it grow. Two invariants matter more than any individual check:

- **No change reduces guardrail coverage.** If a move takes files out of a
  scanned directory, the scanned set changes in the same commit. This is the
  failure mode most likely to pass unnoticed, because it leaves the build green
  and the numbers *improving*.
- **Exceptions are named, not patterned.** `scripts/module-boundary-exceptions.txt`
  keys on `<path>\t<import>`, so an entry excuses one import in one file and a
  second violation in the same file still fails.

Then the suite, run serially:

```bash
bash scripts/run-baseline-aware-tests.sh
```

A red result has three distinct shapes and they are not interchangeable: check
the `Executed N tests` line first. `runner hung before establishing connection`
with 0 executed is an environment problem, `crashed with signal` with 0 executed
is a launch crash, and only `Executed N tests, with M failures` is a real
failure.

## Debug builds and the stack

Debug compiles at `-Onone`, where a computed `some View` property is inlined
into its caller's frame. A screen whose sections are all computed properties
builds its entire view value in two frames and walks off the 1 MB main stack
during generic metadata instantiation — `EXC_BAD_ACCESS (code=2)`, top frame
`swift::SubstGenericParametersFromMetadata`. Release coalesces the slots, so
**a Release build proves nothing here**; the acceptance gate is a Debug launch.

The fix is that each `LazyVStack` child is a `struct: View`. When extracting
one, restate the parent's spacing inside it or the layout silently tightens, and
keep `LazyVStack` rather than `VStack` wherever the list is unbounded — swapping
it is a behavior change, not a restyle.

## Release and visual-system authority

`DESIGN.md` is the agent-readable visual contract; the token packages are the
runtime source of truth. `lifeOSUnifiedPresentationV2` remains a disable-only,
data-preserving diagnostic rollback; app and extension targets default to the
unified palette in Release.

Signed-device performance, paired Watch, App Group, migration, iCloud/account,
and accessibility-device checks cannot be closed by the simulator alone.

Product intent and screen behavior live in `docs/product/README.md`; global
interaction and responsive rules live in
`docs/design/LIFEBOARD_PRODUCT_UI_UX_GUIDE.md`. Architecture documents own
runtime composition, dependency direction, persistence, and trust boundaries.
