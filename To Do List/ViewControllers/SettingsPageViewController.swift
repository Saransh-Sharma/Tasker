//
//  SettingsPageViewController.swift
//  To Do List
//
//  Created by Saransh Sharma on 26/04/20.
//  Copyright © 2020 saransh1337. All rights reserved.
//

import UIKit
import SwiftUI
import Combine

class SettingsPageViewController: UIViewController, PresentationDependencyContainerAware {

    // MARK: - Dependencies

    let appManager = AppManager()
    let llmEvaluator = LLMRuntimeCoordinator.shared.evaluator
    var presentationDependencyContainer: PresentationDependencyContainer?

    private var settingsViewModel: SettingsViewModel?
    private var themeCancellable: AnyCancellable?
    private var settingsHostingController: UIHostingController<AnyView>?
    private var currentLayoutClass: TaskerLayoutClass = .phone

    // MARK: - Backdrop compatibility properties (needed for SettingsBackdrop.swift)
    var backdropContainer = UIView()
    var headerEndY: CGFloat = 128
    var backdropBackgroundImageView = UIImageView()
    var homeTopBar = UIView()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        view.accessibilityIdentifier = "settings.view"

        self.title = "Settings"
        let doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneTapped))
        doneButton.accessibilityIdentifier = "settings.doneButton"
        self.navigationItem.rightBarButtonItem = doneButton

        setupSwiftUIHost()

        themeCancellable = TaskerThemeManager.shared.publisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.applyTheme()
            }

        applyTheme()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        settingsViewModel?.reload()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        refreshLayoutClassIfNeeded()
    }

    // MARK: - SwiftUI Hosting

    private func setupSwiftUIHost() {
        let viewModel = SettingsViewModel(appManager: appManager)

        viewModel.onNavigateToLifeManagement = { [weak self] in
            self?.navigateToLifeManagement()
        }
        viewModel.onNavigateToChats = { [weak self] in
            self?.navigateToLLMChatsSettings()
        }
        viewModel.onNavigateToModels = { [weak self] in
            self?.navigateToLLMModelsSettings()
        }
        viewModel.onDismiss = { [weak self] in
            self?.doneTapped()
        }

        self.settingsViewModel = viewModel

        currentLayoutClass = TaskerLayoutResolver.classify(view: view)
        let rootView = AnyView(
            SettingsRootView(viewModel: viewModel)
                .taskerLayoutClass(currentLayoutClass)
        )
        let hostingController = UIHostingController(rootView: rootView)
        hostingController.view.backgroundColor = .clear
        settingsHostingController = hostingController

        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        hostingController.didMove(toParent: self)
    }

    private func refreshLayoutClassIfNeeded() {
        let nextLayoutClass = TaskerLayoutResolver.classify(view: view)
        guard nextLayoutClass != currentLayoutClass else { return }
        currentLayoutClass = nextLayoutClass
        guard let settingsViewModel else { return }
        settingsHostingController?.rootView = AnyView(
            SettingsRootView(viewModel: settingsViewModel)
                .taskerLayoutClass(nextLayoutClass)
        )
    }

    // MARK: - Actions

    @objc func doneTapped() {
        self.dismiss(animated: true, completion: nil)
    }

    // MARK: - Navigation

    private func navigateToLLMChatsSettings() {
        let view = ChatsSettingsView(currentThread: .constant(nil))
            .environmentObject(appManager)
            .environment(llmEvaluator)
        let vc = UIHostingController(rootView: view)
        vc.title = "Chats"
        self.navigationController?.pushViewController(vc, animated: true)
    }

    private func navigateToLLMModelsSettings() {
        let view = ModelsSettingsView()
            .environmentObject(appManager)
            .environment(llmEvaluator)
        let vc = UIHostingController(rootView: view)
        vc.title = "Models"
        self.navigationController?.pushViewController(vc, animated: true)
    }

    private func navigateToProjectManagement() {
        guard let presentationDependencyContainer else {
            assertionFailure("SettingsPageViewController requires injected PresentationDependencyContainer")
            return
        }
        let viewModel = presentationDependencyContainer.makeProjectManagementViewModel()
        let view = ProjectManagementView(viewModel: viewModel)
        let controller = UIHostingController(rootView: view)
        controller.title = "Projects"
        navigationController?.pushViewController(controller, animated: true)
    }

    private func navigateToLifeManagement() {
        guard let presentationDependencyContainer else {
            assertionFailure("SettingsPageViewController requires injected PresentationDependencyContainer")
            return
        }
        let viewModel = presentationDependencyContainer.makeLifeManagementViewModel()
        let view = LifeManagementView(viewModel: viewModel)
        let controller = UIHostingController(rootView: view)
        controller.title = "Life Management"
        navigationController?.pushViewController(controller, animated: true)
    }

    // MARK: - Theme

    private func applyTheme() {
        let colors = TaskerThemeManager.shared.currentTheme.tokens.color
        view.tintColor = colors.accentPrimary
        view.backgroundColor = colors.bgCanvas
    }

    // MARK: - Status Bar

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
}
