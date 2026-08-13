# LifeBoard iOS — Current Architecture

> Classification: Canonical architecture reference
> Audience: Engineering, architecture, QA, and release teams
> Capability status: Current working tree; transitional boundaries are explicit
> Source authority: Root Package.swift, Xcode targets, runtime composition, persistence model
> Last verified: 2026-08-13

**iOS 26.0+ | Swift 6 | TaskDefinition-first runtime**

LifeBoard is V2-only for task-domain and runtime flows. The application still
contains most feature implementation and orchestration in the `LifeBoard`
Xcode target. Package extraction currently exposes nine products declared in
the repository-root `Package.swift`.

## Implemented module graph

```text
LifeBoard app / extensions / hosted tests
├── JournalFeature ─────────────────→ Persistence, UI, Domain, Transcription
├── KnowledgeFeature ───────────────→ Persistence, UI, Domain
├── LifeBoardTranscription ─────────→ LifeBoardContracts
├── LifeBoardCalendar ───────────────→ UI, Tokens, Domain, Contracts
├── LifeBoardPersistence ────────────→ LifeBoardDomain, LifeBoardContracts
├── LifeBoardUI ─────────────────────→ LifeBoardTokens, LifeBoardContracts
├── LifeBoardTokens ─────────────────→ LifeBoardContracts
├── LifeBoardDomain ─────────────────→ LifeBoardContracts
└── LifeBoardContracts
```

All nine products are declared by one in-repository manifest. The manifest is
the package-product authority and the dependency graph is acyclic.

`LifeBoardPersistence` currently owns the shipped model resource, the explicit
model/container API, and the managed-object classes needed to load that model.
Its cache, integrity, mapper, repository, service, sync, and bootstrap-service
implementation directories remain app-owned and are explicitly excluded from
the package target. This is a transitional boundary, not a completed
persistence extraction.

`LifeBoardCalendar` owns shared EventKit repositories and calendar
computation/merge support. `LifeBoardTranscription` owns shared SpeechAnalyzer
contracts/runtime. `KnowledgeFeature` and `JournalFeature` are the first
feature-level package products; their manifest source/exclusion lists define
the exact extracted boundary rather than implying the entire app feature tree
has moved.

## Feature ownership

The source tree uses feature-oriented directories under
`LifeBoard/Features/<Feature>/{Domain,Data,UI}`, and Inbox code has been folded
into `Features/Plan`. These directories improve ownership and are checked by a
syntax-aware declared-adjacency gate, but they are **not SwiftPM targets**. The
compiler still builds the approved feature set as part of the `LifeBoard` app
module.

Consequences of that transitional state:

- a feature directory can still reference another feature without an actual
  compiler target edge;
- `AppRoute`, `AppRouter`, and destination construction remain App-owned;
- uniform public `<Feature>Route`, `<Feature>Dependencies`, and
  `<Feature>RouteFactory` APIs have not been introduced;
- the remaining tests that use `@testable import LifeBoard` are app integration
  tests, not package-specific unit tests.

Empty facade targets do not count as extraction; a feature boundary is claimed
only for the sources and resources actually declared in `Package.swift` and
verified by package/app builds.

## Layer responsibilities

| Layer | Current responsibility | Boundary |
|---|---|---|
| `LifeBoardContracts` | dependency-light shared contracts | imports no internal module |
| `LifeBoardTokens` | semantic design tokens | Contracts only |
| `LifeBoardUI` | feature-neutral reusable UI | Contracts and Tokens only |
| `LifeBoardDomain` | shared domain models and protocols | Contracts only |
| `LifeBoardPersistence` | packaged model and model-loading API | Contracts and Domain only |
| `LifeBoardCalendar` | shared EventKit/calendar adapters | Domain only |
| `LifeBoardTranscription` | shared SpeechAnalyzer runtime and contracts | Contracts only |
| `KnowledgeFeature` | extracted Knowledge feature sources/resources | Contracts, Domain, Persistence, Tokens, UI |
| `JournalFeature` | extracted Journal route/security/search/mood sources | Contracts, Domain, Persistence, Tokens, UI, Transcription |
| `LifeBoard/Features` | feature code, presently app-compiled | no new feature-to-feature/App coupling |
| `LifeBoard/App` and `Foundation/Navigation` | composition and App routing | may compose all lower layers |

The declared adjacency graph lives in `scripts/module-adjacency.tsv`. The
checker parses imports using the Swift compiler's syntax tree and scans app and
package sources. Its feature rows express the target graph to be enforced as
files cross package boundaries; they do not claim those package targets exist.

## Persistence

`TaskModelV3.xcdatamodeld` is a processed resource of
`LifeBoardPersistence`. `LifeBoardPersistenceModel` resolves the compiled model
from `Bundle.module` and exports `modelURL`, `makeModel()`,
`makeCloudKitContainer`, and `makeContainer`. Application bootstrap passes the
explicit model to `NSPersistentCloudKitContainer(name:managedObjectModel:)`.

All 23 shipped model versions remain present. The 11 formerly Class Definition
entities use Manual/None generation and public managed-object subclasses with
their existing Objective-C names. Entity names, attributes, configurations,
version identifiers, model checksums, store locations, migration options, and
CloudKit identifier are preserved.

- store epoch key: `lifeboard.v3.store.epoch`
- CloudKit container: `iCloud.TaskerCloudKitV3`
- configurations: `CloudSync` and `LocalOnly`

Migration and compatibility tests must load the packaged model through
`LifeBoardPersistenceModel`; `Bundle.main` is not the resource authority.

## Naming

The collision campaign gives independently meaningful names to the semantic
and clay token families. Repository/source/factory suffixes describe the role;
`Provider` remains only where Apple protocols require that vocabulary. Exact
old-to-new mappings are recorded in `scripts/rename-manifest.tsv`, and collision
decisions in `scripts/rename-collisions.tsv`.

Renames apply to Swift symbols and matching primary filenames. Persisted values,
localization keys, accessibility identifiers, UserDefaults keys, CodingKeys,
raw values, entity names, filenames shared through App Groups, and deep-link
paths are frozen and are not rewritten as part of naming cleanup.

## Guardrails

Run the structural suite from the repository root:

```bash
for gate in \
  check-accessibility-identifiers \
  check-directory-shrapnel \
  check-file-size-guardrails \
  check-frozen-contracts \
  check-localization-keys \
  check-module-boundaries \
  check-no-print-logs \
  check-swiftlint-baseline \
  check-xcode-target-membership \
  phase1-foundation-guardrails \
  premium-ui-guardrails \
  validate_coredata_codegen_guardrails \
  validate_legacy_runtime_guardrails \
  validate_legacy_test_guardrails
do
  bash "scripts/$gate.sh"
done
```

Missing required inputs are failures. Localization is aggregated across app and
package catalogs. File-size, directory, accessibility, frozen-contract, and
SwiftLint checks scan package-owned sources/resources as well as app sources.
Target membership is derived from Xcode-generated Swift file lists, rather than
PBX text. It therefore requires every relevant SDK/runtime to be installed.

The object version remains 60 and groups remain explicitly represented in the
PBX project until compilation-derived membership passes for app, tests,
extensions, Watch, and Watch widgets. The filesystem-synchronized-group upgrade
is conditional on that proof.

## Verification policy

- Build every package product in Debug and Release.
- Use isolated DerivedData and serialized simulator builds/tests.
- Retain `.xcresult` bundles for the full unit suite, persistence/migration
  focus, and UI smoke tests.
- Treat a missing SDK/runtime as unresolved infrastructure, not a passing gate.
- Preserve the exact localization and frozen-contract snapshots.
- Do not infer production unreachability from text references alone; retain app,
  routes, extensions, Watch, Objective-C/storyboard, intent, and string-reached
  roots.

Signed-device performance, paired Watch, App Group, CloudKit/account, and
physical-device accessibility validation remain release checks that a simulator
cannot close.
