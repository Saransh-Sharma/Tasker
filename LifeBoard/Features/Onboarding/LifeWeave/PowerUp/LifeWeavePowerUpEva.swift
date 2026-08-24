import Foundation

/// Eva power-up behaviour, as an extension on the one journey model.
///
/// A separate file rather than a separate model: the journey has one owner, and
/// splitting by connector here is only so three people can work at once without
/// editing the same 400 lines. Canonical Eva truth stays in its own service.
///
/// Every line below is a thin wrapper over `EvaCloudAccessCoordinator`. Guest
/// bootstrap, App Attest, age eligibility, consent revisions, quota, and Apple
/// recovery are all resumable single-flight work owned by that coordinator —
/// several of the calls behind it spend a single-use token or a
/// compare-and-swap, so a second entry point here would burn one. The journey
/// decides *when* to ask; it never decides *how* to connect.
@MainActor
extension LifeWeaveOnboardingModel {

    private var evaAccess: EvaCloudAccessCoordinator { .shared }

    /// The stored choice, read the same way Setup Center reads it, so the two
    /// screens can never disagree about whether this device is on Cloud EVA.
    var evaPrefersOffline: Bool {
        EvaProviderRouter.Preference.resolvedStoredPreference() == .offline
    }

    // MARK: - Dock seam

    /// The dock's one dominant verb, named for what will actually happen.
    ///
    /// A single fixed "Enable Cloud EVA" was wrong in five of the seven states:
    /// after a network failure it re-ran activation from scratch, and after
    /// success it offered to do again what was already done.
    var evaPrimaryTitle: String {
        if evaPrefersOffline { return "Continue" }
        switch evaAccess.state {
        case .hydrating, .needsDisclosure: return "Enable Cloud EVA"
        // Disabled while in flight, so it reports rather than invites.
        case .activating: return "Connecting…"
        case .ready: return "Continue"
        case .temporarilyUnavailable: return "Retry Cloud EVA"
        case .appleReauthenticationRequired: return "Reconnect with Apple"
        case .quotaExhausted, .ageBlocked: return "Use Offline EVA"
        }
    }

    /// "Not now" everywhere a decision is still open.
    ///
    /// Nil once EVA is ready: there is nothing left to defer, and offering to
    /// skip a finished connection reads as an undo that it is not. During
    /// activation it becomes "Finish later" — see `performEvaSecondary()`.
    var evaSecondaryTitle: String? {
        if evaPrefersOffline { return nil }
        switch evaAccess.state {
        case .ready: return nil
        case .activating: return "Finish later"
        case .hydrating, .needsDisclosure, .temporarilyUnavailable,
             .quotaExhausted, .ageBlocked, .appleReauthenticationRequired:
            return "Not now"
        }
    }

    /// Disabled only while the coordinator is genuinely in flight. Offline is
    /// never in flight, so its "Continue" always works.
    var isEvaPrimaryDisabled: Bool {
        evaPrefersOffline == false && evaAccess.isWorking
    }

    func performEvaPrimary() async {
        guard evaPrefersOffline == false else {
            finishWithOfflineEva()
            return
        }
        switch evaAccess.state {
        case .needsDisclosure, .hydrating:
            await activateCloudEva()
        case .temporarilyUnavailable:
            await retryCloudEva()
        case .appleReauthenticationRequired:
            await reconnectAppleForEva()
        case .quotaExhausted, .ageBlocked:
            // Never a silent fallback: this is only reached because the user
            // tapped a button that says "Use Offline EVA".
            chooseOfflineEva()
        case .ready:
            recordEvaActivation(ready: true, pending: false)
            advancePowerUp()
        case .activating:
            break
        }
    }

    func performEvaSecondary() {
        // Activation is a single-flight task inside the coordinator and cannot
        // be cancelled from here. Rather than offer a "Cancel" that would stop
        // nothing, leaving mid-flight records the attempt as resumable so Setup
        // Center can finish it without asking for consent a second time.
        if evaAccess.state == .activating {
            recordEvaActivation(ready: false, pending: true)
        }
        deferCurrentPowerUp()
    }

    // MARK: - Choosing between cloud and offline

    /// An explicit choice, always. The one thing this screen must never do is
    /// quietly downgrade someone who asked for Cloud EVA.
    func chooseOfflineEva() {
        evaAccess.selectOffline()
        // Publishes through `draft`, which is what re-renders the dock.
        recordEvaActivation(ready: false, pending: false)
        feedback.light()
    }

    func chooseCloudEva() {
        evaAccess.selectCloud()
        // The preference itself lives in defaults and publishes nothing, so the
        // dock would keep rendering the offline verbs until some other write
        // happened to come along. Coming back to cloud is also, literally, no
        // longer deferring EVA — so saying so is both true and the publish.
        mutateDraft { $0.evaDeferred = false }
        feedback.light()
    }

    private func finishWithOfflineEva() {
        // `recordEvaActivation(ready:)` also flips `evaDeferred`, which here
        // means "not on Cloud EVA" rather than "skipped" — the summary and the
        // final destination both key off `evaCloudReady`, and offline is not it.
        recordEvaActivation(ready: false, pending: false)
        advancePowerUp()
    }

    // MARK: - Activation

    private func activateCloudEva() async {
        // Sent explicitly from the draft. The coordinator's own `selectedGrants`
        // defaults to every category when no receipt exists, so inheriting it
        // would consent to categories this screen may never have shown.
        let grants = draft.resolvedEvaGrants
        evaAccess.selectedGrants = grants
        let succeeded = await evaAccess.confirmAndActivate(grants: grants, source: .onboarding)
        recordEvaOutcome(succeeded: succeeded)
    }

    /// Retry is a resume, never a fresh activation.
    ///
    /// `confirmAndActivate` re-saves the receipt and re-enters the bootstrap
    /// chain; several steps in that chain are single-use, so replaying it after
    /// a timeout spends a token that the resumable path would have reused.
    /// The receipt `resumeConfirmedActivation` needs is guaranteed here, because
    /// the only way to reach a retryable failure is through a confirmation that
    /// wrote one.
    private func retryCloudEva() async {
        evaAccess.selectCloud()
        let succeeded = await evaAccess.resumeConfirmedActivation(source: .onboarding)
        recordEvaOutcome(succeeded: succeeded)
    }

    private func reconnectAppleForEva() async {
        let succeeded = await evaAccess.reconnectApple()
        recordEvaOutcome(succeeded: succeeded)
    }

    /// One place decides what the attempt meant for the journey.
    ///
    /// `pending` is not "it failed" — it is "this can be finished later without
    /// asking for consent again", which is true only of the retryable failure.
    /// Quota, age, and a missing Apple session all need something else first.
    private func recordEvaOutcome(succeeded: Bool) {
        var isResumable = false
        if case .temporarilyUnavailable = evaAccess.state { isResumable = true }
        recordEvaActivation(ready: succeeded, pending: succeeded ? false : isResumable)
        if succeeded { feedback.successSignature() }
    }
}
