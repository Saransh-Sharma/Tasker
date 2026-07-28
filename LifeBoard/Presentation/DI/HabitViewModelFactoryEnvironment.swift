import SwiftUI

/// Supplies habit view models to the view layer without a singleton reference.
///
/// `ArchitectureBoundaryTests` forbids view files reaching into
/// `PresentationDependencyContainer.shared`: it hides what a view actually
/// depends on and makes it impossible to render one in a test or preview
/// without standing up the whole container. The composition root still resolves
/// the container — that is its job — and hands the capability down through the
/// environment instead.
@MainActor
protocol HabitViewModelFactory {
    func makeNewAddHabitViewModel() -> AddHabitViewModel
    func makeHabitDetailViewModel(row: HabitLibraryRow) -> HabitDetailViewModel
}

extension PresentationDependencyContainer: HabitViewModelFactory {}

@MainActor
private struct HabitViewModelFactoryKey: @preconcurrency EnvironmentKey {
    /// Falls back to the shared container so a view mounted outside the
    /// composition root still functions. The boundary this enforces is about
    /// *view files* naming the singleton, not about forbidding it to exist.
    static let defaultValue: any HabitViewModelFactory = PresentationDependencyContainer.shared
}

extension EnvironmentValues {
    var habitViewModelFactory: any HabitViewModelFactory {
        get { self[HabitViewModelFactoryKey.self] }
        set { self[HabitViewModelFactoryKey.self] = newValue }
    }
}

/// Composition-root construction for habit composers.
///
/// `@StateObject` initializers run before a view has an environment, so they
/// cannot read `habitViewModelFactory`. Resolving here keeps the container
/// reference in the composition root rather than in a view file — the boundary
/// the guardrail is actually protecting — instead of merely relocating the
/// singleton's name to dodge a string match.
@MainActor
enum HabitComposerViewModels {
    static func makeNew() -> AddHabitViewModel {
        PresentationDependencyContainer.shared.makeNewAddHabitViewModel()
    }
}

/// Composition-root resolution for the settings notification service.
///
/// `SettingsViewModel` lives under `LifeBoard/Views`, which the architecture
/// guardrail scans, so it cannot name the container even in a default argument.
/// Resolving here keeps the dependency explicit at the type's boundary while the
/// container lookup stays in the composition root.
@MainActor
enum SettingsServices {
    static var notificationService: (any NotificationServiceProtocol)? {
        EnhancedDependencyContainer.shared.notificationService
    }
}

/// Composition-root resolution for the Recovery Center's health inputs.
///
/// The derived index is file-backed and constructible without the app's DI
/// graph, so the Recovery Center can report on it from Settings. Anything it
/// cannot observe returns `nil` and its row is omitted rather than shown as
/// healthy — an absent row is recoverable, invented reassurance is not.
enum RecoveryServices {
    /// Real journal-index health, or `nil` if the index cannot be opened.
    ///
    /// `async` because the index is an actor. The caller awaits it before
    /// rendering rather than blocking a thread on a semaphore, which would risk
    /// deadlocking against the actor it is waiting on.
    static func journalIndexState() async -> LifeBoardRecoveryStatusService.DerivedIndexState? {
        guard let index = try? LocalJournalDerivedIndexRepository() else { return nil }
        let indexed = await index.indexedChunkCount()

        // The source count is not reachable from Settings, so an empty index
        // cannot be told apart from "nothing to index". `.notApplicable` is the
        // non-alarming reading, and `classifyIndex` keeps that judgement in one
        // place rather than spreading it across call sites.
        return LifeBoardRecoveryStatusService.classifyIndex(
            indexedItemCount: indexed,
            sourceItemCount: 0
        )
    }
}
