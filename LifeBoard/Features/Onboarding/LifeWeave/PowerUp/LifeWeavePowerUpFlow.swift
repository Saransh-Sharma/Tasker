import Foundation

/// Entering, advancing, deferring, and leaving the optional second phase.
///
/// The only place that writes `draft.powerUpStep`. Everything else reads
/// `draft.route`, so the two axes — where the user is in core, and where they
/// are in Power Up — can never disagree.
///
/// This file holds journey position only. What Calendar, Health, and EVA are
/// actually *doing* belongs to their own services; the per-connector extensions
/// beside this one wrap those services and never duplicate them.
@MainActor
extension LifeWeaveOnboardingModel {

    var powerUpStep: LifeWeavePowerUpStep? { draft.powerUpStep }

    /// Presentation switch only. Off, the journey ends at the reveal exactly as
    /// it did before the phase existed — and every connection a user already
    /// made survives, because none of that truth lives in this flow.
    var isPowerUpAvailable: Bool { V2FeatureFlags.onboardingPowerUpsEnabled }

    /// Reveal primary: record core completion, then open the first connector.
    ///
    /// Completion is written *before* the first connector is offered, which is
    /// the whole contract — a permission sheet that fails, a network that is
    /// down, or a force-quit during Calendar all leave a finished LifeBoard.
    func beginPowerUp() {
        let phase = draft.resolvedLifecyclePhase
        guard phase == .revealReady || phase == .poweringUp else { return }

        // Ordering matters. If the app dies between these two writes, core is
        // complete and the phase was never entered — which resumes at the
        // reveal. The reverse order would strand a phase over an unfinished core.
        recordCoreCompletion()
        mutateDraft {
            $0.lifecyclePhase = .poweringUp
            $0.powerUpStep = .calendar
        }
        feedback.light()
        Task {
            await ProductTelemetry.shared.record(
                .onboardingStepViewed,
                flowVersion: AppOnboardingState.currentVersion,
                outcome: "powerup_calendar"
            )
        }
    }

    /// Move to the next power-up screen, or finish if there is none.
    func advancePowerUp() {
        guard let current = draft.powerUpStep, let next = current.next else { return }
        setPowerUpStep(next, from: current)
    }

    /// "Not now". An explicit choice, recorded as one.
    ///
    /// Distinct from "not reached" and from "denied in the system sheet": only
    /// this means the person decided, and it is why Setup Center must not nag
    /// afterwards. System permissions record a *deferral* rather than a decline —
    /// `recordOnboardingDeferral` costs no snooze and no decline count, so a
    /// later in-context offer is still allowed to happen once.
    func deferCurrentPowerUp() {
        guard let current = draft.powerUpStep, current.connectorIndex != nil else { return }
        recordDeferral(of: current)
        advancePowerUp()
    }

    /// Reveal secondary — "Start now". Defers everything unresolved by explicit
    /// choice and ends the journey at Home, with no nag card waiting there.
    @discardableResult
    func deferAllPowerUpsAndFinish() -> Bool {
        recordCoreCompletion()
        for connector in LifeWeavePowerUpStep.connectors {
            recordDeferral(of: connector)
        }
        suppressHomeCardIfEverythingWasDeclined()
        for connector in LifeWeavePowerUpStep.connectors {
            recordConnectorResult(connector)
        }
        return finalize(destination: .home)
    }

    /// Stops Home nagging about a choice the user already made.
    ///
    /// `completeCore` resets the Home card's dismissal so a genuinely
    /// interrupted setup can be resumed — but somebody who tapped "Start now",
    /// or "Not now" on all three connectors, has *finished*: they declined. The
    /// resume card exists for interruption, and showing it here would answer a
    /// decision with the same question again.
    func suppressHomeCardIfEverythingWasDeclined() {
        let declined = draft.resolvedDeferredPowerUps
        guard LifeWeavePowerUpStep.connectors.allSatisfy(declined.contains) else { return }
        SetupCenterHomeCardPreference.dismiss()
    }

    /// Back inside the phase. Never into a resolved system prompt.
    var previousPowerUpStep: LifeWeavePowerUpStep? {
        switch draft.powerUpStep {
        case .health: .calendar
        case .eva: .health
        // `.calendar` has the reveal behind it, which is a commit boundary, and
        // `.complete` has a resolved system prompt behind it.
        case .calendar, .complete, .none: nil
        }
    }

    func goBackInPowerUp() {
        guard let previous = previousPowerUpStep, let current = draft.powerUpStep else { return }
        Task {
            await ProductTelemetry.shared.record(
                .onboardingBack,
                flowVersion: AppOnboardingState.currentVersion,
                outcome: "powerup_\(current.identifierSuffix)"
            )
        }
        setPowerUpStep(previous, from: current)
    }

    // MARK: - Unified navigation

    /// One back affordance for both phases, so the shell does not have to know
    /// which axis it is on.
    var canGoBackInFlow: Bool {
        switch draft.route {
        case .core: previousStep != nil
        case .powerUp: previousPowerUpStep != nil
        }
    }

    func goBackInFlow() {
        switch draft.route {
        case .core: goBack()
        case .powerUp: goBackInPowerUp()
        }
    }

    // MARK: - Internals

    /// A short, content-free token for how a connector actually ended.
    ///
    /// Deliberately not the user-facing status copy: that is written to be read
    /// by a person and would drag calendar names, metric counts, and error text
    /// into telemetry. These tokens carry the shape of the outcome and nothing
    /// about the person's data.
    func connectorOutcomeToken(for connector: LifeWeavePowerUpStep) -> String {
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
            case .partial: return "attention"
            case .protectedDataLocked: return "locked"
            case .unavailable: return "unavailable"
            case .notRequested: return "not_started"
            }
        case .eva:
            if evaPrefersOffline { return "offline" }
            return draft.evaCloudReady ? "ready" : "not_started"
        case .complete:
            return "n_a"
        }
    }

    private func recordConnectorResult(_ connector: LifeWeavePowerUpStep) {
        guard connector.connectorIndex != nil else { return }
        let outcome = "\(connector.identifierSuffix)_\(connectorOutcomeToken(for: connector))"
        Task {
            await ProductTelemetry.shared.record(
                .connectorResult,
                flowVersion: AppOnboardingState.currentVersion,
                outcome: outcome
            )
        }
    }

    private func setPowerUpStep(_ step: LifeWeavePowerUpStep, from previous: LifeWeavePowerUpStep) {
        // Recorded on the way out, when the connector's outcome is settled.
        recordConnectorResult(previous)
        mutateDraft { $0.powerUpStep = step }
        MotionDiagnosticsState.shared.record("onboarding:powerup:\(step.identifierSuffix)")
        feedback.light()
        Task {
            await ProductTelemetry.shared.record(
                .onboardingStepCompleted,
                flowVersion: AppOnboardingState.currentVersion,
                outcome: "powerup_\(previous.identifierSuffix)"
            )
            await ProductTelemetry.shared.record(
                .onboardingStepViewed,
                flowVersion: AppOnboardingState.currentVersion,
                outcome: "powerup_\(step.identifierSuffix)"
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
        case .eva, .complete: break
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
