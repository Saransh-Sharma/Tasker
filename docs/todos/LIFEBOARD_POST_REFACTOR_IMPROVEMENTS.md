# LifeBoard Post-Refactor Improvements

This ledger contains only work that remains after the 2026-08-09 remediation checkpoint. It is deliberately separated into structural acceptance blockers and release/design follow-ups; an unchecked structural item is not being represented as complete elsewhere.

## Priority 0 — structural acceptance blockers

- [ ] Finish the `JournalFeature` boundary. Its currently excluded Journal models, adapters, reflection services, and App-coupled views must move to Domain/Persistence/Journal or receive closure-based dependencies before the app stops compiling them.
- [ ] Extract the remaining 19 feature products in the mandated order: Track, Plan, Weekly, DailyLoop, Tasks, Habits, Health, Nutrition, Wellness, Eva, Settings, Onboarding, Capture, Gamification, Sync, Insights, Focus, Projects, and Home. Move resources and tests with each target and require independent Debug/Release builds.
- [ ] Introduce the remaining public route/dependency/factory boundaries and one App-owned exhaustive `AppRouteFactory`. Knowledge and Journal have package route seams; Settings has the raw-value-safe rename and an App-compiled seam, but the full route matrix is not yet compiler-owned.
- [ ] Finish adopting the existing `LifeBoardPersistenceStack`, `LifeBoardRepositoryFactory`, and typed repository bundle. CompositionRoot and the headless App Intents path now use the package-owned factory, and no Persistence source is duplicated into the App target; AppDelegate, SceneDelegate, health runtime, onboarding, and feature Data adapters must still move away from direct containers.
- [ ] Remove the remaining production `CoreData` imports outside Persistence and feature `Data` directories. CompositionRoot is clean; current violations include AppDelegate, Eva App Shortcuts, GamificationEngine, and HealthSync files that have not yet crossed their final Data boundary.
- [ ] Remove every remaining feature reference to `AppRouter` and `CompositionRoot` through injected actions or Domain protocols. Onboarding, Home, Weekly, Journal, Settings, and Eva still contain transitional App-tier coupling.
- [ ] Add the non-product `LifeBoardTestingSupport` target and migrate package-owned tests. Preserve the 81-file ownership ledger and all 2,203 discovered hosted tests; keep only genuine App integration/hosting tests importing `LifeBoard`.
- [ ] Add the pinned compiler-index Release reachability job and its machine-readable retained-root classifications. No production source may be deleted until this proof exists.
- [ ] Run the complete route/capture/deep-link factory matrix and seeded compact-iPhone/iPad screenshot suite for light, dark, accessibility Dynamic Type, reduced motion, reduced transparency, and the combined profile.
- [ ] Only after every feature and all seven Xcode target families have compiler-derived membership proof, upgrade `objectVersion` 60 to 77 and adopt filesystem-synchronized groups with explicit exclusions. The watchOS 26.5 runtime is installed and Watch/Watch-widget Debug builds now work, but feature extraction is still a hard prerequisite.

## Priority 1 — quality acceptance

- [ ] Reduce the existing 349-item SwiftLint baseline to zero without changing visual output or frozen behavior.
- [ ] Add clean/incremental median-of-three performance baselines for every final product and enforce the 120% plus five-second regression rule.
- [ ] Remove the remaining Xcode/project diagnostics and make every acceptance build warning-free. Production and hosted-test source compilation is currently warning-free; the Watch scheme's deprecated manual-order setting was corrected during remediation.
- [ ] Replace platform-only simulator skips with matching macOS host jobs and keep the skip allowlist explicit. The two current hosted skips are macOS-only process/performance harness checks.

## Deliberate release and design follow-ups

- [ ] Complete signed-device, paired-Watch, App Group, CloudKit account/disabled-mode, physical accessibility, and real existing-store validation on suitable hardware/accounts.
- [ ] Consolidate semantic color, spacing, and typography vocabularies only as a separately approved visual-design project with snapshot review. Exact-value compatibility tokens introduced by remediation must remain behavior-neutral until then.
