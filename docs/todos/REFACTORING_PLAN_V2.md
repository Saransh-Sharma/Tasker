# LifeBoard Refactoring Plan v2 — staff review of the draft

Supersedes the draft "Final Refactoring Plan — LifeBoard". Every number below was measured
against the tree at `83222f0f`; where the draft's numbers were wrong I say so.

---

## Part 0 — What the audit actually found

### 0.1 Shape of the codebase

Production: **288,548 lines / 1,014 Swift files** in `LifeBoard/`. Tests: **68,526 / 81 files**
(`LifeBoardTests`) plus **17,437 / 43** (`LifeBoardUITests`). 2,403 commits. Working tree is
clean — the draft's "65-entry dirty tree" prerequisite is already settled.

| Directory | Files | LOC | LOC/file |
|---|---:|---:|---:|
| `Foundation/` | 83 | 81,169 | **978** |
| `Presentation/` | 286 | 47,336 | 165 |
| `View/` | 104 | 31,882 | 307 |
| `LLM/` | 101 | 31,660 | 313 |
| `UseCases/` | 39 | 19,224 | 493 |
| `State/` | 38 | 16,096 | 424 |
| `DesignSystem/` | 36 | 14,173 | 394 |
| `Domain/` | 84 | 12,281 | 146 |
| `Onboarding/` | 121 | 10,186 | 84 |
| `Views/` | 63 | 7,165 | 114 |
| `LifeBoardDesign/` | 34 | 6,313 | 186 |
| `ViewControllers/` | 8 | 2,113 | 264 |

### 0.2 The five things the draft misses

**(1) The pathology is bimodal, not "god files".** `Foundation/` averages 978 lines/file.
`Presentation/Home/Timeline/Surface/` is **97 files for 7,006 lines — 72 lines/file**;
`Presentation/Home/Modals/OverdueRescue/` is **45 files for 4,097 lines — 91 lines/file**.
The codebase simultaneously has god files *and* shrapnel. A bare 800-line ratchet only
pressures one end and actively rewards producing the other. The ratchet needs a companion
cohesion rule (§2.2).

**(2) Reference counting cannot tell "live" from "dead island", and the draft's dead list is
built on reference counting.** Three worked examples from the draft's own list:

- `SunriseTaskListView` (1,355 loc) — referenced by exactly two files, **both test files**.
  Production-dead, test-alive. Deleting it means deleting tests, which the draft's LOC budget
  never accounts for.
- `SunriseWeeklyPlannerView` (1,375 loc) — referenced by **`LifeOSFoundationShell.swift`**.
  It is *live*. The draft's Phase 1.4 ("Sunrise orphans in `View/`, ~10k lines") would delete it.
- `SunriseHabitDetailScreen` (1,157 loc) — referenced by `LifeManagementViewRoot` (live),
  by `SunriseHabitLibraryView` (same island), and by `ChatHostViewController` (which the draft
  correctly identifies as dead). Its liveness is *conditional on deletion order*.

The conclusion that matters: **the Sunrise generation is not a detachable block.** The Foundation
shell has absorbed parts of it. Any plan that treats `View/Sunrise*` as a unit is wrong.

`InsightsViewModel` is a second instructive case. The draft lists it as a single dead file.
It has 9 referencing files — but tracing them shows the *whole cluster* is dead:
`makeInsightsViewModel()` has no callers, `HomeStores.insightsViewModel` is declared and never
assigned, `SunriseInsightsHeaderView` has no consumers, `InsightsLaunchRequest` is never
constructed. So the draft's verdict is right and its unit of work is wrong: it is a 7-file
cluster (~3,000 loc), and deleting only the ViewModel leaves the rest orphaned.

**(3) Phases 1 and 3 break the gates the plan says every batch must pass.** The eight guardrails
are path-literal:

- `validate_coredata_codegen_guardrails.sh` hardcodes `LifeBoard/TaskModelV2.xcdatamodeld/...`
  — Phase 1.6 deletes that model.
- `validate_legacy_runtime_guardrails.sh` hardcodes `LifeBoard/Storyboards/Base.lproj/Main.storyboard`
  — Phase 1.1 deletes it.
- `premium-ui-guardrails.sh` names individual files (`LifeBoardTrackFoundationViews.swift`,
  `LifeBoardPhaseVIViews.swift`, `LBGlassCard.swift`) that Phase 4 splits.
- **`.swiftlint.yml` is the serious one.** All four token-law rules are scoped by
  `included:` regex to `LifeBoard/(View|Views|ViewControllers|Presentation/Views|LLM/Views)/`.
  Two consequences: (a) `Foundation/` — the 81k lines where the product actually lives — is
  *already unguarded today*; (b) Phase 3's move into `Features/` silently disables all four
  rules on everything, and the build stays green while it happens.

**(4) Decomposition has a crash driver, and it outranks the reorganization.** Debug builds at
`-Onone`; a SwiftUI screen whose sections are computed `some View` properties builds its whole
view value in two stack frames and walks off the 1 MB main stack during generic metadata
instantiation (`EXC_BAD_ACCESS code=2`, top frame `SubstGenericParametersFromMetadata`).
This already shipped as a launch crash in `LifeBoardTrackFoundationViews.swift` on 2026-08-05.
`LifeBoardPlanViews.swift` (4,116 loc, 23 top-level types) has the identical body shape and is
the next casualty. Phase 4 is not cosmetic and must not sit behind a move-only Phase 3.

**(5) Flags: the "off" branches are dead code that no build ever exercises.** `V2FeatureFlags`
carries **38 promoted-true staged flags** plus ~50 unstaged ones. `stagedFeatureEnabled` ends in:

```swift
#if DEBUG
return true          // every staged flag, unconditionally
#else
return promotedDefaults[key] ?? false
#endif
```

Debug — which is what the whole test suite runs under — takes every flag's `true` branch. So
every legacy branch behind a promoted flag is compiled, never executed, and never tested. The
draft says "delete the pinned-true flags". Deleting the flag is the small win; **deleting the
branch behind it is the actual line-count and the actual risk**. Also note `phase1ExecutionFlagshipEnabled`
is compound (`dailyLoop && taskProjectFlagship`) — retiring it requires retiring both halves.
And a critical tooling corollary: any dead-code scanner run in Debug will report every gated
branch as live. Dead-code analysis has to run on Release.

### 0.3 Claims verified as correct

- `Presentation/Home/Timeline/` is **103 files** ✓ (6 + 97 in `Surface/`) — though only 7,942 loc.
- `LifeOSFoundationShell.swift` is **6,985 loc / 44 top-level types** ✓.
- `LifeOSFoundationContracts.swift` is **3,095 loc / 123 top-level types** ✓ — the worst
  type-density in the tree.
- `LifeBoardTests.swift` is **17,218 loc** ✓.
- 15 files in `Domain/Interfaces/` are 2-line stubs (`// Canonical definitions are in V2RepositoryProtocols.swift`) ✓.
- `HomeTimelineViewModel`, `SunriseScheduleScreen`, `HomeiPadShell`, `ChatHostViewController`,
  `ColoredPillBackgroundView`, `HomeDailySummaryModalView` are each referenced by their own file
  only ✓ — genuinely dead, safe first batch.

### 0.4 Facts the draft omits entirely

- **`TaskModelV3.xcdatamodeld` carries 23 model versions.** The draft correctly rules schema
  changes out of scope but never names this as the top risk in the repo. There is no migration-chain
  test; add one before anything else moves (§1.4).
- **`LifeBoardThemeManager.shared` has 203 call sites** — 6.7× `PresentationDependencyContainer.shared`
  (30) and 15× `EnhancedDependencyContainer.shared` (13). Phase 5's "kill `.shared` locator calls"
  is aimed at the wrong singleton.
- **646 accessibility identifiers** back 43 UI-test files, including a 1,925-line `HomePage`
  page object. "a11y IDs preserved" is the right invariant; it needs to be a *gate*, not a promise.
- **904 localized string keys** in `Localizable.xcstrings`. Deleting views strands keys;
  nothing currently detects that.
- **The test-failure baseline file is empty (0 bytes)** while the tree is known to have ~5
  failing unit tests. `run-baseline-aware-tests.sh` therefore treats known failures as
  regressions and always exits non-zero. The gate is currently broken, not merely stale.
- **18 Swift files on disk are not in `project.pbxproj`** and sit on an allowlist whose own
  header says each "must be investigated and resolved". Among them: `InsightsViewModel+Presentation.swift`,
  `PulseModels.swift`, `LifeBoardMeshTokens.swift`, plus 12 test files that therefore never run.
- **`objectVersion = 60`.** The project predates Xcode 16 file-system-synchronized groups —
  which is directly relevant to Phase 3 (§3.3).

### 0.5 On the "25–35k dead lines" estimate

Do not commit to it. The named candidates roughly sum to that range, but at least one
1,375-line entry is live, an unknown fraction is test-only, and the estimate ignores the
legacy branches behind 38 flags (which are dead but not in the list). Replace the number with
a *measurement* (§1.2) and report the budget as three tiers: **provably unreferenced**,
**test-only-referenced**, **flag-shadowed**. Each tier has a different approval bar.

---

## Part 1 — Revised phase 0: make the ground safe (blocking; ~1 week)

The draft's Phase 0 is too thin. Nothing below is optional, because Phases 1–4 all depend on it.

**1.1 Repair the gates before using them.**
- Regenerate `scripts/lifeboard-test-failure-baseline.txt` from an actual clean-tree run.
  Commit the run's xcresult summary alongside it so the next person can tell "stale" from "empty".
- Convert every path literal in `scripts/*.sh` and `.swiftlint.yml` into a single sourced
  manifest (`scripts/lifeboard-paths.env`) — one place to update when Phase 3 moves files.
- **Extend the four token-law SwiftLint rules to `Foundation/`, `DesignSystem/`, `LifeBoardDesign/`,
  and `Onboarding/`.** Expect a large violation count; land it as `warning` first, ratchet the
  count down, flip to `error`. This is a real finding independent of the refactor: 81k lines of
  product UI are currently exempt from the design-token law.

**1.2 Build the reachability tool. This is the highest-leverage item in the whole plan.**
- `brew install periphery`; add `.periphery.yml` and `scripts/dead-code-report.sh`.
- **Run it against the Release configuration**, not Debug — otherwise all 38 flag-off branches
  read as live (§0.2.5).
- Seed retention with the real entry points: `AppDelegate`, `SceneDelegate`,
  `LifeBoardAppRouter.AppRoute` cases, `LifeOSFoundationShell`, widget/watch/share-extension
  roots, `@objc`/storyboard/Intents/AppShortcuts surfaces, and anything reached by string
  (`LifeBoardSpotlightRouteTranslator`).
- Emit three separate lists — unreferenced / test-only / flag-shadowed — and commit the report.
  This replaces the draft's hand-built list, which we've shown contains at least one live entry.
- Cross-check tier 1 with a link-level pass (`-dead_strip` map diff) on anything above 500 loc.

**1.3 Add the gates the invariants imply but don't have.**
- `scripts/check-accessibility-identifiers.sh` — snapshot the 646 IDs; any PR that removes one
  fails unless the diff also touches `LifeBoardUITests/`.
- `scripts/check-localization-orphans.sh` — flag `xcstrings` keys with zero code references.
- `scripts/file-size-guardrails.sh` — the draft's 800-line ratchet, **plus** a
  types-per-file ceiling (proposal: 12) and a *directory* rule (§2.2). Ratchet only: current
  values are the ceiling, no file may grow past its recorded size.

**1.4 Add a Core Data migration-chain test** — open a fixture store at each of the 23 model
versions and migrate to head. This is the only thing standing between a file move and data loss,
and it does not exist today.

**1.5 Free wins, no risk.** Resolve all 18 allowlisted non-project files (wire in or delete;
12 are tests that have never run). `.gitignore` `DerivedData*/`; delete the five local
`DerivedData*` dirs and `build/`; untrack `.DS_Store`.

**Exit criteria:** all 8 guardrails + the 3 new ones green on an unmodified tree; dead-code
report committed; migration test green.

---

## Part 2 — Reordered phases

The draft runs 1 → 2 → 3 → 4 → 5. That order is wrong in two places.

### 2.1 The new order and why

| # | Phase | Why here |
|---|---|---|
| **A** | Generation-boundary inventory | Cheap, and it determines whether Phase 1 or Phase 2 items are even safe. |
| **B** | Crash-risk decomposition (was Phase 4, partial) | `LifeBoardPlanViews.swift` is a known-imminent launch crash. Nothing outranks that. |
| **C** | Dead code, tier 1 only (was Phase 1) | Now driven by the tool, not the hand list. |
| **D** | Flag retirement + legacy-branch deletion (was Phase 2) | Deleting branches converts tier-3 into tier-1; re-run the tool after. |
| **E** | Dead code, tiers 2–3 (rest of Phase 1) | Only now is the true set visible. |
| **F** | Remaining god-file decomposition (rest of Phase 4) | Decompose *before* moving: a split file is easier to place than a 7k-line one. |
| **G** | Feature-first reorganization (was Phase 3) | Last, when there is 30% less code to move. |
| **H** | Convergence + modularization (was Phase 5) | Unchanged, but see §4. |

The two swaps: **decompose before you move** (moving a 6,985-line file to a new directory
achieves nothing; splitting it first means Phase G is placing coherent units), and
**retire the generation before finishing the dead sweep** (the Sunrise layer only looks
half-alive because the shell still calls into it).

### 2.2 Phase A — generation-boundary inventory (new, ~2 days)

Produce one document: every call edge from `Foundation/` into `View/`, `Views/`,
`ViewControllers/`, `LifeBoardDesign/`, and `Presentation/`. For each edge, one of three verdicts:

- **Absorbed** — Foundation depends on it; it is not legacy, it is Foundation's now, and it
  moves to a `Features/` home in Phase G. (`SunriseWeeklyPlannerView` is here.)
- **Bridged** — Foundation reaches it through a flag or a rollback route; it dies in Phase D.
- **Orphaned** — no Foundation edge; it dies in Phase C/E.

Without this, "retire the previous generation" has no definition and every deletion is a coin flip.

### 2.3 The size rules (Phase B/F ceiling, replacing the bare 800-line ratchet)

Three limits, all ratchets:

1. **≤ 800 lines/file** — the draft's rule, kept.
2. **≤ 12 top-level types/file** — catches `LifeOSFoundationContracts.swift` (123 types in
   3,095 lines: it passes a per-type line check and is still the least navigable file in the repo).
3. **A directory of ≥ 20 files must average ≥ 150 lines/file** — the anti-shrapnel floor.
   `Timeline/Surface/` (72) and `OverdueRescue/` (91) both fail today; record them as the
   ceiling and require consolidation before either grows.

Rule 3 is what stops Phase F from converting a god-file problem into a 400-file problem.

### 2.4 Phase B — crash-risk decomposition, sequenced by risk not size

Order by "does `body` build the whole screen in two frames", not by line count:

1. `LifeBoardPlanViews.swift` (4,116 / 23 types) — named next-to-break.
2. `LifeOSFoundationShell.swift` (6,985 / 44 types) — 30+ private route views in one file.
3. `LifeBoardTrackAndJournalViews.swift` (6,448 / 45 types).
4. `LifeBoardPhaseVIViews.swift` (1,897 / 26 types).
5. `LifeBoardFoundationGallery.swift` (4,560 / 25 types).

Apply the established method verbatim: every section becomes a `struct: View`; one struct per
`LazyVStack` child; restate `LazyVStack` spacing inside each extracted struct; shared
derivations into a `@MainActor private enum`. Each split gets a Debug launch on device/simulator
as its acceptance test — the crash only reproduces at `-Onone`, so a Release build proves nothing.

### 2.5 Phase D — flag retirement, done properly

Write the policy down first, in `docs/architecture/`:

> A staged flag is retired when it has been promoted-true for ≥ 2 releases with no rollback.
> Retirement is a single PR that deletes: the flag accessor, its `promotedDefaults` entry, its
> launch-argument branch, **the `else` branch at every call site**, and any rollback route that
> exists only to serve it. A flag may not be deleted while any call site still has a live
> `else` branch that another flag can reach.

Then retire in dependency order: leaves first, compounds
(`phase1ExecutionFlagshipEnabled`) last. Re-run the Release dead-code report after each batch —
that is where a large share of the real deletion budget is, and it is invisible until the flags go.

One behavioral note to preserve: the `#if DEBUG return true` fallthrough means retiring a flag
changes nothing in Debug but *can* change Release for any flag not in `promotedDefaults`.
Diff `promotedDefaults` against the accessor list before each batch; today three flags
(`remindersSync`, `autoTaskIcons`, and the `iPadPerf*` family) use a different mechanism entirely
and must not be swept in.

---

## Part 3 — Phase G: the reorganization, with the mechanics fixed

The draft's target tree is good and I would keep it as written. Three mechanical corrections.

### 3.1 Sequence guard

Phase G may not start until: dead-code tiers 1–3 are deleted, Phase B/F splits have landed,
and the path manifest from §1.1 is in place. Moving first inflates every subsequent diff.

### 3.2 The `Foundation/PhaseII…PhaseVI` dissolution needs a rule, not a mapping

The draft's mapping (PhaseII→Journal/Knowledge, III→Plan/Inbox/DailyLoop, …) is right in spirit,
but `PhaseIII/` alone is 25 files / 21,731 lines spanning Plan, Inbox, task execution, weekly
planning, and the day-loop ledger. State the rule instead: **a file goes to the feature that owns
the entity it mutates.** Files that mutate no entity (contracts, models) go to `Core/Domain/`.
`LifeOSFoundationContracts.swift` (123 types) must be split by owning feature *before* it moves,
or it becomes a 123-type import cycle across 18 feature directories.

### 3.3 Consider upgrading `objectVersion` first — with eyes open

The project is at `objectVersion = 60`. Xcode 16's `PBXFileSystemSynchronizedRootGroup` would
make Phase G nearly free: `git mv` with **zero `project.pbxproj` churn**, which removes the
guaranteed merge-conflict hotspot from a phase that is otherwise dozens of PRs all editing the
same 6,993-line file.

The tradeoff is real, so decide deliberately: synchronized groups make target membership
*implicit* (folder-based, with an exceptions list). That invalidates
`check-xcode-target-membership.sh` as written and creates a new failure mode — a stray file in
the wrong folder silently joins the app target. If you take the upgrade, rewrite that guardrail
to assert on the resolved membership from `xcodebuild -showBuildSettings` rather than on
`project.pbxproj` text.

Recommendation: **take the upgrade, before Phase G, as its own PR**, and budget a day to
rewrite the membership guardrail. The alternative is serializing a merge train for every
move PR, which costs more.

### 3.4 PR sizing

The draft's "≤ 1k-line move-only PRs" is right for review, but with pbxproj churn (if §3.3 is
declined) the binding constraint is conflicts, not review load. In that case: one feature
directory per PR, merged strictly serially, `git mv` only, `--find-renames` verified at 100%
similarity, and a CI check asserting the diff contains **zero content changes** outside
`project.pbxproj` and import lines.

---

## Part 4 — Phase H: convergence, re-scoped

- **`LifeBoardThemeManager.shared` (203 sites) is the real singleton problem**, not the DI
  containers. Treat it separately: it is a theming read path, so the fix is an
  `@Environment` value threaded from the root, not constructor injection. Do it after Phase G
  when the feature boundaries exist to thread it along.
- The two DI containers (`PresentationDependencyContainer`, `EnhancedDependencyContainer`,
  43 sites combined) merge into one composition root — as drafted.
- **The `Domain/Mappers` vs `State/Mappers` duplication is not an inversion.** `Domain/` imports
  no CoreData and references no `NSManagedObject` anywhere — the layering is actually clean.
  There are simply two parallel 7-file mapper sets (`TaskDefinitionMapper` /
  `StateTaskDefinitionMapper`, etc.). Diff them; one set is almost certainly the previous
  generation. Reclassify this as a Phase D/E item, not an architecture fix.
- The 15 two-line `Domain/Interfaces` stubs: delete, and move the real definitions out of
  `V2RepositoryProtocols.swift` (482 loc, 24 protocols) into one file per protocol. Doing only
  the first half leaves the god-file.
- Archive the 32 stale `docs/todos/` — but first grep them for the guardrail *rationales*;
  several encode why a check exists, and the checks outlive the todo.

### On SPM modularization

The draft says "evaluate". Be more definite: **feature-first directories without compiler-enforced
boundaries decay back within a year** — that is how this codebase got here. `JournalKit` already
exists as a cross-repo SPM package and is the working precedent. Commit now to extracting, in
this order, once Phase G lands: `Core/Domain` → `DesignSystem` → `Core/Persistence` → one pilot
feature. Each extraction that compiles is a proof that the boundary is real. If `Core/Domain`
cannot be extracted, the reorganization did not actually separate anything and should be treated
as unfinished.

---

## Part 5 — Invariants and risk register

Carried from the draft, unchanged and correct:
- No `TaskModelV3` schema changes; no receipt/Undo semantics changes.
- Move-only PRs never carry behavior changes.
- Type names and accessibility identifiers preserved across moves.

Added:
- **No PR may reduce guardrail coverage.** If a move takes files out of a SwiftLint `included:`
  regex, the regex changes in the same PR. This is the failure mode most likely to go unnoticed,
  because it leaves the build green.
- **Dead-code analysis runs on Release only** (Debug forces all 38 flags true).
- **Debug-launch smoke test on device is the acceptance test for every view split** — the
  `-Onone` stack crash does not reproduce in Release.
- **Test deletion is an explicit, itemized decision**, never a side effect. Tier-2 (test-only)
  deletions list the tests being deleted in the PR description.

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Core Data 23-version migration chain breaks | Low | **Catastrophic** (user data) | §1.4 migration test, before anything moves |
| Guardrail silently disabled by a move | **High** | High (regressions ship) | §1.1 path manifest + §5 invariant |
| A "dead" type is live via the shell | **High** | Medium (build break, caught in CI) | §2.2 boundary inventory + Release Periphery |
| pbxproj merge conflicts stall Phase G | **High** | Medium (schedule) | §3.3 objectVersion upgrade, or serial merge train |
| `-Onone` launch crash ships in a Debug build | Medium | High | §2.4 ordering, device smoke per split |
| a11y ID drift breaks 43 UI-test files | Medium | Medium | §1.3 identifier snapshot gate |

---

## Part 6 — Sequencing summary

| Phase | Content | Blocking? | Rough size |
|---|---|---|---|
| 0 | Gates repaired, Periphery, a11y/l10n/size guardrails, migration test, 18 orphan files | **yes** | ~1 week |
| A | Generation-boundary inventory | **yes** | ~2 days |
| B | Crash-risk view decomposition (5 files) | no | ~1 week |
| C | Dead code tier 1 (provably unreferenced) | no | batched |
| D | Flag retirement + legacy-branch deletion | no | batched, largest unknown |
| E | Dead code tiers 2–3, re-measured | no | batched |
| F | Remaining god-file decomposition | no | batched |
| G | Feature-first reorganization (`objectVersion` upgrade first) | no | 1 feature/PR |
| H | Composition root, theming, mapper dedup, SPM extraction | no | ongoing |

The draft's Phases 1–5 are all still in here. What changed is the order, the method for
producing the dead list, and the recognition that Phase 0 has to build the gates before
Phases 1–4 are allowed to lean on them.
