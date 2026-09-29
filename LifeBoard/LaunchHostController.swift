import UIKit
import SwiftUI

/// Keeps seeded UI journeys deterministic without delaying or changing production launch.
final class UITestSeedGateViewController: UIViewController {
    private let progress = UIActivityIndicatorView(style: .medium)
    private var installed = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = SemanticColorTokens.foundationCanvas
        progress.translatesAutoresizingMaskIntoConstraints = false
        progress.startAnimating()
        progress.accessibilityLabel = String(localized: "Loading…")
        view.addSubview(progress)
        NSLayoutConstraint.activate([
            progress.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            progress.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    func install(_ controller: UIViewController) {
        guard installed == false else { return }
        installed = true
        loadViewIfNeeded()
        addChild(controller)
        controller.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(controller.view)
        NSLayoutConstraint.activate([
            controller.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            controller.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            controller.view.topAnchor.constraint(equalTo: view.topAnchor),
            controller.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        controller.didMove(toParent: self)
        progress.stopAnimating()
        progress.removeFromSuperview()
    }
}

final class LaunchHostController: UIViewController {
    private let resolveHomeRootController: () -> UIViewController?

    private var hasScheduledHomeAttach = false
    private var pendingHomeController: UIViewController?
    private var attachedHomeController: UIViewController?
    private let splashState = LaunchSplashState()
    private var splashHostController: UIHostingController<LaunchSplashView>?

    init(resolveHomeRootController: @escaping () -> UIViewController?) {
        self.resolveHomeRootController = resolveHomeRootController
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupSplash()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        scheduleHomeAttachIfNeeded()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        attachHomeIfPossible()
    }

    private func setupSplash() {
        view.backgroundColor = ThemeStore.shared.currentTheme.tokens.color.bgCanvas

        let splashHostController = UIHostingController(
            rootView: LaunchSplashView(
                state: splashState,
                runtime: (UIApplication.shared.delegate as? AppDelegate)?.appRuntime
            )
        )
        splashHostController.view.backgroundColor = .clear
        splashHostController.view.translatesAutoresizingMaskIntoConstraints = false

        addChild(splashHostController)
        view.addSubview(splashHostController.view)
        NSLayoutConstraint.activate([
            splashHostController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            splashHostController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            splashHostController.view.topAnchor.constraint(equalTo: view.topAnchor),
            splashHostController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        splashHostController.didMove(toParent: self)
        self.splashHostController = splashHostController
    }

    private func scheduleHomeAttachIfNeeded() {
        guard hasScheduledHomeAttach == false else { return }
        hasScheduledHomeAttach = true

        let firstFrameInterval = PerformanceTrace.begin("LaunchHostFirstFrame")
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            PerformanceTrace.end(firstFrameInterval)
            self.refreshPendingHomeController()
        }
    }

    func refreshPendingHomeController() {
        guard attachedHomeController == nil else { return }
        pendingHomeController = resolveHomeRootController()
        attachHomeIfPossible()
    }

    private func attachHomeIfPossible() {
        guard attachedHomeController == nil else { return }
        guard let homeController = pendingHomeController else { return }
        guard view.bounds.width > 1, view.bounds.height > 1 else { return }

        let interval = PerformanceTrace.begin("LaunchHostAttachHome")
        addChild(homeController)
        homeController.view.translatesAutoresizingMaskIntoConstraints = false
        homeController.view.alpha = 1
        if let splashView = splashHostController?.view {
            view.insertSubview(homeController.view, belowSubview: splashView)
        } else {
            view.addSubview(homeController.view)
        }
        NSLayoutConstraint.activate([
            homeController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            homeController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            homeController.view.topAnchor.constraint(equalTo: view.topAnchor),
            homeController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        homeController.didMove(toParent: self)
        PerformanceTrace.end(interval)
        attachedHomeController = homeController
        pendingHomeController = nil
        completeSplashOverAttachedHome()
    }

    private func completeSplashOverAttachedHome() {
        guard let splashHostController else { return }

        if MotionOverride.effectiveReduceMotion {
            fadeSplashOverAttachedHome(duration: 0.12, delay: 0)
            return
        }

        let revealDuration = Self.consumeRevealDuration()
        splashState.completeReveal(duration: revealDuration)
        fadeSplashOverAttachedHome(
            duration: LaunchSplashMetrics.finalCrossfadeDuration,
            delay: max(
                revealDuration
                    - LaunchSplashMetrics.finalCrossfadeDuration,
                0
            ),
            splashHostController: splashHostController
        )
    }

    private static let fullRevealShownKey = "launch.splash.fullRevealShown"

    /// The full zoom once, on the first launch; the short one afterwards.
    private static func consumeRevealDuration() -> TimeInterval {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: fullRevealShownKey) else {
            defaults.set(true, forKey: fullRevealShownKey)
            return LaunchSplashMetrics.revealDuration
        }
        return LaunchSplashMetrics.warmRevealDuration
    }

    private func fadeSplashOverAttachedHome(
        duration: TimeInterval,
        delay: TimeInterval,
        splashHostController: UIHostingController<LaunchSplashView>? = nil
    ) {
        let splashHostController = splashHostController ?? self.splashHostController
        guard let splashHostController else { return }

        UIView.animate(
            withDuration: duration,
            delay: delay,
            options: [.allowUserInteraction, .beginFromCurrentState, .curveEaseOut]
        ) {
            splashHostController.view.alpha = 0
        } completion: { [weak self, weak splashHostController] _ in
            guard let self, let splashHostController else { return }
            self.removeSplashHostController(splashHostController)
        }
    }

    private func removeSplashHostController(
        _ splashHostController: UIHostingController<LaunchSplashView>
    ) {
        splashHostController.willMove(toParent: nil)
        splashHostController.view.removeFromSuperview()
        splashHostController.removeFromParent()
        if self.splashHostController === splashHostController {
            self.splashHostController = nil
        }
    }
}
