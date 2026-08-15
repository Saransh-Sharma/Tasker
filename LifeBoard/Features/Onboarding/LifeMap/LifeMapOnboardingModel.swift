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

@MainActor
final class LifeMapOnboardingModel: ObservableObject {
    @Published private(set) var draft = LifeMapDraft()
    @Published var captureText = ""
    @Published var isResolvingCapture = false
    @Published var isCommitting = false
    @Published var errorMessage: String?
    @Published var permissionInFlight: PermissionKind?
    @Published var inspectedRoot: Destination?

    let feedback: OnboardingFeedbackController
    private let stateStore: AppOnboardingStateStore
    private let commitCoordinator: LifeMapCommitCoordinator
    private let universalInput = UniversalInputCoordinator()
    private let existingLifeAreas: () async throws -> [LifeArea]

    init(
        stateStore: AppOnboardingStateStore = .shared,
        commitCoordinator: LifeMapCommitCoordinator,
        feedback: OnboardingFeedbackController,
        existingLifeAreas: @escaping () async throws -> [LifeArea] = { [] }
    ) {
        self.stateStore = stateStore
        self.commitCoordinator = commitCoordinator
        self.feedback = feedback
        self.existingLifeAreas = existingLifeAreas
    }

    var step: LifeMapOnboardingStep { draft.step }

    var selectedAreaTemplates: [StarterLifeAreaTemplate] {
        draft.orderedLifeAreaTemplateIDs.compactMap { id in
            StarterWorkspaceCatalog.allLifeAreas.first { $0.id == id }
        }
    }

    var selectedModuleGroups: Set<LifeMapModuleGroup> {
        Set(draft.moduleGroupIDs.compactMap(LifeMapModuleGroup.init(rawValue:)))
    }

    var selectedModuleIDs: Set<String> {
        draft.moduleIDs.isEmpty ? Set(selectedModuleGroups.flatMap(\.moduleIDs)) : Set(draft.moduleIDs)
    }

    var requestablePermissions: [PermissionKind] {
        OnboardingModuleCatalog.requestablePermissions(for: selectedModuleIDs)
    }

    /// The layout the reveal step reads back. Derived from the same call the
    /// commit uses, so the preview cannot drift from what was persisted.
    var committedHomePlacements: [DashboardWidgetPlacementValue] {
        OnboardingModuleCatalog.homePlacements(for: selectedModuleIDs)
    }

    var sceneModel: LifeMapSceneModel {
        let nodes = selectedAreaTemplates.enumerated().map { index, template in
            LifeMapSceneNode(
                id: template.id,
                title: template.name,
                symbol: template.icon,
                colorHex: template.colorHex,
                kind: .lifeArea,
                emphasis: max(0.82, 1 - Double(index) * 0.045)
            )
        }
        return LifeMapSceneModel(
            lifeAreas: nodes,
            capacityFraction: LifeMapCapacity.fraction(for: draft.dayShape),
            centerPromise: draft.desiredChange?.title ?? "Daily Loop",
            captureTitle: draft.stagedCapture?.text
        )
    }

    func prepareForPresentation(
        snapshot: LifeMapDraft?,
        entryContext: OnboardingEntryContext = .freshFlow
    ) {
        if let snapshot, snapshot.schemaVersion == LifeMapDraft.currentSchemaVersion {
            draft = snapshot
            captureText = snapshot.stagedCapture?.text ?? ""
        } else {
            draft = LifeMapDraft()
            draft.entryContext = entryContext
        }
        recommendModules()
        persist()

        if draft.entryContext == .establishedWorkspace, draft.orderedLifeAreaTemplateIDs.isEmpty {
            Task { await preseedFromExistingWorkspace() }
        }
    }

    /// Merge mode: start from what the user already has.
    ///
    /// Without this, an established user's selections would append alongside
    /// their real areas and the commit would create near-duplicates ("Health"
    /// next to "Health & Self"). Matching through the catalog's alias table
    /// first means the commit upserts the records that already exist.
    private func preseedFromExistingWorkspace() async {
        guard let areas = try? await existingLifeAreas(), areas.isEmpty == false else { return }
        let active = areas.filter { $0.isArchived == false }

        // The catalog matches template -> existing area, so walk the templates
        // and keep the ones the user already has. Carrying each match's
        // `sortOrder` through preserves the order they arranged themselves
        // rather than imposing the catalog's.
        let matched = StarterWorkspaceCatalog.allLifeAreas.compactMap { template -> (id: String, order: Int)? in
            guard let area = StarterWorkspaceCatalog.matchingLifeArea(for: template, in: active) else { return nil }
            return (template.id, area.sortOrder)
        }
        guard matched.isEmpty == false else { return }

        draft.orderedLifeAreaTemplateIDs = matched
            .sorted { $0.order < $1.order }
            .map(\.id)
            .prefix(LifeMapDraft.maximumLifeAreas)
            .map { $0 }
        persist()
    }

    func selectDesiredChange(_ value: LifeMapDesiredChange) {
        draft.desiredChange = value
        recommendModules()
        feedback.medium()
        persist()
    }

    func toggleFriction(_ value: LifeMapFriction) {
        if let index = draft.frictionIDs.firstIndex(of: value.id) {
            draft.frictionIDs.remove(at: index)
        } else if draft.frictionIDs.count < LifeMapDraft.maximumFrictions {
            draft.frictionIDs.append(value.id)
        }
        feedback.selection()
        persist()
    }

    func toggleLifeArea(_ template: StarterLifeAreaTemplate) {
        if let index = draft.orderedLifeAreaTemplateIDs.firstIndex(of: template.id) {
            guard draft.orderedLifeAreaTemplateIDs.count > LifeMapDraft.minimumLifeAreas else { return }
            draft.orderedLifeAreaTemplateIDs.remove(at: index)
        } else if draft.orderedLifeAreaTemplateIDs.count < LifeMapDraft.maximumLifeAreas {
            draft.orderedLifeAreaTemplateIDs.append(template.id)
        }
        feedback.medium()
        persist()
    }

    func moveLifeArea(from source: Int, to destination: Int) {
        guard draft.orderedLifeAreaTemplateIDs.indices.contains(source) else { return }
        let bounded = min(max(0, destination), draft.orderedLifeAreaTemplateIDs.count - 1)
        guard source != bounded else { return }
        let value = draft.orderedLifeAreaTemplateIDs.remove(at: source)
        draft.orderedLifeAreaTemplateIDs.insert(value, at: bounded)
        feedback.selection()
        persist()
    }

    func updateDayShape(_ update: (inout OnboardingDayShapeDraft) -> Void) {
        update(&draft.dayShape)
        draft.didEditDayShape = true
        feedback.selection()
        persist()
    }

    func toggleModuleGroup(_ group: LifeMapModuleGroup) {
        if let index = draft.moduleGroupIDs.firstIndex(of: group.id) {
            draft.moduleGroupIDs.remove(at: index)
            draft.moduleIDs.removeAll { group.moduleIDs.contains($0) }
        } else {
            draft.moduleGroupIDs.append(group.id)
            draft.moduleIDs = Array(Set(draft.moduleIDs).union(group.moduleIDs)).sorted()
        }
        feedback.medium()
        persist()
    }

    func toggleModule(_ moduleID: String) {
        if let index = draft.moduleIDs.firstIndex(of: moduleID) {
            draft.moduleIDs.remove(at: index)
        } else {
            draft.moduleIDs.append(moduleID)
        }
        feedback.selection()
        persist()
    }

    func resolveCapture() async {
        let text = captureText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.isEmpty == false else { return }
        isResolvingCapture = true
        errorMessage = nil
        defer { isResolvingCapture = false }

        let resolution = await universalInput.resolve(LifeThreadIntentInput(text: text, destination: .home))
        let kind: LifeMapCaptureKind
        if case .captureDraft(let captureDraft) = resolution {
            switch captureDraft.kind {
            case .note: kind = .note
            case .journal: kind = .journal
            default: kind = .task
            }
        } else {
            // The resolver never returns nil — it falls back to `.answer` — so
            // this branch also covers "the model was unavailable and the
            // deterministic adapters did not claim it".
            kind = Self.localCaptureKind(for: text)
        }

        draft.stagedCapture = LifeMapStagedCapture(
            id: draft.stagedCapture?.id ?? UUID(),
            text: text,
            kind: kind,
            lifeAreaTemplateID: suggestedAreaID(for: text),
            isReviewed: false
        )
        draft.skippedCapture = false
        feedback.medium()
        persist()
    }

    func reviewCapture(kind: LifeMapCaptureKind, areaID: String?) {
        draft.stagedCapture?.kind = kind
        draft.stagedCapture?.lifeAreaTemplateID = areaID
        draft.stagedCapture?.isReviewed = true
        feedback.medium()
        persist()
    }

    func skipCapture() {
        draft.skippedCapture = true
        draft.stagedCapture = nil
        captureText = ""
        feedback.light()
        persist()
    }

    func advance() async -> Bool {
        errorMessage = nil
        switch step {
        case .welcome:
            setStep(.desiredChange)
        case .desiredChange:
            guard draft.desiredChange != nil else { return false }
            setStep(.friction)
        case .friction:
            guard draft.frictionIDs.isEmpty == false else { return false }
            setStep(.lifeAreas)
        case .lifeAreas:
            guard draft.isLifeAreaSelectionValid else { return false }
            setStep(.priorities)
        case .priorities:
            setStep(.capacity)
        case .capacity:
            setStep(.connections)
        case .connections:
            setStep(.capture)
        case .capture:
            guard draft.isCaptureResolved else { return false }
            await assemble()
        case .reveal:
            setStep(.permissionsPowerUp)
        case .permissionsPowerUp:
            setStep(.evaPowerUp)
        case .evaPowerUp:
            return true
        }
        return false
    }

    func goBack() {
        guard let index = LifeMapOnboardingStep.core.firstIndex(of: step), index > 0 else { return }
        setStep(LifeMapOnboardingStep.core[index - 1])
    }

    func requestPermission(_ kind: PermissionKind) async {
        guard permissionInFlight == nil else { return }
        permissionInFlight = kind
        defer { permissionInFlight = nil }
        await PermissionPrimingCoordinator.shared.performRequest(
            kind: kind,
            healthDomains: kind == .appleHealth
                ? OnboardingModuleCatalog.healthDomains(for: selectedModuleIDs) : []
        )
        if draft.permissionIDs.contains(kind.id) == false { draft.permissionIDs.append(kind.id) }
        persist()
    }

    func deferPermission(_ kind: PermissionKind) {
        PermissionPromptState.recordOnboardingDeferral(kind)
    }

    /// The transient assemble phase.
    ///
    /// On failure the draft stays on `.capture` with its snapshot intact and
    /// `commitPhase` recording how far it got, so the user can simply press the
    /// primary action again. Nothing is cleared until the commit reports success.
    private func assemble() async {
        isCommitting = true
        defer { isCommitting = false }
        let startedAt = Date()
        do {
            draft = try await commitCoordinator.commit(draft) { [weak self] partial in
                // Captured as it happens, so a failure two writes later still
                // leaves the completed phases recorded and the snapshot on disk.
                self?.draft = partial
                self?.persist()
            }
            await holdAssemblyFloor(since: startedAt)
            draft.step = .reveal
            // Cleared only here. The snapshot is the retry's memory, so it must
            // outlive every failure path and die only on success.
            stateStore.storeLifeMapJourney(nil)
            feedback.successSignature()
        } catch {
            // Stays on `.capture` with the snapshot and phase intact: pressing
            // the primary action again resumes rather than restarts.
            errorMessage = error.localizedDescription
            persist()
        }
    }

    /// Keeps the refraction sequence legible without ever exceeding the
    /// signature-moment budget. Under reduced motion there is no sequence to
    /// protect, so the overlay crossfades out immediately.
    private func holdAssemblyFloor(since startedAt: Date) async {
        guard MotionOverride.effectiveReduceMotion == false else { return }
        let elapsed = Date().timeIntervalSince(startedAt)
        let remaining = Self.assemblyFloor - elapsed
        guard remaining > 0 else { return }
        try? await Task.sleep(for: .seconds(remaining))
    }

    /// Below `DESIGN.md`'s 800 ms ceiling for signature moments, and long enough
    /// that the connection sequence reads as an event rather than a flicker.
    private static let assemblyFloor: TimeInterval = 0.62

    private func setStep(_ step: LifeMapOnboardingStep) {
        draft.step = step
        MotionDiagnosticsState.shared.record("onboarding:\(step)")
        feedback.light()
        persist()
    }

    private func recommendModules() {
        guard draft.moduleGroupIDs.isEmpty else { return }
        var groups: [LifeMapModuleGroup] = [.planFocus, .reflectionGrowth]
        if draft.desiredChange == .makeRoom || draft.desiredChange == .flexibleConsistency {
            groups.insert(.routinesHealth, at: 1)
        }
        groups.append(.eva)
        draft.moduleGroupIDs = groups.map(\.id)
        draft.moduleIDs = Array(Set(groups.flatMap(\.moduleIDs))).sorted()
    }

    private func persist() { stateStore.storeLifeMapJourney(draft) }

    private func suggestedAreaID(for text: String) -> String? {
        let lower = text.lowercased()
        return selectedAreaTemplates.first { template in
            lower.contains(template.name.lowercased()) || template.aliases.contains { lower.contains($0) }
        }?.id ?? selectedAreaTemplates.first?.id
    }

    private static func localCaptureKind(for text: String) -> LifeMapCaptureKind {
        let lower = text.lowercased()
        if lower.hasPrefix("note") || lower.contains("remember that") { return .note }
        if lower.hasPrefix("journal") || lower.contains("i feel") { return .journal }
        return .task
    }
}

/// Capacity as a single derivation.
///
/// Onboarding and the Life Management map previously computed this two
/// different ways — one from the draft, one from the persisted profile — and
/// disagreed about weekends. One function, one answer.
enum LifeMapCapacity {
    /// A notional full week of available hours. Not a target and never shown as
    /// one; it exists only to scale the arc.
    static let referenceWeeklyMinutes = 60 * 60

    static func fraction(for dayShape: OnboardingDayShapeDraft) -> Double {
        let weekdayMinutes = max(0, dayShape.weekdayEndMinute - dayShape.weekdayStartMinute) * 5
        let weekendMinutes = dayShape.worksWeekends
            ? max(0, dayShape.weekendEndMinute - dayShape.weekendStartMinute) * 2
            : 0
        return fraction(forTotalMinutes: weekdayMinutes + weekendMinutes)
    }

    static func fraction(forTotalMinutes minutes: Int) -> Double {
        min(1, max(0, Double(minutes) / Double(referenceWeeklyMinutes)))
    }
}
