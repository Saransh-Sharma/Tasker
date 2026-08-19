import Foundation
import LifeBoardDomain

/// The optional connect chain and the EVA hand-off.
///
/// Structurally this is the one place v6 differs most from v5, and the
/// difference is *where the chain sits* rather than what it does. In v5 the
/// chain was on the way out of onboarding and a five-beat root tour ran after
/// it, so every user was walked past four privacy decisions and five product
/// descriptions before reaching Home. Here the chain is reached only by tapping
/// "Set up connections" on the reveal, and there is nothing after it.
///
/// The permission handling itself is v5's and is correct as written: real
/// outcomes recorded per kind, calendar preselected on grant, Health read and
/// write-back asked separately.
@MainActor
extension LifeWeaveOnboardingModel {

    /// The reveal's secondary action.
    func enterPowerUps() {
        guard let first = visiblePowerUpChain.first else { return }
        setStep(first)
    }

    var visiblePowerUpChain: [LifeWeaveStep] {
        LifeWeaveStep.visiblePowerUps(
            requestablePermissions: requestablePermissions,
            includesEva: true
        )
    }

    /// The next connector, or `nil` when the chain is done and the flow exits.
    func stepAfterPowerUp(_ current: LifeWeaveStep) -> LifeWeaveStep? {
        let chain = visiblePowerUpChain
        guard let index = chain.firstIndex(of: current), index + 1 < chain.count else { return nil }
        return chain[index + 1]
    }

    /// Requests a permission and records **what the system actually said**.
    ///
    /// Granted and denied are separate lists because a single "we asked" list is
    /// how v5 came to paint a green "Connected" row for a permission the user had
    /// just refused in the system sheet.
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
            // Read authorization only. Write-back is a separate answer collected
            // per domain by the health step.
            await powerUps.connectHealth(
                OnboardingModuleCatalog.healthDomains(for: recommendedModuleIDs),
                false
            )
            // HealthKit hides read denial by design, so there is no honest
            // "granted" to report — only that the sheet was presented. The row
            // says "Asked" rather than "Connected" for exactly this reason.
            granted = true
        case .microphone, .speech, .camera:
            // Requested by the capture surface at the point of use. Onboarding
            // may name them; it must not pre-empt the system dialog.
            PermissionPromptState.recordRequested(kind)
            granted = false
        }

        mutateDraft { draft in
            draft.grantedPermissionIDs.removeAll { $0 == kind.id }
            draft.deniedPermissionIDs.removeAll { $0 == kind.id }
            if granted {
                draft.grantedPermissionIDs.append(kind.id)
            } else {
                draft.deniedPermissionIDs.append(kind.id)
            }
        }
        return granted
    }

    /// A granted calendar with no selection shows nothing.
    ///
    /// `FilterCalendarEventsUseCase` reads an empty `selectedCalendarIDs` as
    /// *no calendars*, not *all of them*, and nothing seeds a default — so
    /// granting access and stopping there produces an empty schedule, empty Home
    /// cards, and an empty calendar projection in EVA's context.
    private func preselectAvailableCalendars() async {
        guard draft.selectedCalendarIDs.isEmpty else { return }
        let calendars = await powerUps.availableCalendars()
        recordCalendars(calendars)
        let preselected = calendars.map(\.id).sorted()
        guard preselected.isEmpty == false else { return }
        mutateDraft { $0.selectedCalendarIDs = preselected }
        await powerUps.updateSelectedCalendarIDs(preselected)
    }

    func setCalendarSelection(_ ids: [String]) {
        mutateDraft { $0.selectedCalendarIDs = ids.sorted() }
        Task { await powerUps.updateSelectedCalendarIDs(draft.selectedCalendarIDs) }
    }

    func toggleCalendar(_ id: String) {
        var ids = Set(draft.selectedCalendarIDs)
        if ids.contains(id) { ids.remove(id) } else { ids.insert(id) }
        feedback.selection()
        setCalendarSelection(Array(ids))
    }

    var writableHealthDomains: [HealthDomain] {
        let domains = OnboardingModuleCatalog.healthDomains(for: recommendedModuleIDs)
        return HealthDomain.allCases.filter { $0.supportsWriteBack && domains.contains($0) }
    }

    func setHealthWriteBack(_ enabled: Bool, for domain: HealthDomain) async {
        mutateDraft { draft in
            if enabled {
                if draft.healthWriteBackDomainIDs.contains(domain.id) == false {
                    draft.healthWriteBackDomainIDs.append(domain.id)
                }
            } else {
                draft.healthWriteBackDomainIDs.removeAll { $0 == domain.id }
            }
        }
        await powerUps.setHealthWriteEnabled(enabled, domain)
    }

    /// A skip during onboarding is a deferral, not a decline, so the
    /// just-in-time offer may still make its case later at the point of use.
    func deferPermission(_ kind: PermissionKind) {
        PermissionPromptState.recordOnboardingDeferral(kind)
    }

    func isGranted(_ kind: PermissionKind) -> Bool { draft.grantedPermissionIDs.contains(kind.id) }
    func isDenied(_ kind: PermissionKind) -> Bool { draft.deniedPermissionIDs.contains(kind.id) }

    func chooseOfflineEva() async {
        mutateDraft { $0.evaDeferred = true }
        // `EvaProviderRouter` is an actor; the preference write is isolated to it
        // so cloud selection and this setting can never disagree mid-flight.
        await EvaProviderRouter.shared.setPreference(.offline)
    }

    /// Writes the EVA profile, builds the openers, and stages them.
    ///
    /// v5 ran this on entering `.firstWin`, the last beat of the root tour. v6
    /// has no tour, so it runs at the end of the commit instead — deleting the
    /// closing phase must not silently delete the grounded opening prompts with
    /// it. `didWriteEvaProfile` makes a re-entry a no-op; `EvaMemoryMapper` also
    /// dedupes, so the guard is belt and braces rather than the only thing
    /// standing between the user and a memory full of repeated lines.
    func performEvaHandoff() async {
        let legacy = draft.makeCommitDraft(moduleIDs: recommendedModuleIDs)
        mutateDraft { $0.evaCloudReady = EvaCloudAccountState.shared.canUseCloud }

        if draft.didWriteEvaProfile == false {
            let profile = LifeMapEvaProfileMapper.profileDraft(from: legacy)
            let merged = EvaMemoryMapper.mergeIntoLocalStore(
                draft: profile,
                existing: LLMPersonalMemoryDefaultsStore.load()
            )
            LLMPersonalMemoryDefaultsStore.save(merged)
            mutateDraft { $0.didWriteEvaProfile = true }
        }

        let prompts = LifeMapEvaOpeningPrompt.prompts(
            for: legacy,
            upcomingEventCount: await powerUps.upcomingEventCount()
        )
        recordOpeningPrompts(prompts)
        EvaOpeningPromptStore.stage(prompts)
        EvaActivationDefaultsStore.markCompleted()
    }
}
