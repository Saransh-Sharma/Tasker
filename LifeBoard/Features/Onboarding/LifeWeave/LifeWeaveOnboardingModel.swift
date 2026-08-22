import Foundation
import LifeBoardDomain
import LifeBoardTokens
import SwiftUI

@MainActor
final class LifeWeaveOnboardingModel: ObservableObject {
    @Published private(set) var draft = LifeWeaveDraft()
    @Published var captureText = ""
    @Published var isResolvingCapture = false
    /// Set when the resolver could not honestly claim a destination, so the
    /// review card shows the chooser instead of a confident answer.
    @Published var isCaptureAmbiguous = false
    @Published var isCommitting = false
    @Published var errorMessage: String?
    @Published private(set) var openingPrompts: [EvaStarterPrompt] = []

    let feedback: OnboardingFeedbackController
    private let stateStore: AppOnboardingStateStore
    private let commitCoordinator: LifeMapCommitCoordinator
    private let existingLifeAreas: () async throws -> [LifeArea]
    /// Same construction as the shell's: the deterministic adapters plus the
    /// semantic one, so a sentence classifies identically here and in the
    /// composer the user meets a minute later.
    let universalInput = UniversalInputCoordinator()
    let powerUps: LifeMapPowerUpDependencies

    init(
        stateStore: AppOnboardingStateStore = .shared,
        commitCoordinator: LifeMapCommitCoordinator,
        feedback: OnboardingFeedbackController,
        existingLifeAreas: @escaping () async throws -> [LifeArea] = { [] },
        powerUps: LifeMapPowerUpDependencies = LifeMapPowerUpDependencies()
    ) {
        self.stateStore = stateStore
        self.commitCoordinator = commitCoordinator
        self.feedback = feedback
        self.existingLifeAreas = existingLifeAreas
        self.powerUps = powerUps
    }

    var step: LifeWeaveStep { draft.step }

    var selectedAreaTemplates: [StarterLifeAreaTemplate] {
        draft.orderedLifeAreaTemplateIDs.compactMap { id in
            StarterWorkspaceCatalog.allLifeAreas.first { $0.id == id }
        }
    }

    /// Derived, never asked. See `OnboardingModuleCatalog.recommendedModuleIDs`.
    var recommendedModuleIDs: Set<String> {
        OnboardingModuleCatalog.recommendedModuleIDs(
            intent: draft.intent,
            lifeAreaTemplateIDs: draft.orderedLifeAreaTemplateIDs
        )
    }

    var requestablePermissions: [PermissionKind] {
        OnboardingModuleCatalog.requestablePermissions(for: recommendedModuleIDs)
    }

    /// The layout the reveal reads back — the same call the commit makes, so the
    /// receipt cannot describe a Home that was not persisted.
    var committedHomePlacements: [DashboardWidgetPlacementValue] {
        OnboardingModuleCatalog.homePlacements(for: recommendedModuleIDs)
    }

    // MARK: - Presentation

    /// Restores a journey, translating a v5 one if that is what is on disk.
    ///
    /// Three inputs, in priority order: a v6 snapshot at the current schema, a
    /// v5 snapshot to migrate, or nothing. The middle case is the one that
    /// matters — flipping the flag mid-rollout must not throw away the four
    /// answers somebody already gave.
    func prepareForPresentation(
        snapshot: LifeWeaveDraft?,
        legacySnapshot: LifeMapDraft?,
        entryContext: OnboardingEntryContext = .freshFlow
    ) {
        if let snapshot, snapshot.schemaVersion == LifeWeaveDraft.currentSchemaVersion {
            draft = snapshot
        } else if let snapshot, (8..<LifeWeaveDraft.currentSchemaVersion).contains(snapshot.schemaVersion) {
            draft = LifeWeaveMigration.draft(fromEarlierSchema: snapshot)
        } else if let legacySnapshot, legacySnapshot.schemaVersion == LifeMapDraft.currentSchemaVersion {
            draft = LifeWeaveMigration.draft(fromV5: legacySnapshot)
            // The v5 snapshot is left on disk deliberately. Turning the flag back
            // off has to find the journey where its owner left it, and the commit
            // clears both together on success.
            logOnboardingInfo(
                event: "onboarding_migrated",
                message: "Migrated an interrupted v5 journey into the v6 flow",
                fields: ["step": draft.step.identifierSuffix]
            )
        } else {
            draft = LifeWeaveDraft()
            draft.entryContext = entryContext
            draft.lifecyclePhase = .editing
        }
        draft.lifecyclePhase = draft.resolvedLifecyclePhase
        if draft.lifecyclePhase == .revealReady { draft.step = .reveal }
        captureText = draft.stagedCapture?.text ?? ""
        persist()
        Task {
            await ProductTelemetry.shared.record(
                draft.entryContext == .establishedWorkspace ? .refreshPresented : .onboardingPresented,
                flowVersion: AppOnboardingState.currentVersion,
                audience: draft.entryContext == .establishedWorkspace ? "existing" : "fresh"
            )
            await ProductTelemetry.shared.record(
                .onboardingStepViewed,
                flowVersion: AppOnboardingState.currentVersion,
                outcome: draft.step.identifierSuffix
            )
        }

        if draft.entryContext == .establishedWorkspace, draft.orderedLifeAreaTemplateIDs.isEmpty {
            Task { await preseedFromExistingWorkspace() }
        }
        if draft.lifecyclePhase == .captureWritten {
            Task { await prepareRevealAfterCanonicalCommit() }
        }
    }

    /// Merge mode: start from what the user already has, so the commit upserts
    /// their real areas instead of creating "Health" beside "Health & Self".
    private func preseedFromExistingWorkspace() async {
        guard let areas = try? await existingLifeAreas(), areas.isEmpty == false else { return }
        let active = areas.filter { $0.isArchived == false }
        let matched = StarterWorkspaceCatalog.allLifeAreas.compactMap { template -> (id: String, order: Int)? in
            guard let area = StarterWorkspaceCatalog.matchingLifeArea(for: template, in: active) else { return nil }
            return (template.id, area.sortOrder)
        }
        guard matched.isEmpty == false else { return }
        draft.orderedLifeAreaTemplateIDs = matched
            .sorted { $0.order < $1.order }
            .map(\.id)
            .prefix(LifeWeaveDraft.maximumLifeAreas)
            .map { $0 }
        draft.primaryLifeAreaTemplateID = draft.orderedLifeAreaTemplateIDs.first
        persist()
    }

    // MARK: - Answers

    func selectIntent(_ value: LifeWeaveIntent) {
        draft.intent = value
        feedback.medium()
        persist()
    }

    /// Optional and inline. Never gates the primary action.
    func toggleBlocker(_ id: String) {
        if let index = draft.blockerIDs.firstIndex(of: id) {
            draft.blockerIDs.remove(at: index)
        } else if draft.blockerIDs.count < LifeWeaveDraft.maximumBlockers {
            draft.blockerIDs.append(id)
        }
        feedback.selection()
        persist()
    }

    func toggleLifeArea(_ template: StarterLifeAreaTemplate) {
        if let index = draft.orderedLifeAreaTemplateIDs.firstIndex(of: template.id) {
            draft.orderedLifeAreaTemplateIDs.remove(at: index)
            // Deselecting the primary area must not leave a dangling pointer to
            // it; the next area in order inherits the emphasis rather than the
            // map showing a primary that is no longer on it.
            if draft.primaryLifeAreaTemplateID == template.id {
                draft.primaryLifeAreaTemplateID = draft.orderedLifeAreaTemplateIDs.first
            }
        } else if draft.orderedLifeAreaTemplateIDs.count < LifeWeaveDraft.maximumLifeAreas {
            draft.orderedLifeAreaTemplateIDs.append(template.id)
        }
        feedback.medium()
        persist()
    }

    /// One tap replaces v5's drag ranking.
    ///
    /// The chosen area moves to index 0 because the commit writes
    /// `sortOrder = index` straight from this array — keeping the emphasis and
    /// the stored order in one place is what stops them drifting apart.
    func selectPrimaryLifeArea(_ templateID: String) {
        guard let index = draft.orderedLifeAreaTemplateIDs.firstIndex(of: templateID) else { return }
        draft.primaryLifeAreaTemplateID = templateID
        let value = draft.orderedLifeAreaTemplateIDs.remove(at: index)
        draft.orderedLifeAreaTemplateIDs.insert(value, at: 0)
        feedback.medium()
        persist()
    }

    func selectDayShapePreset(_ preset: LifeWeaveDayShapePreset) {
        draft.dayShapePreset = preset
        if let window = preset.weekdayWindow {
            draft.dayShape.weekdayStartMinute = window.start
            draft.dayShape.weekdayEndMinute = window.end
        }
        // A preset is an explicit answer, so the merge-mode commit may act on it.
        draft.didEditDayShape = true
        feedback.medium()
        persist()
    }

    /// The disclosed editor. Any hand edit stops calling the window a preset.
    func updateDayShape(_ update: (inout OnboardingDayShapeDraft) -> Void) {
        update(&draft.dayShape)
        draft.dayShapePreset = LifeWeaveMigration.preset(matching: draft.dayShape, wasEdited: true)
        draft.didEditDayShape = true
        feedback.selection()
        persist()
    }

    func skipCapture() {
        draft.skippedCapture = true
        draft.stagedCapture = nil
        captureText = ""
        feedback.light()
        persist()
        Task { await ProductTelemetry.shared.record(.firstCaptureSkipped, flowVersion: 6) }
    }

    // MARK: - Navigation

    func advance() async -> Bool {
        errorMessage = nil
        switch step {
        case .arrival:
            setStep(.intent)
        case .intent:
            guard draft.intent != nil else { return false }
            setStep(.lifeAreas)
        case .lifeAreas:
            guard draft.isLifeAreaSelectionValid else { return false }
            setStep(.dayShape)
        case .dayShape:
            setStep(.firstCapture)
        case .firstCapture:
            guard draft.isCaptureResolved else { return false }
            await assemble()
        case .reveal:
            return false
        }
        return false
    }

    /// Where Back goes, or `nil` when there is nowhere calm to go.
    ///
    /// Back never destroys an answer — it moves the step and leaves the draft
    /// alone, so returning to a screen shows what was already chosen.
    var previousStep: LifeWeaveStep? {
        guard let index = LifeWeaveStep.core.firstIndex(of: step), index > 0 else { return nil }
        // The reveal is a commit boundary. Stepping back into the capture screen
        // from it would offer to re-stage a capture that is already persisted.
        guard step != .reveal else { return nil }
        return LifeWeaveStep.core[index - 1]
    }

    func goBack() {
        guard let previousStep else { return }
        Task { await ProductTelemetry.shared.record(.onboardingBack, outcome: step.identifierSuffix) }
        setStep(previousStep)
    }

    // MARK: - Commit

    /// The transient assemble phase.
    ///
    /// On failure the draft stays on `.firstCapture` with its snapshot intact and
    /// `commitPhase` recording how far it got, so the primary action resumes
    /// rather than restarts. Nothing is cleared until the commit reports success.
    private func assemble() async {
        isCommitting = true
        defer { isCommitting = false }
        let startedAt = Date()
        await ProductTelemetry.shared.record(.commitStarted, flowVersion: 6)
        do {
            draft.lifecyclePhase = .committing
            persist()
            let legacy = draft.makeCommitDraft(moduleIDs: recommendedModuleIDs)
            let committed = try await commitCoordinator.commit(legacy) { [weak self] partial in
                guard let self else { return }
                self.draft.absorbCommitResult(partial)
                self.persist()
            }
            draft.absorbCommitResult(committed)
            draft.lifecyclePhase = .captureWritten
            persist()
            await ProductTelemetry.shared.record(.commitCompleted, flowVersion: 6)
            await holdAssemblyFloor(since: startedAt)
            await prepareRevealAfterCanonicalCommit()
        } catch {
            errorMessage = error.localizedDescription
            persist()
            await ProductTelemetry.shared.record(.commitFailed, flowVersion: 6, errorCode: "canonical_commit")
        }
    }

    /// Keeps the assemble sequence legible without exceeding `DESIGN.md`'s 800 ms
    /// signature-moment ceiling. Under reduced motion there is no sequence to
    /// protect, so the overlay crossfades out immediately.
    private func holdAssemblyFloor(since startedAt: Date) async {
        guard MotionOverride.effectiveReduceMotion == false else { return }
        let remaining = Self.assemblyFloor - Date().timeIntervalSince(startedAt)
        guard remaining > 0 else { return }
        try? await Task.sleep(for: .seconds(remaining))
    }

    private static let assemblyFloor: TimeInterval = 0.62

    private func prepareRevealAfterCanonicalCommit() async {
        guard draft.resolvedLifecyclePhase == .captureWritten else { return }
        await performEvaHandoff()
        draft.step = .reveal
        draft.lifecyclePhase = .revealReady
        persist()
        feedback.successSignature()
        await ProductTelemetry.shared.record(.revealViewed, flowVersion: 6)
    }

    @discardableResult
    func finalize(destination: LifeWeaveCompletionDestination) -> Bool {
        guard draft.resolvedLifecyclePhase == .revealReady
                || draft.resolvedLifecyclePhase == .finalized else { return false }
        if draft.resolvedLifecyclePhase != .finalized {
            draft.selectedCompletionDestination = destination
            draft.lifecyclePhase = .finalized
            persist()
            stateStore.finalizeLifeWeave(entryContext: draft.entryContext, destination: destination)
        }
        return true
    }

    func setStep(_ step: LifeWeaveStep) {
        let previous = draft.step
        draft.step = step
        MotionDiagnosticsState.shared.record("onboarding:\(step.identifierSuffix)")
        feedback.light()
        persist()
        Task {
            await ProductTelemetry.shared.record(.onboardingStepCompleted, flowVersion: 6, outcome: previous.identifierSuffix)
            await ProductTelemetry.shared.record(.onboardingStepViewed, flowVersion: 6, outcome: step.identifierSuffix)
        }
    }

    func persist() {
        if draft.entryContext == .establishedWorkspace {
            stateStore.storeRefreshDraft(draft)
        } else {
            stateStore.storeLifeWeaveJourney(draft)
        }
    }

    func setStagedCapture(_ capture: LifeMapStagedCapture?) {
        draft.stagedCapture = capture
        if capture != nil { draft.skippedCapture = false }
        persist()
        if capture != nil {
            Task { await ProductTelemetry.shared.record(.firstCaptureConfirmed, flowVersion: 6) }
        }
    }

    func recordOpeningPrompts(_ prompts: [EvaStarterPrompt]) {
        openingPrompts = prompts
    }

    func mutateDraft(_ update: (inout LifeWeaveDraft) -> Void) {
        update(&draft)
        persist()
    }

    func toggleEvaGrant(_ grant: EvaConsentPolicy.Grant, enabled: Bool) {
        var grants = draft.resolvedEvaGrants
        if enabled { grants.insert(grant) }
        else { grants.remove(grant) }
        mutateDraft {
            $0.evaSelectedGrantIDs = grants.map(\.rawValue).sorted()
        }
    }

    func recordEvaActivation(ready: Bool, pending: Bool) {
        mutateDraft {
            $0.evaCloudReady = ready
            $0.evaDeferred = ready == false
            $0.evaActivationPending = pending
        }
    }
}

/// Seeds bounded local context and starter prompts after canonical onboarding
/// writes. Cloud activation is confirmed on the reveal after these local writes.
@MainActor
extension LifeWeaveOnboardingModel {
    func performEvaHandoff() async {
        let legacy = draft.makeCommitDraft(moduleIDs: recommendedModuleIDs)

        if draft.didWriteEvaProfile == false {
            let profile = LifeMapEvaProfileMapper.profileDraft(from: legacy)
            let merged = EvaMemoryMapper.mergeIntoV3Store(
                draft: profile,
                existing: EvaMemoryDefaultsStoreV3.load()
            )
            EvaMemoryDefaultsStoreV3.save(merged)
            mutateDraft { $0.didWriteEvaProfile = true }
        }

        let prompts = LifeMapEvaOpeningPrompt.prompts(
            for: legacy,
            upcomingEventCount: await powerUps.upcomingEventCount()
        )
        recordOpeningPrompts(prompts)
        EvaOpeningPromptStore.stage(prompts)
    }
}
