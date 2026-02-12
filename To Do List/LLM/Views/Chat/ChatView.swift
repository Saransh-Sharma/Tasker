//
//  ChatView.swift
//
//

import MarkdownUI
import SwiftUI
import Combine
import SwiftData
import CoreData
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
    static private var contextInjectedThreads = Set<UUID>()

    var isPromptEmpty: Bool {
        prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Chat Input Bar

    var chatInput: some View {
        HStack(alignment: .bottom, spacing: 0) {
            TextField("ask Eva anything...", text: $prompt, axis: .vertical)
                .focused($isPromptFocused)
                .textFieldStyle(.plain)
                .font(.tasker(.body))
                .foregroundColor(Color.tasker(.textPrimary))
            #if os(iOS) || os(visionOS)
                .padding(.horizontal, TaskerTheme.Spacing.lg)
            #elseif os(macOS)
                .padding(.horizontal, TaskerTheme.Spacing.md)
                .onSubmit {
                    handleShiftReturn()
                }
                .submitLabel(.send)
            #endif
                .padding(.vertical, TaskerTheme.Spacing.sm)
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
            RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.xl, style: .continuous)
                .fill(Color.tasker(.surfaceSecondary))
        )
        .overlay(
            RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.xl, style: .continuous)
                .stroke(Color.tasker(.strokeHairline), lineWidth: 1)
        )
        .taskerElevation(.e1, cornerRadius: TaskerTheme.CornerRadius.xl)
        #elseif os(macOS)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.tasker(.surfaceSecondary))
        )
        #endif
    }

    // MARK: - Model Picker Button

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
                    .fontWeight(.semibold)
                    .foregroundColor(Color.tasker(.accentPrimary))
            }
            #if os(iOS) || os(visionOS)
            .frame(width: 48, height: 48)
            #elseif os(macOS)
            .frame(width: 32, height: 32)
            #endif
            .background(
                Circle()
                    .fill(Color.tasker(.accentWash))
            )
            .overlay(
                Circle()
                    .stroke(Color.tasker(.accentMuted), lineWidth: 1)
            )
        }
        #if os(macOS) || os(visionOS)
        .buttonStyle(.plain)
        #endif
        .scaleOnPress()
    }

    // MARK: - Send Button

    var generateButton: some View {
        Button {
            generate()
        } label: {
            Image(systemName: "arrow.up")
                .font(.tasker(.buttonSmall))
                .fontWeight(.semibold)
                .foregroundColor(isPromptEmpty ? Color.tasker(.textQuaternary) : Color.tasker(.accentOnPrimary))
            #if os(iOS) || os(visionOS)
                .frame(width: 32, height: 32)
            #else
                .frame(width: 24, height: 24)
            #endif
                .background(
                    Circle()
                        .fill(isPromptEmpty ? Color.tasker(.surfaceTertiary) : Color.tasker(.accentPrimary))
                )
        }
        .disabled(isPromptEmpty)
        #if os(iOS) || os(visionOS)
            .padding(.trailing, TaskerTheme.Spacing.md)
            .padding(.bottom, TaskerTheme.Spacing.md)
        #else
            .padding(.trailing, TaskerTheme.Spacing.sm)
            .padding(.bottom, TaskerTheme.Spacing.sm)
        #endif
        .animation(TaskerAnimation.quick, value: isPromptEmpty)
        #if os(macOS) || os(visionOS)
        .buttonStyle(.plain)
        #endif
    }

    // MARK: - Stop Button

    var stopButton: some View {
        Button {
            llm.stop()
        } label: {
            Image(systemName: "stop.fill")
                .font(.caption)
                .foregroundColor(Color.tasker(.accentOnPrimary))
            #if os(iOS) || os(visionOS)
                .frame(width: 32, height: 32)
            #else
                .frame(width: 24, height: 24)
            #endif
                .background(
                    Circle()
                        .fill(Color.tasker(.statusDanger))
                )
        }
        .disabled(llm.cancelled)
        #if os(iOS) || os(visionOS)
            .padding(.trailing, TaskerTheme.Spacing.md)
            .padding(.bottom, TaskerTheme.Spacing.md)
        #else
            .padding(.trailing, TaskerTheme.Spacing.sm)
            .padding(.bottom, TaskerTheme.Spacing.sm)
        #endif
        .scaleOnPress()
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

    // MARK: - Empty State

    var emptyState: some View {
        VStack(spacing: TaskerTheme.Spacing.lg) {
            Spacer()

            // Eva avatar circle
            ZStack {
                Circle()
                    .fill(Color.tasker(.accentWash))
                    .frame(width: 80, height: 80)
                Image(systemName: "bubble.left.and.text.bubble.right")
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(Color.tasker(.accentPrimary))
                    .symbolEffect(.wiggle.byLayer, options: .repeat(.periodic(delay: 3.0)))
            }

            VStack(spacing: TaskerTheme.Spacing.xs) {
                Text("ask Eva anything")
                    .font(.tasker(.title2))
                    .foregroundColor(Color.tasker(.textPrimary))
                Text("your AI assistant knows your tasks and projects")
                    .font(.tasker(.callout))
                    .foregroundColor(Color.tasker(.textTertiary))
                    .multilineTextAlignment(.center)
            }

            // Suggestion chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: TaskerTheme.Spacing.sm) {
                    ForEach(["what's due today?", "summarize my week", "plan tomorrow"], id: \.self) { suggestion in
                        Button {
                            prompt = suggestion
                            generate()
                        } label: {
                            Text(suggestion)
                                .font(.tasker(.callout))
                                .foregroundColor(Color.tasker(.accentPrimary))
                                .padding(.horizontal, TaskerTheme.Spacing.md)
                                .padding(.vertical, TaskerTheme.Spacing.sm)
                                .background(Color.tasker(.accentWash))
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(Color.tasker(.accentMuted), lineWidth: 1))
                        }
                        .scaleOnPress()
                    }
                }
                .padding(.horizontal, TaskerTheme.Spacing.xl)
            }

            Spacer()
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let currentThread = currentThread {
                    ConversationView(thread: currentThread, generatingThreadID: generatingThreadID)
                } else {
                    emptyState
                }

                // Bottom input area
                HStack(alignment: .bottom, spacing: TaskerTheme.Spacing.md) {
                    modelPickerButton
                    chatInput
                }
                .padding(.horizontal, TaskerTheme.Spacing.lg)
                .padding(.bottom, TaskerTheme.Spacing.md)
                .padding(.top, TaskerTheme.Spacing.sm)
                .background(
                    Color.tasker(.bgCanvas)
                        .shadow(color: Color.tasker(.textPrimary).opacity(0.04), radius: 8, y: -4)
                )
            }
            .background(Color.tasker(.bgCanvas))
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
                    .presentationBackground(Color.tasker(.bgElevated))
                    .presentationCornerRadius(TaskerTheme.CornerRadius.xl)
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
                    .presentationBackground(Color.tasker(.bgElevated))
                    .presentationCornerRadius(TaskerTheme.CornerRadius.xl)
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
            let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
            let action = parseSlashCommand(trimmed)

            if case .clear = action {
                if let thread = currentThread {
                    modelContext.delete(thread)
                    try? modelContext.save()
                }
                currentThread = nil
                prompt = ""
                return
            }

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

                    var dynamicSystemPrompt = "You are Eva, the user's personal task assistant. Use the provided tasks and project details to answer questions and help manage their work." + "\n\n" + appManager.systemPrompt

                    switch action {
                    case let .summary(range, project):
                        let summary = PromptMiddleware.buildTasksSummary(range: range, project: project)
                        dynamicSystemPrompt += "\n\nTasks (\(range.description)):\n" + summary
                    default:
                        break
                    }
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
                let context = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer.viewContext
                let request: NSFetchRequest<Projects> = Projects.fetchRequest()
                let allProjects = (try? context?.fetch(request)) ?? []
                let match = allProjects.first { ($0.projectName ?? "").lowercased().contains(query) }
                return .summary(.all, match)
            }
            return .summary(.all, nil)
        case "/clear":
            return .clear
        default:
            return .none
        }
    }

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
