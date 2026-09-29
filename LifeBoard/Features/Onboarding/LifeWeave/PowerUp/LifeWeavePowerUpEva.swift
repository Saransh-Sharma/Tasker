import Foundation

/// Eva power-up behaviour, as an extension on the one journey model.
///
/// A separate file rather than a separate model: the journey has one owner, and
/// splitting by connector here is only so three people can work at once without
/// editing the same 400 lines. Canonical Eva truth stays in its own service.
///
/// Every line below is a thin wrapper over `EvaCloudAccessCoordinator`. Guest
/// bootstrap, App Attest, consent revisions, quota, and Apple recovery are all
/// resumable single-flight work owned by that coordinator —
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
    /// The primary action follows the current connection state: it advances
    /// while automatic activation continues in the background, retries a
    /// recoverable failure, or opens the explicit Offline path.
    var evaPrimaryTitle: String {
        if evaPrefersOffline { return LifeWeaveCopy.Dock.done }
        switch evaAccess.state {
        case .hydrating, .needsActivation:
            return evaAccess.hasConfirmedCloudConsent
                ? LifeWeaveCopy.Dock.continue
                : String(localized: "Turn on Eva")
        case .activating: return LifeWeaveCopy.Dock.done
        case .ready: return LifeWeaveCopy.Dock.done
        case .temporarilyUnavailable: return String(localized: "Try again")
        case .appleReauthenticationRequired: return String(localized: "Sign in with Apple")
        case .quotaExhausted: return offlineEvaActionTitle
        }
    }

    /// Connection work belongs to the coordinator; onboarding may always continue.
    var isEvaPrimaryDisabled: Bool {
        false
    }

    func performEvaPrimary() async {
        guard evaPrefersOffline == false else {
            finishWithOfflineEva()
            return
        }
        switch evaAccess.state {
        case .needsActivation, .hydrating:
            // Nothing reaches the cloud before the person confirms what EVA
            // may use; the consent sheet records that choice and connects.
            guard evaAccess.hasConfirmedCloudConsent else {
                showsEvaConsent = true
                return
            }
            finishConnector()
            Task { _ = await evaAccess.ensureActivated(source: .onboarding) }
        case .temporarilyUnavailable:
            await retryCloudEva()
        case .appleReauthenticationRequired:
            await reconnectAppleForEva()
        case .quotaExhausted:
            // Never a silent fallback: this is only reached because the user
            // tapped a button that says "Use Offline EVA".
            chooseOfflineEva()
        case .ready:
            recordEvaActivation(ready: true, pending: false)
            finishConnector()
        case .activating:
            recordEvaActivation(ready: false, pending: true)
            finishConnector()
        }
    }

    // MARK: - Choosing between cloud and offline

    /// An explicit choice, always. The one thing this screen must never do is
    /// quietly downgrade someone who asked for Cloud EVA.
    func chooseOfflineEva() {
        guard powerUps.offlineEvaReady() else { showsOfflineSetup = true; return }
        evaAccess.selectOffline()
        // Publishes through `draft`, which is what re-renders the dock.
        recordEvaActivation(ready: false, pending: false)
        feedback.light()
    }

    /// Called by the consent sheet once the person has confirmed.
    func evaConsentFinished(ready: Bool) {
        recordEvaOutcome(succeeded: ready)
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
        finishConnector()
    }

    // MARK: - Activation recovery

    private func retryCloudEva() async {
        evaAccess.selectCloud()
        let succeeded = await evaAccess.ensureActivated(source: .onboarding)
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
    /// Quota and a missing Apple session need a different recovery action.
    private func recordEvaOutcome(succeeded: Bool) {
        var isResumable = false
        if case .temporarilyUnavailable = evaAccess.state { isResumable = true }
        recordEvaActivation(ready: succeeded, pending: succeeded ? false : isResumable)
        if succeeded { feedback.successSignature() }
    }
}
