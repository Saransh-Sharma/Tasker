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

    // MARK: - SwiftUI Hosting

    private func setupSwiftUIHost() {
        let viewModel = SettingsViewModel(appManager: appManager)

        viewModel.onNavigateToProjects = { [weak self] in
            self?.navigateToProjectManagement()
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

        let rootView = SettingsRootView(viewModel: viewModel)
        let hostingController = UIHostingController(rootView: rootView)
        hostingController.view.backgroundColor = .clear

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
        let view = SettingsProjectManagementV2View(viewModel: viewModel)
        let controller = UIHostingController(rootView: view)
        controller.title = "Projects"
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

// MARK: - Project Management View (kept for navigation target)

private struct SettingsProjectManagementV2View: View {
    @ObservedObject var viewModel: ProjectManagementViewModel
    @State private var showingCreateDialog = false
    @State private var newProjectName = ""
    @State private var newProjectDescription = ""

    var body: some View {
        List {
            ForEach(viewModel.filteredProjects, id: \.project.id) { entry in
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.project.name)
                        .font(.headline)
                    if let description = entry.project.projectDescription, description.isEmpty == false {
                        Text(description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Text("\(entry.taskCount) tasks")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .onDelete(perform: deleteProjects)
        }
        .overlay {
            if viewModel.filteredProjects.filter({ $0.project.id != ProjectConstants.inboxProjectID }).isEmpty {
                ContentUnavailableView(
                    "No Custom Projects",
                    systemImage: "folder.badge.plus",
                    description: Text("Tap + to create your first custom project")
                )
            }
        }
        .navigationTitle("Projects")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingCreateDialog = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .alert("New Project", isPresented: $showingCreateDialog) {
            TextField("Project Name", text: $newProjectName)
            TextField("Description (Optional)", text: $newProjectDescription)
            Button("Cancel", role: .cancel) {
                resetDraft()
            }
            Button("Create") {
                let trimmedName = newProjectName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard trimmedName.isEmpty == false else { return }
                viewModel.createProject(name: trimmedName, description: normalizedDescription())
                resetDraft()
            }
        } message: {
            Text("Create a new project under your life areas.")
        }
        .task {
            viewModel.loadProjects()
        }
    }

    private func deleteProjects(at offsets: IndexSet) {
        for index in offsets {
            guard viewModel.filteredProjects.indices.contains(index) else { continue }
            let entry = viewModel.filteredProjects[index]
            guard entry.project.id != ProjectConstants.inboxProjectID else { continue }
            viewModel.deleteProject(entry, strategy: .moveToInbox)
        }
    }

    private func normalizedDescription() -> String? {
        let trimmed = newProjectDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func resetDraft() {
        newProjectName = ""
        newProjectDescription = ""
    }
}
