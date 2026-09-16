import Foundation
import LifeBoardDomain

/// The outside-world services the power-up chain drives.
///
/// Injected as closures for the same reason `LifeMapCommitCoordinator` is:
/// every one of these touches a system permission dialog, EventKit, HealthKit,
/// or the network, none of which a unit test can stand up. The defaults below
/// are the real wiring, so production callers construct the model unchanged.
@MainActor
struct LifeMapPowerUpDependencies {
    var offlineEvaReady: () -> Bool = { false }
    /// Returns whether calendar access was actually granted. Deliberately not
    /// `PermissionPrimingCoordinator.performRequest`, whose calendar seam is
    /// `() -> Void` and reports nothing.
    var requestCalendarAccess: () async -> Bool = { false }
    /// Every calendar EventKit reports, after access was granted.
    var availableCalendars: () async -> [CalendarSourceSnapshot] = { [] }
    /// The real authorization status, read back rather than inferred.
    ///
    /// Without this the only readable signal is "did a fetch return calendars",
    /// which collapses `restricted` and `writeOnly` into `denied` — so a device
    /// under a configuration profile was told to open Settings and turn on a
    /// switch it does not have, and a write-only grant was never offered the
    /// upgrade to full access that would actually fix it.
    var calendarAuthorizationStatus: () async -> CalendarAuthorizationStatus = { .notDetermined }
    var updateSelectedCalendarIDs: ([String]) async -> Void = { _ in }
    /// Events in the coming week, used only to decide whether the opening
    /// prompt may mention the calendar at all.
    var upcomingEventCount: () async -> Int? = { nil }
    var requestNotificationAccess: () async -> Bool = { false }
    var connectHealth: (Set<HealthDomain>, Bool) async -> Void = { _, _ in }
    var setHealthWriteEnabled: (Bool, HealthDomain) async -> Void = { _, _ in }
}

/// Entering, advancing, deferring, and leaving the optional second phase.
///
/// The only place that writes `draft.powerUpStep`. A connector opens as a sheet
/// over the Ready screen and returns there, so `draft.step` stays at `.reveal`
/// for the whole phase and the two never disagree.
///
/// This file holds journey position only. What Calendar, Health, and EVA are
/// actually *doing* belongs to their own services; the per-connector extensions
/// beside this one wrap those services and never duplicate them.
@MainActor
extension LifeWeaveOnboardingModel {

    var powerUpStep: LifeWeavePowerUpStep? { draft.resolvedPowerUpStep }

    /// The Health connector's live state, read straight from its store. The
    /// sheet renders from `HealthConnectionStore` itself; this is only for the
    /// outcome token below.
    var healthFirstSyncOutcome: HealthFirstSyncOutcome {
        HealthCoordinator.shared.connectionStore.presentation
    }

    /// Presentation switch only. Off, the journey ends at the reveal exactly as
    /// it did before the phase existed — and every connection a user already
    /// made survives, because none of that truth lives in this flow.
    var isPowerUpAvailable: Bool { V2FeatureFlags.onboardingPowerUpsEnabled }

    /// Reveal primary: record core completion, then open the first connector.
    ///
    /// Completion is written *before* the first connector is offered, which is
    /// the whole contract — a permission sheet that fails, a network that is
    /// down, or a force-quit during Calendar all leave a finished LifeBoard.
    func beginPowerUp(_ connector: LifeWeavePowerUpStep = .calendar) {
        let phase = draft.resolvedLifecyclePhase
        guard phase == .revealReady || phase == .poweringUp else { return }

        // Ordering matters. If the app dies between these two writes, core is
        // complete and the phase was never entered — which resumes at the
        // reveal. The reverse order would strand a phase over an unfinished core.
        recordCoreCompletion()
        mutateDraft {
            $0.lifecyclePhase = .poweringUp
            $0.powerUpStep = connector.rawValue
        }
        feedback.light()
        Task {
            await ProductTelemetry.shared.record(
                .onboardingStepViewed,
                flowVersion: AppOnboardingState.currentVersion,
                outcome: "powerup_\(connector.identifierSuffix)"
            )
        }
    }

    func finishConnector() {
        if let connector = draft.resolvedPowerUpStep { recordConnectorResult(connector) }
        mutateDraft {
            $0.powerUpStep = nil
            $0.step = .reveal
            $0.lifecyclePhase = .revealReady
        }
    }

    /// "Not now". An explicit choice, recorded as one.
    ///
    /// Distinct from "not reached" and from "denied in the system sheet": only
    /// this means the person decided, and it is why Setup Center must not nag
    /// afterwards. System permissions record a *deferral* rather than a decline —
    /// `recordOnboardingDeferral` costs no snooze and no decline count, so a
    /// later in-context offer is still allowed to happen once.
    func deferCurrentPowerUp() {
        guard let current = draft.resolvedPowerUpStep else { return }
        recordDeferral(of: current)
        finishConnector()
    }

    /// Reveal secondary — "Start now". Defers everything unresolved by explicit
    /// choice and ends the journey at Home, with no nag card waiting there.
    @discardableResult
    func deferAllPowerUpsAndFinish() -> Bool {
        recordCoreCompletion()
        for connector in LifeWeavePowerUpStep.connectors {
            recordDeferral(of: connector)
        }
        if ConnectionResumeStore.pending.isEmpty { SetupCenterHomeCardPreference.dismiss() }
        for connector in LifeWeavePowerUpStep.connectors {
            recordConnectorResult(connector)
        }
        return finalize(destination: .home)
    }

    // MARK: - Internals

    /// A short, content-free token for how a connector actually ended.
    ///
    /// Deliberately not the user-facing status copy: that is written to be read
    /// by a person and would drag calendar names, metric counts, and error text
    /// into telemetry. These tokens carry the shape of the outcome and nothing
    /// about the person's data.
    func connectorOutcomeToken(for connector: LifeWeavePowerUpStep) -> String {
        // Live success always outranks an older skip.
        if connector == .calendar, calendarStage == .proof { return "ready" }
        if connector == .health, case .ready = healthFirstSyncOutcome { return "ready" }
        if connector == .eva, draft.evaCloudReady { return "ready" }
        if draft.resolvedDeferredPowerUps.contains(connector) { return "later" }
        switch connector {
        case .calendar:
            switch calendarStage {
            case .proof: return "ready"
            case .chooser: return "no_selection"
            case .primer: return "not_started"
            case .recovery: return "attention"
            }
        case .health:
            switch healthFirstSyncOutcome {
            case .ready: return "ready"
            case .syncing, .requesting: return "syncing"
            case .reviewedNoDataYet: return "no_data"
            case .partial, .authorizationFailed: return "attention"
            case .protectedDataLocked: return "locked"
            case .unavailable: return "unavailable"
            case .notRequested: return "not_started"
            }
        case .eva:
            if evaPrefersOffline { return "offline" }
            return draft.evaCloudReady ? "ready" : "not_started"
        }
    }

    private func recordConnectorResult(_ connector: LifeWeavePowerUpStep) {
        let outcome = "\(connector.identifierSuffix)_\(connectorOutcomeToken(for: connector))"
        Task {
            await ProductTelemetry.shared.record(
                .connectorResult,
                flowVersion: AppOnboardingState.currentVersion,
                outcome: outcome
            )
        }
    }

    private func recordDeferral(of connector: LifeWeavePowerUpStep) {
        var deferred = draft.resolvedDeferredPowerUps
        guard deferred.contains(connector) == false else { return }
        deferred.insert(connector)
        mutateDraft {
            $0.deferredPowerUpIDs = deferred.map(\.rawValue).sorted()
            if connector == .eva { $0.evaDeferred = true }
        }

        // Reuse the durable permission memory rather than inventing a parallel
        // skip flag. A deferral is deliberately not a decline: it costs no
        // snooze and no decline count, so a later in-context offer is still
        // allowed to happen once. EVA is not a system permission and has none.
        switch connector {
        case .calendar: PermissionPromptState.recordOnboardingDeferral(.calendar)
        case .health: PermissionPromptState.recordOnboardingDeferral(.appleHealth)
        case .eva: break
        }
        Task {
            await ProductTelemetry.shared.record(
                .onboardingDeferred,
                flowVersion: AppOnboardingState.currentVersion,
                outcome: connector.identifierSuffix
            )
        }
    }
}
