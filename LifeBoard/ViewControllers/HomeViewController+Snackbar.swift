//
//  HomeViewController+Snackbar.swift
//  LifeBoard
//
//  Move-only HomeViewController decomposition.
//

import UIKit
import SwiftUI
@preconcurrency import Combine
import SwiftData


// MARK: - Snackbar Support

extension HomeViewController {
    /// Executes observeTaskCreatedForSnackbar.
    func observeTaskCreatedForSnackbar() {
        notificationCenter.publisher(for: .taskCreated)
            .receive(on: RunLoop.main)
            .compactMap { $0.object as? TaskDefinition }
            .sink { [weak self] createdTask in
                self?.showTaskCreatedSnackbar(for: createdTask)
            }
            .store(in: &cancellables)
    }

    func observeOnboardingRequests() {
        notificationCenter.publisher(for: .lifeboardStartOnboardingRequested)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.onboardingCoordinator?.restartOnboarding()
                self?.onboardingCoordinator?.drainPendingPresentationIfPossible()
            }
            .store(in: &cancellables)
    }

    /// Executes showTaskCreatedSnackbar.
    func showTaskCreatedSnackbar(for task: TaskDefinition) {
        let taskID = task.id
        showHomeSnackbar(
            data: SnackbarData(
                message: "Task added.",
                actions: [
                    SnackbarAction(title: "Undo") { [weak self] in
                        self?.viewModel?.deleteTask(taskID: taskID) { _ in }
                    }
                ]
            )
        )
    }

    func showHomeSnackbar(message: String) {
        showHomeSnackbar(data: SnackbarData(message: message, actions: []))
    }

    func showHomeSnackbar(data: SnackbarData) {
        guard homeHostingController != nil else { return }

        dismissCurrentHomeSnackbar()

        let snackbar = LifeBoardSnackbar(data: data, onDismiss: {})
        let snackbarVC = UIHostingController(rootView: snackbar)
        snackbarVC.view.backgroundColor = .clear
        snackbarVC.view.translatesAutoresizingMaskIntoConstraints = false

        addChild(snackbarVC)
        view.addSubview(snackbarVC.view)
        NSLayoutConstraint.activate([
            snackbarVC.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            snackbarVC.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            snackbarVC.view.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),
        ])
        snackbarVC.didMove(toParent: self)
        currentSnackbarViewController = snackbarVC

        let dismissWorkItem = DispatchWorkItem { [weak self, weak snackbarVC] in
            guard let self, let snackbarVC, self.currentSnackbarViewController === snackbarVC else { return }
            self.dismissCurrentHomeSnackbar()
        }
        currentSnackbarDismissWorkItem = dismissWorkItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 6.0, execute: dismissWorkItem)
    }

    func dismissCurrentHomeSnackbar() {
        currentSnackbarDismissWorkItem?.cancel()
        currentSnackbarDismissWorkItem = nil
        guard let snackbarVC = currentSnackbarViewController else { return }
        snackbarVC.willMove(toParent: nil)
        snackbarVC.view.removeFromSuperview()
        snackbarVC.removeFromParent()
        currentSnackbarViewController = nil
    }
}
