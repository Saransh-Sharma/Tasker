import Foundation
import LifeBoardDomain
import LifeBoardTokens
import SwiftUI

/// The outside-world services the power-up chain drives.
///
/// Injected as closures for the same reason `LifeMapCommitCoordinator` is:
/// every one of these touches a system permission dialog, EventKit, HealthKit,
/// or the network, none of which a unit test can stand up. The defaults below
/// are the real wiring, so production callers construct the model unchanged.
@MainActor
struct LifeMapPowerUpDependencies {
    /// Returns whether calendar access was actually granted. Deliberately not
    /// `PermissionPrimingCoordinator.performRequest`, whose calendar seam is
    /// `() -> Void` and reports nothing.
    var requestCalendarAccess: () async -> Bool = { false }
    /// Every calendar EventKit reports, after access was granted.
    var availableCalendars: () async -> [CalendarSourceSnapshot] = { [] }
    var updateSelectedCalendarIDs: ([String]) async -> Void = { _ in }
    /// Events in the coming week, used only to decide whether the opening
    /// prompt may mention the calendar at all.
    var upcomingEventCount: () async -> Int? = { nil }
    var requestNotificationAccess: () async -> Bool = { false }
    var connectHealth: (Set<HealthDomain>, Bool) async -> Void = { _, _ in }
    var setHealthWriteEnabled: (Bool, HealthDomain) async -> Void = { _, _ in }
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
    @Published private(set) var availableCalendars: [CalendarSourceSnapshot] = []
    @Published private(set) var openingPrompts: [EvaStarterPrompt] = []

    let feedback: OnboardingFeedbackController
    private let stateStore: AppOnboardingStateStore
    private let commitCoordinator: LifeMapCommitCoordinator
    private let universalInput = UniversalInputCoordinator()
    private let existingLifeAreas: () async throws -> [LifeArea]
    private let powerUps: LifeMapPowerUpDependencies

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
            // The primary action skips straight to the closing phase; the
            // power-up chain is reached through the secondary action, which
            // calls `enterPowerUps()` instead.
            setStep(.tour)
        case .calendar, .health, .reminders, .eva:
            setStep(stepAfterPowerUp(step))
        case .tour:
            setStep(.firstWin)
        case .firstWin:
            return true
        }
        return false
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

/// The power-up chain and the EVA hand-off.
///
/// A same-file extension: the guardrail measures the largest top-level
/// declaration, and keeping this here preserves access to the model's
/// `private` dependencies and `persist()`.
@MainActor
extension LifeMapOnboardingModel {
    /// The reveal's secondary action: opt in to connecting the outside world.
    func enterPowerUps() {
        setStep(visiblePowerUps.first ?? .tour)
    }

    /// The power-up steps worth showing for this workspace, in order.
    var visiblePowerUps: [LifeMapOnboardingStep] {
        LifeMapOnboardingStep.visiblePowerUps(
            requestablePermissions: requestablePermissions,
            includesEva: selectedModuleGroups.contains(.eva)
        )
    }

    /// Back-navigation targets for the current step.
    ///
    /// Core walks core. The power-up chain walks itself and stops at its own
    /// first step: the only thing behind it is the post-commit reveal, and
    /// re-entering `.capture` from there would re-run a commit that has already
    /// succeeded. The closing phase is one-way by design.
    private var navigableFlow: [LifeMapOnboardingStep] {
        if step.isPowerUp { return visiblePowerUps }
        if step.isClosing { return [] }
        return LifeMapOnboardingStep.core
    }

    var canGoBack: Bool {
        guard let index = navigableFlow.firstIndex(of: step) else { return false }
        return index > 0
    }

    private func stepAfterPowerUp(_ current: LifeMapOnboardingStep) -> LifeMapOnboardingStep {
        let chain = visiblePowerUps
        guard let index = chain.firstIndex(of: current), index + 1 < chain.count else { return .tour }
        return chain[index + 1]
    }

    func goBack() {
        let flow = navigableFlow
        guard let index = flow.firstIndex(of: step), index > 0 else { return }
        setStep(flow[index - 1])
    }

    /// Requests a permission and records **what the system actually said**.
    ///
    /// The previous implementation appended to a single `permissionIDs` list
    /// the moment the request returned, so tapping Allow and then "Don't Allow"
    /// in the system sheet still painted a green "Connected" checkmark. Worse,
    /// the calendar path went through `PermissionPrimingCoordinator`, whose
    /// `requestCalendar` seam is fire-and-forget `() -> Void` — the outcome was
    /// not merely mis-recorded, it was never observed.
    ///
    /// Each branch below therefore uses the properly async service call and
    /// reads a real status back. `PermissionPromptState.recordRequested` still
    /// runs for every kind, so onboarding and Settings leave identical state.
    @discardableResult
    func requestPermission(_ kind: PermissionKind) async -> Bool {
        guard permissionInFlight == nil else { return false }
        permissionInFlight = kind
        defer { permissionInFlight = nil }

        let granted: Bool
        switch kind {
        case .calendar:
            PermissionPromptState.recordRequested(.calendar)
            granted = await powerUps.requestCalendarAccess()
            if granted { await preselectAvailableCalendars() }
        case .notifications:
            PermissionPromptState.recordRequested(.notifications)
            granted = await powerUps.requestNotificationAccess()
        case .appleHealth:
            // Read authorization only. Write-back is a separate answer the
            // health step collects explicitly; see `setHealthWriteBack`.
            await powerUps.connectHealth(
                OnboardingModuleCatalog.healthDomains(for: selectedModuleIDs),
                false
            )
            // HealthKit deliberately hides read denial, so there is no honest
            // "granted" to report — only that the sheet was presented. The row
            // says "Asked" rather than "Connected" for exactly this reason.
            granted = true
        case .microphone, .speech, .camera:
            // Requested by the capture surface at the point of use; onboarding
            // names them but must not pre-empt the system dialog.
            PermissionPromptState.recordRequested(kind)
            granted = false
        }

        record(kind: kind, granted: granted)
        persist()
        return granted
    }

    private func record(kind: PermissionKind, granted: Bool) {
        draft.grantedPermissionIDs.removeAll { $0 == kind.id }
        draft.deniedPermissionIDs.removeAll { $0 == kind.id }
        if granted {
            draft.grantedPermissionIDs.append(kind.id)
        } else {
            draft.deniedPermissionIDs.append(kind.id)
        }
    }

    /// A granted calendar with no selection shows nothing.
    ///
    /// `FilterCalendarEventsUseCase` treats an empty `selectedCalendarIDs` as
    /// *no calendars*, not *all of them*, and the integration service only ever
    /// removes stale IDs on refresh — nothing seeds a default. So granting
    /// access and stopping there produced an empty schedule, empty Home cards,
    /// and an empty calendar projection in EVA's context.
    ///
    /// Every available calendar is preselected rather than some "primary" one:
    /// neither `CalendarSnapshot` nor `CalendarIntegrationService` models a
    /// default calendar, and reaching for `EKEventStore.defaultCalendarForNewEvents`
    /// would mean widening the calendar package's public surface to answer a
    /// question the user can answer better themselves. The step shows the full
    /// list immediately, so narrowing is one tap away.
    private func preselectAvailableCalendars() async {
        guard draft.selectedCalendarIDs.isEmpty else { return }
        availableCalendars = await powerUps.availableCalendars()
        let preselected = availableCalendars.map(\.id).sorted()
        guard preselected.isEmpty == false else { return }
        draft.selectedCalendarIDs = preselected
        await powerUps.updateSelectedCalendarIDs(preselected)
    }

    func setCalendarSelection(_ ids: [String]) {
        draft.selectedCalendarIDs = ids.sorted()
        persist()
        Task { await powerUps.updateSelectedCalendarIDs(draft.selectedCalendarIDs) }
    }

    /// Writable domains the health step should offer, in catalog order.
    var writableHealthDomains: [HealthDomain] {
        HealthDomain.allCases.filter {
            $0.supportsWriteBack && OnboardingModuleCatalog.healthDomains(for: selectedModuleIDs).contains($0)
        }
    }

    func setHealthWriteBack(_ enabled: Bool, for domain: HealthDomain) async {
        if enabled {
            if draft.healthWriteBackDomainIDs.contains(domain.id) == false {
                draft.healthWriteBackDomainIDs.append(domain.id)
            }
        } else {
            draft.healthWriteBackDomainIDs.removeAll { $0 == domain.id }
        }
        persist()
        await powerUps.setHealthWriteEnabled(enabled, domain)
    }

    func deferPermission(_ kind: PermissionKind) {
        PermissionPromptState.recordOnboardingDeferral(kind)
    }

    func isGranted(_ kind: PermissionKind) -> Bool {
        draft.grantedPermissionIDs.contains(kind.id)
    }

    func isDenied(_ kind: PermissionKind) -> Bool {
        draft.deniedPermissionIDs.contains(kind.id)
    }

    func toggleCalendar(_ id: String) {
        var ids = Set(draft.selectedCalendarIDs)
        if ids.contains(id) { ids.remove(id) } else { ids.insert(id) }
        feedback.selection()
        setCalendarSelection(Array(ids))
    }

    /// Leaves the power-up chain without skipping the closing phase.
    ///
    /// "Enter LifeBoard" reads as an exit, but the tour and the staged EVA
    /// openers are the part every user should get — including, especially, the
    /// user who just declined every connection and would otherwise arrive at a
    /// Home they have never been introduced to.
    func skipToClosing() {
        setStep(.tour)
    }

    func chooseOfflineEva() async {
        draft.evaDeferred = true
        // `EvaProviderRouter` is an actor; the preference write is isolated to it
        // so cloud selection and this setting can never disagree mid-flight.
        await EvaProviderRouter.shared.setPreference(.offline)
        persist()
    }

    /// Writes the EVA profile and builds the openers.
    ///
    /// Runs on entering `.firstWin` rather than inside the commit, because the
    /// commit already succeeded several steps ago. `didWriteEvaProfile` makes a
    /// re-entry a no-op; `EvaMemoryMapper` also dedupes, so the guard is belt
    /// and braces rather than the only thing standing between the user and a
    /// memory full of repeated lines.
    func prepareEvaHandoff() async {
        draft.evaCloudReady = EvaCloudAccountState.shared.canUseCloud
        if draft.didWriteEvaProfile == false {
            let profile = LifeMapEvaProfileMapper.profileDraft(from: draft)
            let merged = EvaMemoryMapper.mergeIntoLocalStore(
                draft: profile,
                existing: LLMPersonalMemoryDefaultsStore.load()
            )
            LLMPersonalMemoryDefaultsStore.save(merged)
            draft.didWriteEvaProfile = true
        }
        openingPrompts = LifeMapEvaOpeningPrompt.prompts(
            for: draft,
            upcomingEventCount: await powerUps.upcomingEventCount()
        )
        persist()
    }

    /// Stages the openers and retires the standalone EVA activation flow.
    func completeEvaHandoff() {
        draft.didTour = true
        EvaOpeningPromptStore.stage(openingPrompts)
        EvaActivationDefaultsStore.markCompleted()
        persist()
    }
}
