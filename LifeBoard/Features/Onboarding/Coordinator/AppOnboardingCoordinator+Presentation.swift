import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

extension AppOnboardingCoordinator {
    /// The controller onboarding should actually present from.
    ///
    /// The native application host is the normal anchor. The topmost fallback
    /// keeps queued onboarding presentation correct while another canonical
    /// route is dismissing or the scene is restoring its hierarchy.
    var presentationAnchor: UIViewController? {
        if let hostAdapter, hostAdapter.viewIfLoaded?.window != nil {
            return hostAdapter
        }
        guard let root = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController
        else { return hostAdapter }
        var topmost = root
        while let presented = topmost.presentedViewController, presented !== onboardingHost {
            topmost = presented
        }
        return topmost
    }

    func evaluateLaunchIfNeeded() {
        guard hasEvaluatedLaunch == false else { return }
        hasEvaluatedLaunch = true

        Task { @MainActor [weak self] in
            guard let self else { return }
            // Checked before the resume branch: resuming an interrupted journey
            // short-circuits ahead of `evaluate()`, which is where the skip
            // argument is otherwise honored. A seeded run that had stored a
            // partial journey therefore presented onboarding anyway, making
            // `-SKIP_ONBOARDING` runs unreliable after a partial setup.
            guard self.eligibilityService.isSuppressedByLaunchArgument == false else { return }

            let state = self.stateStore.load()
            if state.hasHandledCurrentVersion == false, state.lifeMapJourneySnapshot != nil {
                self.enqueuePresentation(.fullFlow(source: "resume"))
                return
            }
            switch await self.eligibilityService.evaluate() {
            case .fullFlow:
                self.enqueuePresentation(.fullFlow(source: "launch_auto"))
            case .promptOnly:
                // Deliberately not `enqueuePresentation(.prompt(...))`. An
                // established user opening the app asked for their workspace,
                // not for a setup flow; the invitation waits on Home until they
                // want it, and the permanent entry is the Life Map card in
                // Life Management.
                self.guidanceModel.showLifeMapInvitation()
            case .suppressed:
                break
            }
        }
    }

    func restartOnboarding() {
        stateStore.clear()
        guidanceModel.clear()
        presentationQueue = OnboardingPresentationQueue()
        enqueuePresentation(.fullFlow(source: "settings_replay"))
    }

    func drainPendingPresentationIfPossible() {
        guard let pending = presentationQueue.pending else { return }
        if attemptPresentation(pending, source: "drain") {
            presentationQueue.markPresented(pending)
        }
    }

    func enqueuePresentation(_ presentation: PendingOnboardingPresentation) {
        let previousPending = presentationQueue.pending
        presentationQueue.enqueue(presentation)
        let currentPending = presentationQueue.pending

        if currentPending == presentation,
           previousPending != presentation,
           isPresentationBlocked() {
            pendingPresentationWasBlocked = true
            logOnboardingInfo(
                event: "onboarding_presentation_queued",
                message: "Queued onboarding presentation until the host is free",
                fields: [
                    "presentation": presentation.analyticsLabel,
                    "blocked_by_presented_controller": String(presentationAnchor?.presentedViewController != nil)
                ]
            )
        }

        drainPendingPresentationIfPossible()
    }

    @discardableResult
    func attemptPresentation(_ presentation: PendingOnboardingPresentation, source: String) -> Bool {
        let presented: Bool
        switch presentation {
        case .fullFlow(let sourceLabel):
            presented = presentFullFlowIfPossible(source: sourceLabel)
        }

        if presented, pendingPresentationWasBlocked {
            pendingPresentationWasBlocked = false
            logOnboardingInfo(
                event: "onboarding_presentation_drained",
                message: "Presented queued onboarding surface",
                fields: [
                    "presentation": presentation.analyticsLabel,
                    "source": source
                ]
            )
        }
        return presented
    }

    func presentFullFlowIfPossible(source: String) -> Bool {
        guard onboardingHost == nil else { return false }
        guard let hostAdapter else { return false }
        guard let anchor = presentationAnchor, anchor.presentedViewController == nil else { return false }

        feedbackController.prepare()
        let entryContext: OnboardingEntryContext = source == "settings_replay" || source == "life_map_refresh"
            ? .establishedWorkspace : .freshFlow
        lifeMapModel.prepareForPresentation(
            snapshot: stateStore.load().lifeMapJourneySnapshot,
            entryContext: entryContext
        )
        logOnboardingInfo(
            event: "onboarding_started",
            message: "Started Life Map onboarding flow",
            fields: ["source": source]
        )

        let rootView = LifeMapOnboardingView(
            model: self.lifeMapModel,
            onDismissFlow: { [weak self] in
                guard let self else { return }
                self.dismissFullFlow(animated: true)
            }
        )
        .lifeBoardTokenEnvironment(for: hostAdapter.currentOnboardingLayoutClass)
        // Mandatory, not decorative. This hosting controller is presented from
        // UIKit and inherits none of `FoundationShell`'s environment, so
        // without its own resolution the flow would read the default motion
        // context and a permanently-false shader readiness — which is exactly
        // why the onboarding view already hand-bridges `\.scenePhase`.
        .lifeBoardResolvedMotion(
            comfortProfile: FoundationCoordinator.shared.preferences.comfortProfile,
            requestedAmbientTierID: FoundationCoordinator.shared.preferences.renderingTier.rawValue
        )

        let controller = UIHostingController(rootView: AnyView(rootView))
        controller.modalPresentationStyle = .fullScreen
        onboardingHost = controller
        anchor.present(controller, animated: true, completion: nil)
        return true
    }

    func dismissFullFlow(animated: Bool, completion: (() -> Void)? = nil) {
        guard let onboardingHost else {
            completion?()
            return
        }
        self.onboardingHost = nil
        onboardingHost.dismiss(animated: animated, completion: completion)
    }

    func isPresentationBlocked() -> Bool {
        presentationAnchor?.presentedViewController != nil
    }
}
