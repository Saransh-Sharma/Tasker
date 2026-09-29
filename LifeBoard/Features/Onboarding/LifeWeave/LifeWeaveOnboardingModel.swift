import Foundation
import LifeBoardDomain
import LifeBoardTokens
import SwiftUI

@MainActor
final class LifeWeaveOnboardingModel: ObservableObject {
    @Published private(set) var draft = LifeWeaveDraft()
    @Published var captureText = "" {
        didSet {
            captureEditGeneration &+= 1
            draft.unreviewedCaptureText = captureText
            persist()
        }
    }
    /// Bumped on every edit. An interpretation captures it before awaiting the
    /// resolver and is discarded if the text moved on in the meantime, so a slow
    /// answer for an old sentence can never overwrite the one on screen.
    private(set) var captureEditGeneration = 0
    /// The interpretation currently awaiting the resolver, keyed by the exact
    /// sentence it is reading. Save joins it rather than starting a second.
    var captureResolution: (text: String, task: Task<Void, Never>)?
    @Published var isResolvingCapture = false
    /// Set when the resolver could not honestly claim a destination, so the
    /// review card shows the chooser instead of a confident answer.
    @Published var isCaptureAmbiguous = false
    @Published var isCommitting = false
    /// The pending pause-to-interpret pass. See `scheduleCaptureInterpretation`.
    var captureInterpretationTask: Task<Void, Never>?
    @Published var errorMessage: String?
    @Published var showsOfflineSetup = false
    /// The Cloud EVA consent sheet; the connector never connects without it.
    @Published var showsEvaConsent = false
    @Published private(set) var openingPrompts: [EvaStarterPrompt] = []

    let feedback: OnboardingFeedbackController
    private let stateStore: AppOnboardingStateStore
    let commitCoordinator: LifeMapCommitCoordinator
    private let existingLifeAreas: () async throws -> [LifeArea]
    /// By default the same construction as the shell's `UniversalInputCoordinator`:
    /// the deterministic adapters plus the semantic one, so a sentence classifies
    /// identically here and in the composer the user meets a minute later. Tests
    /// hand in a gated resolver to drive the interleavings deterministically.
    let captureResolver: any LifeWeaveCaptureResolving
    let powerUps: LifeMapPowerUpDependencies

    init(
        stateStore: AppOnboardingStateStore = .shared,
        commitCoordinator: LifeMapCommitCoordinator,
        feedback: OnboardingFeedbackController,
        existingLifeAreas: @escaping () async throws -> [LifeArea] = { [] },
        powerUps: LifeMapPowerUpDependencies = LifeMapPowerUpDependencies(),
        captureResolver: any LifeWeaveCaptureResolving = UniversalInputCoordinator()
    ) {
        self.stateStore = stateStore
        self.commitCoordinator = commitCoordinator
        self.feedback = feedback
        self.existingLifeAreas = existingLifeAreas
        self.powerUps = powerUps
        self.captureResolver = captureResolver
    }

    var step: LifeWeaveStep { draft.step }
    var coreSteps: [LifeWeaveStep] { LifeWeaveStep.streamlined }
    var offlineEvaActionTitle: String { powerUps.offlineEvaReady() ? String(localized: "Use Eva offline") : String(localized: "Set up offline") }


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
        draft.streamlinedJourney = true
        draft = LifeWeaveMigration.streamlined(draft)
        // A server consent or confirmed receipt outranks unconfirmed defaults.
        if let consent = EvaCloudAccessCoordinator.shared.account.consent {
            draft.evaSelectedGrantIDs = consent.grants.map(\.rawValue)
        } else if let receipt = EvaCloudActivationReceiptStore.load() {
            draft.evaSelectedGrantIDs = receipt.grants.map(\.rawValue)
        }
        draft.lifecyclePhase = draft.resolvedLifecyclePhase
        if draft.lifecyclePhase == .revealReady { draft.step = .reveal }
        captureText = draft.stagedCapture?.text ?? draft.unreviewedCaptureText ?? ""
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
        feedback.selection()
        persist()
    }

    /// Pick order is the ranking.
    ///
    /// The first area picked leads, and the commit writes `sortOrder = index`
    /// straight from this array. That replaced a separate "which one first?"
    /// question: numbered picks answer it without asking, and deselecting the
    /// leader promotes the next pick instead of leaving a dangling primary.
    func toggleLifeArea(_ template: StarterLifeAreaTemplate) {
        let wasValid = draft.isLifeAreaSelectionValid
        if let index = draft.orderedLifeAreaTemplateIDs.firstIndex(of: template.id) {
            draft.orderedLifeAreaTemplateIDs.remove(at: index)
        } else if draft.orderedLifeAreaTemplateIDs.count < LifeWeaveDraft.maximumLifeAreas {
            draft.orderedLifeAreaTemplateIDs.append(template.id)
        }
        draft.primaryLifeAreaTemplateID = draft.orderedLifeAreaTemplateIDs.first
        // One settle when the selection becomes enough to continue, rather than
        // the same tick on every tap.
        if wasValid == false, draft.isLifeAreaSelectionValid {
            feedback.medium()
        } else {
            feedback.selection()
        }
        persist()
    }

    /// Picks remaining before the areas step can continue. Zero once it can.
    var lifeAreasStillNeeded: Int {
        max(0, LifeWeaveDraft.minimumLifeAreas - draft.orderedLifeAreaTemplateIDs.count)
    }

    func selectDayShapePreset(_ preset: LifeWeaveDayShapePreset) {
        draft.dayShapePreset = preset
        if let window = preset.weekdayWindow {
            draft.dayShape.weekdayStartMinute = window.start
            draft.dayShape.weekdayEndMinute = window.end
        }
        // A preset is an explicit answer, so the merge-mode commit may act on it.
        draft.didEditDayShape = true
        feedback.selection()
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
        captureInterpretationTask?.cancel()
        draft.skippedCapture = true
        draft.stagedCapture = nil
        captureText = ""
        feedback.light()
        persist()
        Task { await ProductTelemetry.shared.record(.firstCaptureSkipped, flowVersion: 6) }
    }

    /// The life areas "Set up later" starts with: broad enough to hold
    /// anything, and both easy to rename or remove afterwards.
    static let setUpLaterLifeAreaTemplateIDs = ["work-career", "life-admin"]

    /// "Set up later" on the first screen. Fills anything unanswered with a
    /// default, skips the capture, and commits, so the person lands on Ready
    /// with a working LifeBoard instead of three more questions.
    func setUpLater() async {
        guard !isCommitting, step == .arrival || step == .intent else { return }
        errorMessage = nil
        if draft.intent == nil { draft.intent = .somethingElse }
        if draft.isLifeAreaSelectionValid == false {
            draft.orderedLifeAreaTemplateIDs = Self.setUpLaterLifeAreaTemplateIDs
            draft.primaryLifeAreaTemplateID = draft.orderedLifeAreaTemplateIDs.first
        }
        if draft.isCaptureResolved == false {
            skipCapture()
        }
        persist()
        await assemble()
    }

    // MARK: - Navigation

    func advance() async {
        guard !isCommitting else { return }
        errorMessage = nil
        switch step {
        case .arrival, .intent:
            guard draft.intent != nil else { return }
            setStep(.lifeAreas)
        case .lifeAreas, .dayShape:
            guard draft.isLifeAreaSelectionValid else { return }
            setStep(.firstCapture)
        case .firstCapture:
            guard draft.isCaptureResolved else { return }
            await assemble()
        case .reveal:
            break
        }
    }

    /// Where Back goes, or `nil` when there is nowhere calm to go.
    ///
    /// Back never destroys an answer — it moves the step and leaves the draft
    /// alone, so returning to a screen shows what was already chosen.
    var previousStep: LifeWeaveStep? {
        guard let index = coreSteps.firstIndex(of: step), index > 0 else { return nil }
        // The reveal is a commit boundary. Stepping back into the capture screen
        // from it would offer to re-stage a capture that is already persisted.
        guard step != .reveal else { return nil }
        return coreSteps[index - 1]
    }

    func goBack() {
        guard let previousStep else { return }
        Task { await ProductTelemetry.shared.record(.onboardingBack, outcome: step.identifierSuffix) }
        setStep(previousStep)
    }

    @discardableResult
    func finalize(destination: LifeWeaveCompletionDestination) -> Bool {
        // `.poweringUp` is a finishable phase: the optional connectors run after
        // core is already committed and recorded, so ending from inside them is
        // an ordinary exit rather than an abandoned setup.
        guard draft.resolvedLifecyclePhase == .revealReady
                || draft.resolvedLifecyclePhase == .poweringUp
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

    /// Records core completion without ending the journey.
    ///
    /// A deliberately narrow seam: the power-up extensions need this one effect
    /// on `stateStore` and nothing else, so the store itself stays private and
    /// no connector can start writing onboarding state directly.
    func recordCoreCompletion() {
        stateStore.completeCore(entryContext: draft.entryContext)
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
