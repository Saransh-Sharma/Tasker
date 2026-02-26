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
import Combine






/// UIKit wrapper that embeds the SwiftUI LLM module.
extension Notification.Name {
    static let toggleChatHistory = Notification.Name("toggleChatHistory")
}

class ChatHostViewController: UIViewController {
    private let appManager = AppManager()
    private let llmEvaluator = LLMRuntimeCoordinator.shared.evaluator
    // Shared SwiftData container for the LLM module (persistent on-disk, CloudKit disabled)
    private let container: ModelContainer? = LLMDataController.shared

    private var hostingController: UIHostingController<AnyView>!
    private var themeCancellable: AnyCancellable?

    /// Executes viewDidLoad.
    override func viewDidLoad() {
        super.viewDidLoad()
        if LLMDataController.isDegradedModeActive {
            logWarning(
                event: "llm_data_controller_degraded_mode_active",
                message: "LLM chat storage is running in degraded mode",
                fields: ["reason": LLMDataController.degradedModeReason ?? "unknown"]
            )
        }
        let themeColors = TaskerThemeManager.shared.currentTheme.tokens.color
        view.backgroundColor = themeColors.bgCanvas

        // Root SwiftUI view that decides what to present.
        let rootView: AnyView
        if let container {
            rootView = AnyView(
                ChatContainerView()
                    .environmentObject(appManager)
                    .environment(llmEvaluator)
                    .modelContainer(container)
            )
        } else {
            rootView = AnyView(LLMStoreUnavailableView())
        }

        hostingController = UIHostingController(rootView: rootView)
        addChild(hostingController)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        hostingController.view.backgroundColor = themeColors.bgCanvas
        view.addSubview(hostingController.view)
        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        hostingController.didMove(toParent: self)
        setupNavigationBar()
        Task { @MainActor in
            await LLMRuntimeCoordinator.shared.prewarmIfEligibleCurrentModel()
        }

        themeCancellable = TaskerThemeManager.shared.publisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.applyTheme()
            }
    }
    // MARK: - Navigation Bar Setup
    /// Executes setupNavigationBar.
    private func setupNavigationBar() {
        // Configure navigation bar appearance using standard iOS APIs
        title = "Eva"

        let themeColors = TaskerThemeManager.shared.currentTheme.tokens.color
        let onAccent = themeColors.accentOnPrimary

        // Configure navigation bar appearance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = themeColors.accentPrimary
        appearance.titleTextAttributes = [.foregroundColor: onAccent]
        appearance.largeTitleTextAttributes = [.foregroundColor: onAccent]

        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.compactAppearance = appearance
        navigationController?.navigationBar.prefersLargeTitles = false

        // Left: Back button
        let backButton = UIBarButtonItem(
            image: UIImage(systemName: "chevron.backward"),
            style: .plain,
            target: self,
            action: #selector(onBackTapped)
        )
        backButton.tintColor = onAccent
        backButton.accessibilityLabel = "Back"
        navigationItem.leftBarButtonItem = backButton

        // Right: History button
        let historyButton = UIBarButtonItem(
            image: UIImage(systemName: "text.below.folder"),
            style: .plain,
            target: self,
            action: #selector(onHistoryTapped)
        )
        historyButton.tintColor = onAccent
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

    /// Executes applyTheme.
    private func applyTheme() {
        let themeColors = TaskerThemeManager.shared.currentTheme.tokens.color
        view.backgroundColor = themeColors.bgCanvas
        let onAccent = themeColors.accentOnPrimary

        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = themeColors.accentPrimary
        appearance.titleTextAttributes = [.foregroundColor: onAccent]
        appearance.largeTitleTextAttributes = [.foregroundColor: onAccent]

        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.compactAppearance = appearance
        navigationItem.leftBarButtonItem?.tintColor = onAccent
        navigationItem.rightBarButtonItem?.tintColor = onAccent
    }

    deinit {
        themeCancellable?.cancel()
    }
}

private struct LLMStoreUnavailableView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.orange)
            Text("Assistant storage unavailable")
                .font(.headline)
                .foregroundColor(.tasker(.textPrimary))
            Text("Restart the app to retry LLM storage initialization.")
                .font(.subheadline)
                .foregroundColor(.tasker(.textSecondary))
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.tasker(.bgCanvas))
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
                    .onChange(of: appManager.installedModels) { _, _ in
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
        .background(Color.tasker(.bgCanvas))
        // Present chat history list when showChats toggled (iPhone)
        .sheet(isPresented: $showChats) {
            ChatsListView(currentThread: $currentThread, isPromptFocused: $isPromptFocused)
                .environmentObject(appManager)
                #if os(iOS)
                .presentationDragIndicator(.hidden)
                .presentationDetents(appManager.userInterfaceIdiom == .phone ? [.medium, .large] : [.large])
                .presentationBackground(Color.tasker(.bgElevated))
                .presentationCornerRadius(TaskerTheme.CornerRadius.modal)
            #endif
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleChatHistory)) { _ in
            showChats.toggle()
        }
    }
}
