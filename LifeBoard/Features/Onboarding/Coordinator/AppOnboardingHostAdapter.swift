import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

@MainActor
protocol AppOnboardingHostAdapter: AnyObject {
    var currentOnboardingLayoutClass: LayoutClass { get }
    var presentedViewController: UIViewController? { get }

    func prepareForOnboardingHomeGuidance()
    func present(_ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)?)
}

/// UIKit composition host for the SwiftUI Life OS root.
///
/// It contains no Home behavior; its only job is child containment. The three
/// `makeOnboarding*Controller` factories that used to live here — add-task,
/// add-habit, and task-detail — went with the nine-step flow: the Life Map flow
/// creates at most one record, through the reviewed capture, and never presents
/// a UIKit composer.
@MainActor
final class ApplicationHostController: UIViewController, AppOnboardingHostAdapter {
    private let root: AnyView
    private let presentationDependencies: CompositionRoot
    private let router: AppRouter

    init(
        root: AnyView,
        presentationDependencies: CompositionRoot,
        router: AppRouter
    ) {
        self.root = root
        self.presentationDependencies = presentationDependencies
        self.router = router
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        let host = UIHostingController(rootView: root)
        // The one place a high-contrast *trait* can actually be forced.
        //
        // `\.colorSchemeContrast` is read-only in SwiftUI, so the appearance
        // fixture could previously only fake it with `.contrast(1.16)` — a
        // post-render filter that multiplies the finished image and never sets
        // `UITraitCollection.accessibilityContrast`. That is the value every
        // `adaptive(...)` token provider branches on, so the `high-contrast-*`
        // fixtures had never once exercised a high-contrast token, including the
        // `strokeHairline` values added specifically to fix separator
        // visibility under that setting.
        if VisualAppearanceFixture.active?.usesHighContrast == true {
            host.traitOverrides.accessibilityContrast = .high
        }
        addChild(host)
        view.addSubview(host.view)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        host.didMove(toParent: self)
    }

    var currentOnboardingLayoutClass: LayoutClass {
        LayoutResolver.classify(view: view)
    }

    func prepareForOnboardingHomeGuidance() {
        router.select(.home)
    }

}
