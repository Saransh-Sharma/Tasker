import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

@MainActor
protocol AppOnboardingHostAdapter: AnyObject {
    var currentOnboardingLayoutClass: LifeBoardLayoutClass { get }
    var presentedViewController: UIViewController? { get }

    func prepareForOnboardingHomeGuidance()
    func present(_ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)?)
    func makeOnboardingAddTaskController(
        prefill: AddTaskPrefillTemplate,
        onTaskCreated: @escaping (UUID) -> Void,
        onDismissWithoutTask: (() -> Void)?
    ) -> UIViewController?
    func makeOnboardingAddHabitController(
        prefill: AddHabitPrefillTemplate,
        onHabitCreated: @escaping (UUID) -> Void,
        onDismissWithoutTask: (() -> Void)?
    ) -> UIViewController?
    func makeOnboardingTaskDetailController(
        task: TaskDefinition,
        onDismiss: @escaping () -> Void
    ) -> UIViewController?
}

/// UIKit composition host for the SwiftUI Life OS root and first-run modals.
/// It contains no Home behavior: its only jobs are child containment and the
/// three UIKit presentations onboarding still requires.
@MainActor
final class LifeBoardApplicationHostController: UIViewController, AppOnboardingHostAdapter {
    private let root: AnyView
    private let presentationDependencies: PresentationDependencyContainer
    private let planDependencies: PlanFeatureDependencies?
    private let router: LifeBoardAppRouter
    private var taskDetailDismissBridges: [ObjectIdentifier: OnboardingTaskDetailDismissBridge] = [:]

    init(
        root: AnyView,
        presentationDependencies: PresentationDependencyContainer,
        planDependencies: PlanFeatureDependencies?,
        router: LifeBoardAppRouter
    ) {
        self.root = root
        self.presentationDependencies = presentationDependencies
        self.planDependencies = planDependencies
        self.router = router
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        let host = UIHostingController(rootView: root)
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

    var currentOnboardingLayoutClass: LifeBoardLayoutClass {
        LifeBoardLayoutResolver.classify(view: view)
    }

    func prepareForOnboardingHomeGuidance() {
        router.select(.home)
    }

    func makeOnboardingAddTaskController(
        prefill: AddTaskPrefillTemplate,
        onTaskCreated: @escaping (UUID) -> Void,
        onDismissWithoutTask: (() -> Void)?
    ) -> UIViewController? {
        let model = presentationDependencies.makeNewAddTaskViewModel()
        model.applyPrefill(prefill)
        let content = SunriseAddTaskSheetView(
            viewModel: model,
            onTaskCreated: onTaskCreated,
            onDismissWithoutTask: onDismissWithoutTask
        )
        let host = UIHostingController(rootView: AnyView(content.lifeboardLayoutClass(currentOnboardingLayoutClass)))
        configureComposerSheet(host)
        return host
    }

    func makeOnboardingAddHabitController(
        prefill: AddHabitPrefillTemplate,
        onHabitCreated: @escaping (UUID) -> Void,
        onDismissWithoutTask: (() -> Void)?
    ) -> UIViewController? {
        let model = presentationDependencies.makeNewAddHabitViewModel()
        model.applyPrefill(prefill)
        let content = SunriseAddHabitSheetView(
            viewModel: model,
            onHabitCreated: onHabitCreated,
            onDismissWithoutHabit: onDismissWithoutTask
        )
        let host = UIHostingController(rootView: AnyView(content.lifeboardLayoutClass(currentOnboardingLayoutClass)))
        configureComposerSheet(host)
        return host
    }

    func makeOnboardingTaskDetailController(
        task: TaskDefinition,
        onDismiss: @escaping () -> Void
    ) -> UIViewController? {
        guard let planDependencies else { return nil }
        let content = NavigationStack {
            FoundationTaskRouteView(id: task.id, dependencies: planDependencies, router: router)
        }
        .lifeboardLayoutClass(currentOnboardingLayoutClass)
        let host = UIHostingController(rootView: AnyView(content))
        host.modalPresentationStyle = currentOnboardingLayoutClass == .phone ? .pageSheet : .formSheet
        if currentOnboardingLayoutClass != .phone {
            host.preferredContentSize = CGSize(width: 540, height: 680)
        }
        let bridge = OnboardingTaskDetailDismissBridge(onDismiss: { [weak self, weak host] in
            if let host { self?.taskDetailDismissBridges[ObjectIdentifier(host)] = nil }
            onDismiss()
        })
        taskDetailDismissBridges[ObjectIdentifier(host)] = bridge
        host.presentationController?.delegate = bridge
        return host
    }

    private func configureComposerSheet<Content: View>(_ host: UIHostingController<Content>) {
        host.modalPresentationStyle = .pageSheet
        if let sheet = host.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.prefersScrollingExpandsWhenScrolledToEdge = false
        }
    }
}
