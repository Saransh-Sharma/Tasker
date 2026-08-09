# LifeBoard Post-Refactor Improvements

These items are intentionally non-blocking for the structural refactor. They must not be mixed into move/extraction work when doing so could alter behavior, persistence, accessibility, localization, deep links, defaults, or visual appearance.

## Priority 0 — incomplete structural acceptance

- [ ] Extract the approved 21 feature products, in dependency order and with Home last; move each feature's sources, resources, and tests together and require independent Debug/Release builds.
- [ ] Introduce each routed target's public `<Feature>Route`, `<Feature>Dependencies`, and `@MainActor <Feature>RouteFactory`; keep `AppRoute` mapping and cross-feature orchestration in the App tier.
- [ ] Finish `LifeBoardPersistence` extraction. Cache, integrity, mappers, repositories, services, sync, and the bootstrap service are still excluded from the package target.
- [ ] Migrate the 81 remaining `@testable import LifeBoard` files into owning package tests where possible; retain genuinely cross-module cases as app integration tests.
- [ ] Install the watchOS 26.5 runtime and prove compilation-derived membership for the Watch app and Watch widgets.
- [ ] Only after all membership targets pass, upgrade project object version 60 to 77 and adopt filesystem-synchronized groups with explicit target exclusions.
- [ ] Run the complete route matrix and seeded compact-iPhone/iPad UI/screenshot suite in light/dark, Dynamic Type, reduced motion, and reduced transparency configurations.
- [ ] Complete paired-Watch, signed-device, App Group, CloudKit-disabled/account, and existing-store compatibility validation on suitable hardware.

## Priority 1 — correctness and maintainability debt

- [ ] Reduce the 349-item SwiftLint baseline monotonically, prioritizing correctness and concurrency rules before style-only findings.
- [ ] Resolve compiler warnings, including the Insights retroactive `Equatable` conformance and deprecated SwiftUI `Text + Text` composition.
- [ ] Add performance budgets and timing evidence for the largest independently compiled feature targets.
- [ ] Add a repeatable Release reachability job with retained roots and machine-readable production-unreferenced, test-only, and flag-shadowed reports.

## Priority 2 — design-system convergence

- [ ] Evaluate semantic consolidation of the existing color vocabularies as a product/design project with visual regression approval.
- [ ] Evaluate spacing and typography vocabulary consolidation after screenshots establish an intentional visual baseline.
- [ ] Reduce app-owned compatibility shims only after every consumer imports its owning product directly.
- [ ] Audit package-owned resource loading for caching, memory pressure, and localization fallback behavior.

## Priority 3 — quality and polish

- [ ] Expand compact-phone and iPad screenshot coverage beyond route roots to critical empty, loading, error, and destructive states.
- [ ] Add more VoiceOver traversal and Switch Control UI tests after the frozen identifier migration is stable.
- [ ] Profile Dynamic Type, reduced motion, and reduced transparency paths on physical devices.
- [ ] Ratchet directory shrapnel and top-level-type limits downward after module ownership settles.
- [ ] Profile incremental and clean build times and tune target boundaries where compile fan-out is disproportionate.
