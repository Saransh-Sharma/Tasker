//
//  ChatHostViewController.swift
//  To Do List
//
//  Hosts the SwiftUI chat/onboarding UI for the local-LLM feature.
//  If no model is installed, shows onboarding to guide download. Otherwise presents Chat UI.
//

import UIKit
import SwiftUI
import SwiftData
import FluentUI






/// UIKit wrapper that embeds the SwiftUI LLM module.
extension Notification.Name {
    static let toggleChatHistory = Notification.Name("toggleChatHistory")
}

class ChatHostViewController: UIViewController {
    private let appManager = AppManager()
    private let llmEvaluator = LLMEvaluator()
    // Shared SwiftData container for the LLM module (persistent on-disk, CloudKit disabled)
    private let container: ModelContainer = LLMDataController.shared

    private var hostingController: UIHostingController<AnyView>!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        // Root SwiftUI view that decides what to present.
        let rootView = ChatContainerView()
            .environmentObject(appManager)
            .environment(llmEvaluator)
            .modelContainer(container)

        hostingController = UIHostingController(rootView: AnyView(rootView))
        addChild(hostingController)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hostingController.view)
        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        hostingController.didMove(toParent: self)
        // Configure FluentUI navigation bar
        setupFluentNavigationBar()

        // Observe theme changes to update navigation bar color
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(themeChanged),
            name: .themeChanged,
            object: nil
        )
    }
    // MARK: - FluentUI Navigation Bar Setup
    private func setupFluentNavigationBar() {
        // Configure navigation bar appearance using standard iOS APIs
        title = "Chat"

        // Set FluentUI custom navigation bar color - this is the correct way to set color with FluentUI
        let todoColors = ToDoColors()
        navigationItem.fluentConfiguration.customNavigationBarColor = todoColors.primaryColor
        navigationItem.fluentConfiguration.navigationBarStyle = .custom

        // Configure navigation bar appearance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = todoColors.primaryColor
        appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]

        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.compactAppearance = appearance
        navigationController?.navigationBar.prefersLargeTitles = true

        // Left: Back button
        let backButton = UIBarButtonItem(
            image: UIImage(systemName: "chevron.backward"),
            style: .plain,
            target: self,
            action: #selector(onBackTapped)
        )
        backButton.accessibilityLabel = "Back"
        navigationItem.leftBarButtonItem = backButton

        // Right: History button
        let historyButton = UIBarButtonItem(
            image: UIImage(systemName: "text.below.folder"),
            style: .plain,
            target: self,
            action: #selector(onHistoryTapped)
        )
        historyButton.accessibilityLabel = "History"
        navigationItem.rightBarButtonItem = historyButton
    }

    @objc private func onBackTapped() {
        dismiss(animated: true)
    }

    @objc private func onHistoryTapped() {
        NotificationCenter.default.post(name: .toggleChatHistory, object: nil)
    }

    // MARK: - Theme Handling

    @objc private func themeChanged() {
        let todoColors = ToDoColors()
        navigationItem.fluentConfiguration.customNavigationBarColor = todoColors.primaryColor
        navigationItem.fluentConfiguration.navigationBarStyle = .custom
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - SwiftUI container deciding between onboarding and chat

private struct ChatContainerView: View {
    @EnvironmentObject var appManager: AppManager
    @Environment(LLMEvaluator.self) var llm

    @State private var currentThread: Thread? = nil
    @FocusState private var isPromptFocused: Bool
    @State private var showChats = false
    @State private var showSettings = false
    @State private var showOnboarding = true

    var body: some View {
        Group {
            if appManager.installedModels.isEmpty {
                // Show onboarding until at least one model is installed
                OnboardingView(showOnboarding: $showOnboarding)
                    .onChange(of: appManager.installedModels) { _ in
                        // Refresh UI when a model gets installed
                        showOnboarding = false
                    }
            } else {
                // Present main chat UI
                ChatView(
                    currentThread: $currentThread,
                    isPromptFocused: $isPromptFocused,
                    showChats: $showChats,
                    showSettings: $showSettings
                )
            }
        }
        .environmentObject(appManager)
        .environment(llm)
        .ignoresSafeArea()
        // Present chat history list when showChats toggled (iPhone)
        .sheet(isPresented: $showChats) {
            ChatsListView(currentThread: $currentThread, isPromptFocused: $isPromptFocused)
                .environmentObject(appManager)
                #if os(iOS)
                .presentationDragIndicator(.hidden)
                .presentationDetents(appManager.userInterfaceIdiom == .phone ? [.medium, .large] : [.large])
            #endif
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleChatHistory)) { _ in
            showChats.toggle()
        }
    }
}
