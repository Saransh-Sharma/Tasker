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






/// UIKit wrapper that embeds the SwiftUI LLM module.
class ChatHostViewController: UIViewController {
    private let appManager = AppManager()
    private let llmEvaluator = LLMEvaluator()
    // Shared SwiftData container for the LLM module (persistent on-disk, CloudKit disabled)
    private let container: ModelContainer = LLMDataController.shared

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        // Root SwiftUI view that decides what to present.
        let rootView = ChatContainerView()
            .environmentObject(appManager)
            .environment(llmEvaluator)
            .modelContainer(container)

        let hostingController = UIHostingController(rootView: rootView)
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
    }
}
