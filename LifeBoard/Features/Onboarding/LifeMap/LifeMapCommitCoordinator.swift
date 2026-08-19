import Foundation
import LifeBoardDomain
import LifeBoardTokens
import SwiftUI

/// Write boundaries inside `LifeMapCommitCoordinator.commit`.
///
/// The area upsert and the capture write are naturally idempotent — they look
/// for an existing record by stable identity first. The working-hours, layout,
/// preference, and profile writes are not: they are unconditional overwrites
/// with no rollback, so replaying them after a mid-commit failure would clobber
/// state a merge-mode user already had. Recording the phase lets a retry pick up
/// where it stopped.
enum LifeMapCommitPhase: Int, Codable, Comparable {
    case notStarted
    case lifeAreasWritten
    case capacityWritten
    case layoutWritten
    case profileWritten
    case captureWritten

    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

@MainActor
final class LifeMapCommitCoordinator {
    struct Dependencies {
        var fetchLifeAreas: () async throws -> [LifeArea]
        var createLifeArea: (StarterLifeAreaTemplate) async throws -> LifeArea
        var updateLifeArea: (LifeArea) async throws -> LifeArea
        var fetchTask: (UUID) async throws -> TaskDefinition?
        var createTask: (CreateTaskDefinitionRequest) async throws -> TaskDefinition
        var fetchReflection: (UUID) async throws -> ReflectionNote?
        var saveReflection: (ReflectionNote) async throws -> ReflectionNote
        var saveWorkingHours: (WorkingHoursProfile) async throws -> Void
        var fetchHomeLayout: () async throws -> DashboardLayoutValue?
        var saveHomeLayout: (DashboardLayoutValue) async throws -> Void
    }

    private let dependencies: Dependencies
    private let stateStore: AppOnboardingStateStore
    private let profileStore: LifeMapProfileStore
    private let preferencesStore: WorkspacePreferencesStore

    init(
        dependencies: Dependencies,
        stateStore: AppOnboardingStateStore,
        profileStore: LifeMapProfileStore = .shared,
        preferencesStore: WorkspacePreferencesStore = .shared
    ) {
        self.dependencies = dependencies
        self.stateStore = stateStore
        self.profileStore = profileStore
        self.preferencesStore = preferencesStore
    }

    /// Upserts each canonical record using stable draft identities.
    ///
    /// Two properties make a retry safe. First, every write looks for an
    /// existing record by stable identity before creating one. Second, the
    /// draft carries a `commitPhase` so the non-idempotent writes — capacity,
    /// layout, profile — are skipped on a retry that already passed them.
    /// Completion is marked last, after every required write has succeeded, so
    /// a failure halfway through never leaves onboarding "done" with a
    /// half-built workspace.
    /// - Parameter onProgress: Called after each write boundary with the draft
    ///   as it stands. Without this the recorded `commitPhase` would die with
    ///   the thrown error and a retry would replay every non-idempotent write —
    ///   the phase would be bookkeeping that never bookkept anything.
    func commit(
        _ draft: LifeMapDraft,
        onProgress: ((LifeMapDraft) -> Void)? = nil
    ) async throws -> LifeMapDraft {
        var committed = draft
        let templates = draft.orderedLifeAreaTemplateIDs.compactMap { id in
            StarterWorkspaceCatalog.allLifeAreas.first { $0.id == id }
        }

        // Areas are always reconciled, even on retry: the upsert is idempotent
        // by name, and re-running it repairs a partial first attempt.
        var existing = try await dependencies.fetchLifeAreas()
        for (index, template) in templates.enumerated() {
            let normalized = Self.normalizedName(template.name)
            var area = existing.first { Self.normalizedName($0.name) == normalized }
            if area == nil {
                area = try await dependencies.createLifeArea(template)
                if let area { existing.append(area) }
            }
            guard var area else { continue }
            committed.resolvedLifeAreaIDsByTemplate[template.id] = area.id
            if area.sortOrder != index || area.isArchived {
                area.sortOrder = index
                area.isArchived = false
                area.updatedAt = Date()
                area = try await dependencies.updateLifeArea(area)
            }
        }
        committed.commitPhase = max(committed.commitPhase, .lifeAreasWritten)
        onProgress?(committed)

        if committed.commitPhase < .capacityWritten {
            // An established user who never opened the capacity step has not
            // asked for their week to be redefined.
            if draft.entryContext != .establishedWorkspace || draft.didEditDayShape {
                preferencesStore.update { $0.weekStartsOn = draft.dayShape.weekStartsOn }
                try await dependencies.saveWorkingHours(draft.dayShape.makeProfile())
            }
            committed.commitPhase = .capacityWritten
            onProgress?(committed)
        }

        if committed.commitPhase < .layoutWritten {
            try await dependencies.saveHomeLayout(try await resolvedLayout(for: draft))
            committed.commitPhase = .layoutWritten
            onProgress?(committed)
        }

        if committed.commitPhase < .profileWritten {
            let now = Date()
            let previousProfile = profileStore.load()
            profileStore.save(
                LifeMapProfile(
                    desiredChangeID: draft.desiredChange?.id ?? "",
                    frictionIDs: draft.frictionIDs,
                    createdAt: previousProfile?.createdAt ?? now,
                    updatedAt: now
                )
            )
            committed.commitPhase = .profileWritten
            onProgress?(committed)
        }

        if committed.commitPhase < .captureWritten {
            try await commitCapture(draft, templates: templates, resolved: committed.resolvedLifeAreaIDsByTemplate)
            committed.commitPhase = .captureWritten
            onProgress?(committed)
        }

        stateStore.markHandled(outcome: .completed)
        return committed
    }

    /// The Home layout to persist.
    ///
    /// A fresh workspace gets the recommended layout outright. An established
    /// one gets its existing layout with the newly chosen modules appended —
    /// overwriting would silently discard a Home the user already arranged,
    /// which is precisely what "merge mode" exists to prevent.
    private func resolvedLayout(for draft: LifeMapDraft) async throws -> DashboardLayoutValue {
        let recommended = OnboardingModuleCatalog.homePlacements(for: selectedModuleIDs(from: draft))
        guard draft.entryContext == .establishedWorkspace,
              let current = try await dependencies.fetchHomeLayout(),
              current.placements.isEmpty == false
        else {
            return DashboardLayoutValue(mode: .smart, isDefault: true, placements: recommended)
        }

        let presentKinds = Set(current.placements.map(\.widgetKind))
        let additions = recommended.filter { presentKinds.contains($0.widgetKind) == false }
        guard additions.isEmpty == false else { return current }

        var merged = current.placements
        var nextOrdinal = (merged.map(\.ordinal).max() ?? -1) + 1
        for addition in additions {
            merged.append(DashboardWidgetPlacementValue(
                widgetKind: addition.widgetKind,
                semanticSize: addition.semanticSize,
                ordinal: nextOrdinal
            ))
            nextOrdinal += 1
        }
        return DashboardLayoutValue(
            mode: current.mode,
            isDefault: current.isDefault,
            placements: HomeGridPackingService.normalized(merged)
        )
    }

    private func commitCapture(
        _ draft: LifeMapDraft,
        templates: [StarterLifeAreaTemplate],
        resolved: [String: UUID]
    ) async throws {
        guard let capture = draft.stagedCapture, capture.isReviewed else { return }

        if capture.kind == .task {
            guard try await dependencies.fetchTask(capture.id) == nil else { return }
            let lifeAreaID = capture.lifeAreaTemplateID.flatMap { resolved[$0] }
            _ = try await dependencies.createTask(
                CreateTaskDefinitionRequest(
                    id: capture.id,
                    title: capture.text,
                    projectID: ProjectConstants.inboxProjectID,
                    projectName: ProjectConstants.inboxProjectName,
                    lifeAreaID: lifeAreaID,
                    priority: .low,
                    type: .morning,
                    energy: .medium,
                    category: .general,
                    context: .anywhere,
                    planningBucket: .thisWeek
                )
            )
        } else {
            guard try await dependencies.fetchReflection(capture.id) == nil else { return }
            let areaName = capture.lifeAreaTemplateID.flatMap { id in
                templates.first(where: { $0.id == id })?.name
            }
            _ = try await dependencies.saveReflection(
                ReflectionNote(
                    id: capture.id,
                    kind: .freeform,
                    prompt: [capture.kind.title, areaName].compactMap { $0 }.joined(separator: " · "),
                    noteText: capture.text
                )
            )
        }
    }

    private func selectedModuleIDs(from draft: LifeMapDraft) -> Set<String> {
        if draft.moduleIDs.isEmpty == false { return Set(draft.moduleIDs) }
        return Set(draft.moduleGroupIDs.compactMap(LifeMapModuleGroup.init(rawValue:)).flatMap(\.moduleIDs))
    }

    private static func normalizedName(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
