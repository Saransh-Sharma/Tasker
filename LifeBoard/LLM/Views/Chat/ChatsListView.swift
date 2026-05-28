//
//  ChatsListView.swift
//
//

import StoreKit
import SwiftData
import SwiftUI

struct ChatsListView: View {
    @EnvironmentObject var appManager: AppManager
    @Environment(\.dismiss) var dismiss
    @Environment(\.lifeboardLayoutClass) private var layoutClass
    @Binding var currentThread: Thread?
    @FocusState.Binding var isPromptFocused: Bool
    @Environment(\.modelContext) var modelContext
    @Query(sort: \Thread.timestamp, order: .reverse) var threads: [Thread]
    @State var search = ""
    @State var selection: Thread?

    @Environment(\.requestReview) private var requestReview

    var body: some View {
        NavigationStack {
            ZStack {
                EvaChatSunriseBackground()

                if filteredThreads.isEmpty {
                    emptyState
                } else {
                    List(selection: $selection) {
                        #if os(macOS)
                        Section {} // adds some space below the search bar on mac
                        #endif
                        ForEach(Array(filteredThreads.enumerated()), id: \.element.id) { index, thread in
                            HStack(spacing: LifeBoardTheme.Spacing.md) {
                                ZStack {
                                    Circle()
                                        .fill(EvaChatSunriseGlass.assistantSurface)
                                        .frame(width: 40, height: 40)
                                        .overlay(Circle().stroke(EvaChatSunriseGlass.assistantBorder.opacity(0.78), lineWidth: 1))
                                    Image(systemName: "bubble.left.fill")
                                        .font(.system(size: 16))
                                        .foregroundStyle(EvaChatSunriseGlass.primary)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    if let firstMessage = thread.sortedMessages.first {
                                        Text(firstMessage.content)
                                            .lineLimit(1)
                                            .font(.lifeboard(.bodyEmphasis))
                                            .foregroundStyle(EvaChatSunriseGlass.navy)
                                    } else {
                                        Text("untitled")
                                            .font(.lifeboard(.bodyEmphasis))
                                            .foregroundStyle(EvaChatSunriseGlass.navy)
                                    }

                                    Text(thread.timestamp.formatted())
                                        .font(.lifeboard(.caption1))
                                        .foregroundStyle(EvaChatSunriseGlass.navyMuted)
                                }

                                Spacer()
                            }
                            .padding(.horizontal, LifeBoardTheme.Spacing.sm)
                            .padding(.vertical, LifeBoardTheme.Spacing.sm)
                            .lifeboardPremiumSurface(
                                cornerRadius: 22,
                                fillColor: EvaChatSunriseGlass.glassFill,
                                strokeColor: EvaChatSunriseGlass.glassBorder,
                                accentColor: EvaChatSunriseGlass.primary,
                                level: .e1
                            )
                            .staggeredAppearance(index: index)
                            #if os(macOS)
                                .swipeActions {
                                    Button("Delete") {
                                        deleteThread(thread)
                                    }
                                    .tint(Color.lifeboard(.statusDanger))
                                }
                                .contextMenu {
                                    Button {
                                        deleteThread(thread)
                                    } label: {
                                        Text("Delete")
                                    }
                                }
                            #endif
                                .tag(thread)
                                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                        }
                        .onDelete(perform: deleteThreads)
                    }
                    .onChange(of: selection) {
                        setCurrentThread(selection)
                    }
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    #if os(iOS)
                    .listStyle(.plain)
                    #elseif os(macOS) || os(visionOS)
                    .listStyle(.sidebar)
                    #endif
                }
            }
            .navigationTitle("Chats")
            #if os(iOS) || os(visionOS)
                .navigationBarTitleDisplayMode(.inline)
                .searchable(text: $search, prompt: "search")
            #elseif os(macOS)
                .searchable(text: $search, placement: .sidebar, prompt: "search")
            #endif
                .toolbar {
                    #if os(iOS) || os(visionOS)
                    if layoutClass == .phone {
                        ToolbarItem(placement: .topBarLeading) {
                            Button(action: { dismiss() }) {
                                Image(systemName: "xmark")
                            }
                        }
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: {
                            selection = nil
                            // create new thread
                            setCurrentThread(nil)

                            // ask for review if appropriate
                            requestReviewIfAppropriate()
                        }) {
                            Image(systemName: "plus")
                                .foregroundColor(Color.lifeboard(.accentPrimary))
                        }
                        .keyboardShortcut("N", modifiers: [.command])
                        #if os(visionOS)
                            .buttonStyle(.bordered)
                        #endif
                    }
                    #elseif os(macOS)
                    ToolbarItem(placement: .primaryAction) {
                        Button(action: {
                            selection = nil
                            // create new thread
                            setCurrentThread(nil)

                            // ask for review if appropriate
                            requestReviewIfAppropriate()
                        }) {
                            Label("New", systemImage: "plus")
                        }
                        .keyboardShortcut("N", modifiers: [.command])
                    }
                    #endif
                }
        }
        .tint(EvaChatSunriseGlass.primary)
    }

    private var emptyState: some View {
        VStack(spacing: LifeBoardTheme.Spacing.lg) {
            ZStack {
                Circle()
                    .fill(EvaChatSunriseGlass.assistantSurface)
                    .frame(width: 80, height: 80)
                    .overlay(Circle().stroke(EvaChatSunriseGlass.assistantBorder.opacity(0.78), lineWidth: 1))
                Image(systemName: "message")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(EvaChatSunriseGlass.primary)
            }

            VStack(spacing: LifeBoardTheme.Spacing.xs) {
                Text(threads.isEmpty ? "No chats yet" : "No results")
                    .font(.lifeboard(.headline))
                    .foregroundStyle(EvaChatSunriseGlass.navy)
                Text(threads.isEmpty ? "Start a conversation with \(AssistantIdentityText.currentSnapshot().displayName)" : "Try a different search term")
                    .font(.lifeboard(.callout))
                    .foregroundStyle(EvaChatSunriseGlass.navyMuted)
            }
        }
        .padding(LifeBoardTheme.Spacing.xl)
        .lifeboardPremiumSurface(
            cornerRadius: 28,
            fillColor: EvaChatSunriseGlass.glassFill,
            strokeColor: EvaChatSunriseGlass.glassBorder,
            accentColor: EvaChatSunriseGlass.primary,
            level: .e1
        )
        .padding(.horizontal, LifeBoardTheme.Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var filteredThreads: [Thread] {
        threads.filter { thread in
            search.isEmpty || thread.messages.contains { message in
                message.content.localizedCaseInsensitiveContains(search)
            }
        }
    }

    /// Executes requestReviewIfAppropriate.
    func requestReviewIfAppropriate() {
        if appManager.numberOfVisits - appManager.numberOfVisitsOfLastRequest >= 5 {
            requestReview() // can only be prompted if the user hasn't given a review in the last year, so it will prompt again when apple deems appropriate
            appManager.numberOfVisitsOfLastRequest = appManager.numberOfVisits
        }
    }

    /// Executes deleteThreads.
    private func deleteThreads(at offsets: IndexSet) {
        let targets = offsets.sorted(by: >).compactMap { offset -> Thread? in
            guard filteredThreads.indices.contains(offset) else { return nil }
            return filteredThreads[offset]
        }
        for thread in targets {
            guard let threadIndex = threads.firstIndex(where: { $0.id == thread.id }) else { continue }
            let targetThread = threads[threadIndex]
            let threadID = targetThread.id

            if let currentThread = currentThread {
                if currentThread.id == threadID {
                    setCurrentThread(nil)
                }
            }

            Task { @MainActor in
                selection = nil
                await Task.yield()
                await ThreadContextAttachmentStore.shared.clear(threadID: threadID)
                modelContext.delete(targetThread)
                do {
                    try modelContext.save()
                } catch {
                    logError(
                        event: "chat_thread_delete_save_failed",
                        message: "Failed to save chat thread deletion",
                        fields: ["thread_id": threadID.uuidString, "error": error.localizedDescription]
                    )
                }
            }
        }
    }

    /// Executes deleteThread.
    private func deleteThread(_ thread: Thread) {
        let threadID = thread.id
        if let currentThread = currentThread {
            if currentThread.id == threadID {
                setCurrentThread(nil)
            }
        }
        Task { @MainActor in
            await ThreadContextAttachmentStore.shared.clear(threadID: threadID)
            modelContext.delete(thread)
            do {
                try modelContext.save()
            } catch {
                logError(
                    event: "chat_thread_delete_save_failed",
                    message: "Failed to save chat thread deletion",
                    fields: ["thread_id": threadID.uuidString, "error": error.localizedDescription]
                )
            }
        }
    }

    /// Executes setCurrentThread.
    private func setCurrentThread(_ thread: Thread? = nil) {
        currentThread = thread
        isPromptFocused = true
        #if os(iOS)
        if layoutClass == .phone || V2FeatureFlags.iPadNativeShellEnabled == false {
            dismiss()
        }
        #endif
        appManager.playHaptic()
    }
}

#Preview {
    @FocusState var isPromptFocused: Bool
    ChatsListView(currentThread: .constant(nil), isPromptFocused: $isPromptFocused)
}
