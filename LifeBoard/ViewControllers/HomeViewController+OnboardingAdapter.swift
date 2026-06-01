//
//  HomeViewController+OnboardingAdapter.swift
//  LifeBoard
//
//  Move-only HomeViewController decomposition.
//

import UIKit
import SwiftUI
@preconcurrency import Combine
import SwiftData


extension HomeViewController {
    func processPendingIPadModalRequest() {
        guard isUsingIPadNativeShell else {
            pendingIPadModalRequest = nil
            resetPendingIPadModalWaitState()
            return
        }
        guard let request = pendingIPadModalRequest else {
            resetPendingIPadModalWaitState()
            return
        }
        if let blockingController = presentedViewController {
            if let presentationController = blockingController.presentationController {
                if presentationController.delegate !== self {
                    pendingIPadModalPreviousPresentationDelegate = presentationController.delegate
                    presentationController.delegate = self
                }
            } else {
                viewModel?.trackHomeInteraction(
                    action: "ipad_modal_request_waiting_for_presented_controller",
                    metadata: ["layout_class": currentLayoutClass.rawValue]
                )
            }
            return
        }

        resetPendingIPadModalWaitState()
        pendingIPadModalRequest = nil
        switch request {
        case .addTask:
            viewModel?.trackHomeInteraction(
                action: "ipad_modal_request_presented",
                metadata: ["layout_class": currentLayoutClass.rawValue]
            )
            presentAddTaskSheetForPadFallback()
        }
    }

    func resetPendingIPadModalWaitState() {
        if let presentationController = presentedViewController?.presentationController,
           presentationController.delegate === self {
            presentationController.delegate = pendingIPadModalPreviousPresentationDelegate
        }
        pendingIPadModalPreviousPresentationDelegate = nil
    }

    func refreshPersistentSyncOutageBanner() {
        if AppDelegate.isWriteClosed {
            showPersistentSyncOutageBanner(
                message: "Sync unavailable, read-only mode. Recover from iCloud to resume edits."
            )
        } else {
            hidePersistentSyncOutageBanner()
        }
    }

    func showPersistentSyncOutageBanner(message: String) {
        if syncOutageBanner == nil {
            let banner = UIView()
            banner.translatesAutoresizingMaskIntoConstraints = false
            banner.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.18)
            banner.layer.cornerRadius = 10
            banner.layer.masksToBounds = true

            let label = UILabel()
            label.translatesAutoresizingMaskIntoConstraints = false
            label.font = .systemFont(ofSize: 13, weight: .semibold)
            label.textColor = .label
            label.numberOfLines = 2
            label.textAlignment = .center

            banner.addSubview(label)
            view.addSubview(banner)

            let topConstraint = banner.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8)
            let leadingConstraint = banner.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12)
            let trailingConstraint = banner.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12)
            let heightConstraint = banner.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)

            NSLayoutConstraint.activate([
                topConstraint,
                leadingConstraint,
                trailingConstraint,
                heightConstraint,
                label.leadingAnchor.constraint(equalTo: banner.leadingAnchor, constant: 12),
                label.trailingAnchor.constraint(equalTo: banner.trailingAnchor, constant: -12),
                label.topAnchor.constraint(equalTo: banner.topAnchor, constant: 8),
                label.bottomAnchor.constraint(equalTo: banner.bottomAnchor, constant: -8)
            ])

            syncOutageBanner = banner
            syncOutageLabel = label
        }

        syncOutageLabel?.text = message
        syncOutageBanner?.isHidden = false
        syncOutageBanner?.alpha = 1
    }

    func hidePersistentSyncOutageBanner() {
        syncOutageBanner?.isHidden = true
        syncOutageBanner?.alpha = 0
    }

    func consumeUITestInjectedRouteIfNeeded() {
        launchHarnessService.consumeUITestInjectedRouteIfNeeded { [weak self] route in
            self?.navigationCoordinator.handle(.notificationRoute(route))
        }
    }

    func consumeUITestOpenSettingsIfNeeded() {
        launchHarnessService.consumeUITestOpenSettingsIfNeeded(
            canOpenSettings: { [weak self] in
                self?.presentedViewController == nil
            }
        ) { [weak self] in
            guard let self, self.presentedViewController == nil else { return }
            self.onMenuButtonTapped()
        }
    }

    var currentOnboardingLayoutClass: LifeBoardLayoutClass {
        currentLayoutClass
    }

    func prepareForOnboardingHomeGuidance() {
        if isUsingIPadNativeShell {
            iPadShellState.destination = .tasks
        }
    }

    func makeOnboardingAddTaskController(
        prefill: AddTaskPrefillTemplate,
        onTaskCreated: @escaping (UUID) -> Void,
        onDismissWithoutTask: (() -> Void)? = nil
    ) -> UIViewController? {
        guard let presentationDependencyContainer else {
            return nil
        }
        let viewModel = presentationDependencyContainer.makeNewAddTaskViewModel()
        viewModel.applyPrefill(prefill)
        let sheet = SunriseAddTaskSheetView(
            viewModel: viewModel,
            onTaskCreated: onTaskCreated,
            onDismissWithoutTask: onDismissWithoutTask
        )
        let hostingController = UIHostingController(rootView: AnyView(sheet.lifeboardLayoutClass(currentLayoutClass)))
        hostingController.modalPresentationStyle = .pageSheet
        if let sheetController = hostingController.sheetPresentationController {
            sheetController.detents = [.medium(), .large()]
            sheetController.prefersGrabberVisible = true
            sheetController.prefersScrollingExpandsWhenScrolledToEdge = false
        }
        return hostingController
    }

    func makeOnboardingAddHabitController(
        prefill: AddHabitPrefillTemplate,
        onHabitCreated: @escaping (UUID) -> Void,
        onDismissWithoutTask: (() -> Void)? = nil
    ) -> UIViewController? {
        guard let presentationDependencyContainer else {
            return nil
        }
        let habitViewModel = presentationDependencyContainer.makeNewAddHabitViewModel()
        habitViewModel.applyPrefill(prefill)
        let sheet = SunriseAddHabitSheetView(
            viewModel: habitViewModel,
            onHabitCreated: onHabitCreated,
            onDismissWithoutHabit: onDismissWithoutTask
        )
        let hostingController = UIHostingController(rootView: AnyView(sheet.lifeboardLayoutClass(currentLayoutClass)))
        hostingController.modalPresentationStyle = .pageSheet
        if let sheetController = hostingController.sheetPresentationController {
            sheetController.detents = [.medium(), .large()]
            sheetController.prefersGrabberVisible = true
            sheetController.prefersScrollingExpandsWhenScrolledToEdge = false
        }
        return hostingController
    }

    func makeOnboardingTaskDetailController(
        task: TaskDefinition,
        onDismiss: @escaping () -> Void
    ) -> UIViewController? {
        let detailView = makeTaskDetailView(for: task, containerMode: .sheet)
        let hostingController = UIHostingController(rootView: AnyView(detailView.lifeboardLayoutClass(currentLayoutClass)))
        hostingController.view.backgroundColor = LifeBoardThemeManager.shared.currentTheme.tokens.color.bgCanvas

        if isUsingIPadNativeShell {
            switch currentLayoutClass {
            case .padCompact, .padRegular, .padExpanded:
                hostingController.modalPresentationStyle = .formSheet
                hostingController.preferredContentSize = CGSize(width: 540, height: 680)
                if let sheet = hostingController.sheetPresentationController {
                    sheet.detents = [.large()]
                    sheet.preferredCornerRadius = LifeBoardThemeManager.shared.currentTheme.tokens.corner.modal
                    sheet.prefersScrollingExpandsWhenScrolledToEdge = false
                }
            case .phone:
                hostingController.modalPresentationStyle = .pageSheet
            }
        } else {
            hostingController.modalPresentationStyle = .pageSheet
            if let sheet = hostingController.sheetPresentationController {
                sheet.detents = [.medium(), .large()]
                sheet.preferredCornerRadius = LifeBoardThemeManager.shared.currentTheme.tokens.corner.modal
                sheet.prefersScrollingExpandsWhenScrolledToEdge = true
            }
        }

        let dismissBridge = OnboardingTaskDetailDismissBridge(onDismiss: onDismiss)
        hostingController.presentationController?.delegate = dismissBridge
        objc_setAssociatedObject(
            hostingController,
            &onboardingTaskDetailDismissBridgeKey,
            dismissBridge,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        return hostingController
    }
}
