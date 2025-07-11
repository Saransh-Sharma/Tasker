//
//  ChatView.swift
//
//

import MarkdownUI
import SwiftUI
import Combine
import SwiftData
import os

struct ChatView: View {
    @EnvironmentObject var appManager: AppManager
    @Environment(\.modelContext) var modelContext
    @Binding var currentThread: Thread?
    @Environment(LLMEvaluator.self) var llm
    @Namespace var bottomID
    @State var showModelPicker = false
    @State var prompt = ""
    @FocusState.Binding var isPromptFocused: Bool
    @Binding var showChats: Bool
    @Binding var showSettings: Bool
    @Environment(\.dismiss) var dismissView
    
    @State var thinkingTime: TimeInterval?
    
    @State private var generatingThreadID: UUID?
    // Track which threads already received task/project context to avoid bloating each prompt
    static private var contextInjectedThreads = Set<UUID>()

    var isPromptEmpty: Bool {
        prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    let platformBackgroundColor: Color = {
        #if os(iOS)
        return Color(UIColor.secondarySystemBackground)
        #elseif os(visionOS)
        return Color(UIColor.separator)
        #elseif os(macOS)
        return Color(NSColor.secondarySystemFill)
        #endif
    }()

    var chatInput: some View {
        HStack(alignment: .bottom, spacing: 0) {
            TextField("message", text: $prompt, axis: .vertical)
                .focused($isPromptFocused)
                .textFieldStyle(.plain)
            #if os(iOS) || os(visionOS)
                .padding(.horizontal, 16)
            #elseif os(macOS)
                .padding(.horizontal, 12)
                .onSubmit {
                    handleShiftReturn()
                }
                .submitLabel(.send)
            #endif
                .padding(.vertical, 8)
            #if os(iOS) || os(visionOS)
                .frame(minHeight: 48)
            #elseif os(macOS)
                .frame(minHeight: 32)
            #endif
            #if os(iOS)
            .onSubmit {
                isPromptFocused = true
                generate()
            }
            #endif

            if llm.running {
                stopButton
            } else {
                generateButton
            }
        }
        #if os(iOS) || os(visionOS)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(platformBackgroundColor)
        )
        #elseif os(macOS)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(platformBackgroundColor)
        )
        #endif
    }

    var modelPickerButton: some View {
        Button {
            appManager.playHaptic()
            showModelPicker.toggle()
        } label: {
            Group {
                Image(systemName: "chevron.up")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                #if os(iOS) || os(visionOS)
                    .frame(width: 16)
                #elseif os(macOS)
                    .frame(width: 12)
                #endif
                    .tint(.primary)
            }
            #if os(iOS) || os(visionOS)
            .frame(width: 48, height: 48)
            #elseif os(macOS)
            .frame(width: 32, height: 32)
            #endif
            .background(
                Circle()
                    .fill(platformBackgroundColor)
            )
        }
        #if os(macOS) || os(visionOS)
        .buttonStyle(.plain)
        #endif
    }

    var generateButton: some View {
        Button {
            generate()
        } label: {
            Image(systemName: "arrow.up.circle.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
            #if os(iOS) || os(visionOS)
                .frame(width: 24, height: 24)
            #else
                .frame(width: 16, height: 16)
            #endif
        }
        .disabled(isPromptEmpty)
        #if os(iOS) || os(visionOS)
            .padding(.trailing, 12)
            .padding(.bottom, 12)
        #else
            .padding(.trailing, 8)
            .padding(.bottom, 8)
        #endif
        #if os(macOS) || os(visionOS)
        .buttonStyle(.plain)
        #endif
    }

    var stopButton: some View {
        Button {
            llm.stop()
        } label: {
            Image(systemName: "stop.circle.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
            #if os(iOS) || os(visionOS)
                .frame(width: 24, height: 24)
            #else
                .frame(width: 16, height: 16)
            #endif
        }
        .disabled(llm.cancelled)
        #if os(iOS) || os(visionOS)
            .padding(.trailing, 12)
            .padding(.bottom, 12)
        #else
            .padding(.trailing, 8)
            .padding(.bottom, 8)
        #endif
        #if os(macOS) || os(visionOS)
        .buttonStyle(.plain)
        #endif
    }

    var chatTitle: String {
        if let currentThread = currentThread {
            if let firstMessage = currentThread.sortedMessages.first {
                return firstMessage.content
            }
        }

        return "chat"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let currentThread = currentThread {
                    ConversationView(thread: currentThread, generatingThreadID: generatingThreadID)
                } else {
                    Spacer()
                    Image(systemName: "checkmark.circle")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 32, height: 32)
                        .foregroundStyle(.quaternary)
                    Spacer()
                }

                HStack(alignment: .bottom) {
                    modelPickerButton
                    chatInput
                }
                .padding()
            }
            .navigationTitle(chatTitle)
            #if os(iOS) || os(visionOS)
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarHidden(true)
            #endif
                .sheet(isPresented: $showModelPicker) {
                    NavigationStack {
                        ModelsSettingsView()
                            .environment(llm)
                        #if os(visionOS)
                            .toolbar {
                                ToolbarItem(placement: .topBarLeading) {
                                    Button(action: { showModelPicker.toggle() }) {
                                        Image(systemName: "xmark")
                                    }
                                }
                            }
                        #endif
                    }
                    #if os(iOS)
                    .presentationDragIndicator(.visible)
                    .presentationDetents(appManager.userInterfaceIdiom == .phone ? [.medium] : [.large])
                    #elseif os(macOS)
                    .toolbar {
                        ToolbarItem(placement: .destructiveAction) {
                            Button(action: { showModelPicker.toggle() }) {
                                Text("close")
                            }
                        }
                    }
                    #endif
                }
                .sheet(isPresented: $showSettings) {
                    NavigationStack {
                        LLMSettingsView(currentThread: $currentThread)
                            .environment(llm)
                        #if os(visionOS)
                            .toolbar {
                                ToolbarItem(placement: .topBarLeading) {
                                    Button(action: { showSettings.toggle() }) {
                                        Image(systemName: "xmark")
                                    }
                                }
                            }
                        #endif
                    }
                    #if os(iOS)
                    .presentationDragIndicator(.visible)
                    .presentationDetents(appManager.userInterfaceIdiom == .phone ? [.large] : [.large])
                    #elseif os(macOS)
                    .toolbar {
                        ToolbarItem(placement: .destructiveAction) {
                            Button(action: { showSettings.toggle() }) {
                                Text("close")
                            }
                        }
                    }
                    #endif
                }
                // MARK: - Main Toolbar
                .toolbar {
                    #if os(macOS)

                    ToolbarItem(placement: .primaryAction) {
                        Button(action: {
                            appManager.playHaptic()
                            showSettings.toggle()
                        }) {
                            Label("settings", systemImage: "gear")
                        }
                    }
                    #endif
                }
        }
    }

    private enum SlashAction {
        case summary(TaskRange, Projects?)
        case clear
        case none
    }

    private func generate() {
        if !isPromptEmpty {
            // Parse slash command if any
            let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
            let action = parseSlashCommand(trimmed)

            // Handle /clear immediately
            if case .clear = action {
                if let thread = currentThread {
                    modelContext.delete(thread)
                    try? modelContext.save()
                }
                currentThread = nil
                prompt = ""
                return
            }

            // Ensure thread exists
            if currentThread == nil {
                let newThread = Thread()
                currentThread = newThread
                modelContext.insert(newThread)
                do {
                    try modelContext.save()
                    print("[DEBUG] saved new thread OK")
                } catch {
                    print("[DEBUG] save thread error: \(error)")
                }
                do {
                    let all = try modelContext.fetch(FetchDescriptor<Thread>())
                    print("[DEBUG] after creating thread, total threads: \(all.count)")
                } catch {
                    print("[DEBUG] fetch threads error: \(error)")
                }
            }

            if let currentThread = currentThread {
                generatingThreadID = currentThread.id
                _Concurrency.Task {
                    let message = prompt
                    prompt = ""
                    appManager.playHaptic()

                    // Build dynamic system prompt based on action
                    var dynamicSystemPrompt = "You are Eva, the user's personal task assistant. Use the provided tasks and project details to answer questions and help manage their work." + "\n\n" + appManager.systemPrompt

                    switch action {
                    case let .summary(range, project):
                        let summary = PromptMiddleware.buildTasksSummary(range: range, project: project)
                        dynamicSystemPrompt += "\n\nTasks (\(range.description)):\n" + summary
                    default:
                        break
                    }
                    // Add task/project context only once per thread to keep prompts small
                    let tID = currentThread.id
                    if !ChatView.contextInjectedThreads.contains(tID) {
                        let tasksText = LLMTaskContextBuilder.weeklyTasksTextCached()
                        dynamicSystemPrompt += "\n\n" + tasksText
                        ChatView.contextInjectedThreads.insert(tID)
                    }

                    await MainActor.run {
                        sendMessage(Message(role: .user, content: message, thread: currentThread))
                    }
                    await MainActor.run {
                        llm.isThinking = true
                    }
                    DispatchQueue.main.async {
                        _Concurrency.Task {
                            guard let modelName = appManager.currentModelName else {
                                sendMessage(Message(role: .assistant, content: "No model selected", thread: currentThread))
                                generatingThreadID = nil
                                return
                            }
                            os_log("SystemPrompt length %d", dynamicSystemPrompt.count)
                            print("SYSTEM PROMPT ->\n\(dynamicSystemPrompt)")
                            print("USER MESSAGE ->\n\(message)")
                            let output = await llm.generate(modelName: modelName, thread: currentThread, systemPrompt: dynamicSystemPrompt)
                            print("LLM RESPONSE ->\n\(output)")
                            sendMessage(Message(role: .assistant, content: output, thread: currentThread, generatingTime: llm.thinkingTime))
                            generatingThreadID = nil
                        }
                    }
                }
            }
        }
    }

    private func sendMessage(_ message: Message) {
        appManager.playHaptic()
        modelContext.insert(message)
        do {
            try modelContext.save()
            print("[DEBUG] saved message OK")
        } catch {
            print("[DEBUG] save message error: \(error)")
        }
        do {
            let all = try modelContext.fetch(FetchDescriptor<Message>())
            print("[DEBUG] after inserting message, total messages: \(all.count)")
        } catch {
            print("[DEBUG] fetch messages error: \(error)")
        }
    }

    // MARK: - Slash command parsing
    private func parseSlashCommand(_ text: String) -> SlashAction {
        guard text.hasPrefix("/") else { return .none }
        let components = text.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        guard let command = components.first?.lowercased() else { return .none }

        switch command {
        case "/todo", "/today":
            return .summary(.today, nil)
        case "/tomorrow":
            return .summary(.tomorrow, nil)
        case "/week":
            return .summary(.week, nil)
        case "/month":
            return .summary(.month, nil)
        case "/project":
            if components.count == 2 {
                let query = components[1].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let match = ProjectManager.sharedInstance.getAllProjects().first { ($0.projectName ?? "").lowercased().contains(query) }
                return .summary(.all, match)
            }
            return .summary(.all, nil)
        case "/clear":
            return .clear
        default:
            return .none
        }
    }

    // MARK: - Task summary helper
    private func buildTasksSummary() -> String {
        PromptMiddleware.buildTasksSummary(range: .today)
    }

    #if os(macOS)
    private func handleShiftReturn() {
        if NSApp.currentEvent?.modifierFlags.contains(.shift) == true {
            prompt.append("\n")
            isPromptFocused = true
        } else {
            generate()
        }
    }
    #endif
}

#Preview {
    @FocusState var isPromptFocused: Bool
    ChatView(currentThread: .constant(nil), isPromptFocused: $isPromptFocused, showChats: .constant(false), showSettings: .constant(false))
}
