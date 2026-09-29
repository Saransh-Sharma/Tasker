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
    @Binding var currentThread: Thread?
    @FocusState.Binding var isPromptFocused: Bool
    @Environment(\.modelContext) var modelContext
    @Query(sort: \Thread.timestamp, order: .reverse) var threads: [Thread]
    @State var search = ""
    @State var selection: Thread?
    @State private var showsAppliedHistory = false
    @State private var receipts = EvaChatReceiptCenter.shared
    /// The query, a beat behind the keystrokes: every message of every thread
    /// was searched on each character typed.
    @State private var settledSearch = ""

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
                        if settledSearch.isEmpty == false, messageHits.isEmpty == false {
                            Section("Messages") {
                                ForEach(messageHits) { hit in
                                    Button {
                                        guard let thread = threads.first(where: { $0.id == hit.threadID }) else { return }
                                        // The thread opens at the message that matched,
                                        // not at its bottom.
                                        EvaChatScrollTarget.shared.messageID = hit.messageID
                                        setCurrentThread(thread)
                                    } label: {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(ChatSearchHighlight.attributed(hit.snippet, query: settledSearch))
                                                .font(.lifeboard(.body))
                                                .foregroundStyle(EvaChatSunriseGlass.navy)
                                                .lineLimit(3)
                                            Text("\(hit.role == .user ? String(localized: "You") : AssistantIdentityText.currentSnapshot().displayName) · \(hit.timestamp.formatted(date: .abbreviated, time: .shortened))")
                                                .font(.lifeboard(.caption1))
                                                .foregroundStyle(EvaChatSunriseGlass.navyMuted)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .accessibilityIdentifier("eva.search.hit.\(hit.messageID.uuidString)")
                                    .listRowBackground(Color.clear)
                                }
                            }
                        }
                        ForEach(Array(filteredThreads.enumerated()), id: \.element.id) { index, thread in
                            HStack(spacing: Theme.Spacing.md) {
                                ZStack {
                                    Circle()
                                        .fill(EvaChatSunriseGlass.assistantSurface)
                                        .frame(width: 40, height: 40)
                                        .overlay(Circle().stroke(EvaChatSunriseGlass.assistantBorder.opacity(0.78), lineWidth: 1))
                                    Image(systemName: "bubble.left.fill")
                                        .lifeboardFont(.body)
                                        .foregroundStyle(EvaChatSunriseGlass.primary)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    if let firstMessage = thread.sortedMessages.first {
                                        Text(firstMessage.content)
                                            .lineLimit(1)
                                            .font(.lifeboard(.bodyEmphasis))
                                            .foregroundStyle(EvaChatSunriseGlass.navy)
                                    } else {
                                        Text("Untitled chat")
                                            .font(.lifeboard(.bodyEmphasis))
                                            .foregroundStyle(EvaChatSunriseGlass.navy)
                                    }

                                    Text(thread.timestamp.formatted())
                                        .font(.lifeboard(.caption1))
                                        .foregroundStyle(EvaChatSunriseGlass.navyMuted)
                                }

                                Spacer()
                            }
                            .padding(.horizontal, Theme.Spacing.sm)
                            .padding(.vertical, Theme.Spacing.sm)
                            .lifeboardPremiumSurface(
                                cornerRadius: Radius.card,
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
                            #if os(iOS) || os(visionOS)
                                .contextMenu {
                                    ShareLink(
                                        item: exportMarkdown(for: thread),
                                        preview: SharePreview(thread.sortedMessages.first?.content ?? String(localized: "Chat with \(AssistantIdentityText.currentSnapshot().displayName)"))
                                    ) {
                                        Label("Export chat", systemImage: "square.and.arrow.up")
                                    }
                                    Button(role: .destructive) {
                                        deleteThread(thread)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
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
                .searchable(text: $search, prompt: "Search chats")
            #elseif os(macOS)
                .searchable(text: $search, placement: .sidebar, prompt: "Search chats")
            #endif
                .toolbar {
                    #if os(iOS) || os(visionOS)
                    ToolbarItem(placement: .topBarLeading) {
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                        }
                        .keyboardShortcut(.cancelAction)
                        .accessibilityLabel("Close chats")
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showsAppliedHistory = true
                        } label: {
                            Image(systemName: "checklist")
                                .foregroundColor(Color.lifeboard(.accentPrimary))
                        }
                        .accessibilityLabel("Applied changes")
                        .accessibilityIdentifier("eva.history.open")
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
                        .accessibilityLabel("New chat")
                        .keyboardShortcut("N", modifiers: [.command])
                        #if os(visionOS)
                            .buttonStyle(.lifeBoardChip)
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
        // The list is a sheet over the chat, so its deletions need their
        // receipt here too.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            EvaChatReceiptSlot()
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.bottom, Theme.Spacing.sm)
        }
        .task(id: search) {
            guard search != settledSearch else { return }
            if search.isEmpty == false {
                try? await Task.sleep(for: .milliseconds(180))
                guard Task.isCancelled == false else { return }
            }
            settledSearch = search
        }
        .sheet(isPresented: $showsAppliedHistory) {
            EvaAppliedRunHistorySheet()
        }
    }

    private var messageHits: [ChatSearchIndex.Hit] {
        let snapshots = threads.flatMap { thread in
            thread.messages.map { message in
                ChatMessageSnapshot(
                    id: message.id,
                    threadID: thread.id,
                    role: ChatMessageSnapshot.Role(rawValue: message.role.rawValue) ?? .user,
                    content: message.content,
                    timestamp: message.timestamp
                )
            }
        }
        return ChatSearchIndex.search(settledSearch, in: snapshots, limit: 20)
    }

    private func exportMarkdown(for thread: Thread) -> String {
        ChatTranscriptExporter.markdown(
            title: thread.title,
            messages: thread.sortedMessagesSnapshot().map { message in
                ChatMessageSnapshot(
                    id: message.id,
                    threadID: thread.id,
                    role: ChatMessageSnapshot.Role(rawValue: message.role.rawValue) ?? .user,
                    content: message.content,
                    timestamp: message.timestamp
                )
            }
        )
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.lg) {
            ZStack {
                Circle()
                    .fill(EvaChatSunriseGlass.assistantSurface)
                    .frame(width: 80, height: 80)
                    .overlay(Circle().stroke(EvaChatSunriseGlass.assistantBorder.opacity(0.78), lineWidth: 1))
                Image(systemName: "message")
                    .lifeboardFont(.heroDisplay)
                    .foregroundStyle(EvaChatSunriseGlass.primary)
            }

            VStack(spacing: Theme.Spacing.xs) {
                Text(threads.isEmpty ? "No chats yet" : "No results")
                    .font(.lifeboard(.headline))
                    .foregroundStyle(EvaChatSunriseGlass.navy)
                Text(threads.isEmpty ? "Ask \(AssistantIdentityText.currentSnapshot().displayName) anything to start." : "Try another search.")
                    .font(.lifeboard(.callout))
                    .foregroundStyle(EvaChatSunriseGlass.navyMuted)
            }
        }
        .padding(Theme.Spacing.xl)
        .lifeboardPremiumSurface(
            cornerRadius: 28,
            fillColor: EvaChatSunriseGlass.glassFill,
            strokeColor: EvaChatSunriseGlass.glassBorder,
            accentColor: EvaChatSunriseGlass.primary,
            level: .e1
        )
        .padding(.horizontal, Theme.Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var filteredThreads: [Thread] {
        threads.filter { thread in
            guard receipts.pendingDeletedThreadIDs.contains(thread.id) == false else { return false }
            return settledSearch.isEmpty || thread.messages.contains { message in
                message.content.localizedCaseInsensitiveContains(settledSearch)
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

    /// Swipe-to-delete. Deletion is soft until its receipt settles; see
    /// `requestDeletion(_:)`.
    private func deleteThreads(at offsets: IndexSet) {
        let visible = filteredThreads
        let targets = offsets.compactMap { visible.indices.contains($0) ? visible[$0] : nil }
        selection = nil
        for thread in targets { requestDeletion(thread) }
    }

    private func deleteThread(_ thread: Thread) {
        requestDeletion(thread)
    }

    /// Deleting a chat used to be immediate and final, with no confirmation
    /// and no Undo. It now hides the chat and leaves a receipt; the chat is
    /// destroyed only when that receipt is dismissed or replaced.
    private func requestDeletion(_ thread: Thread) {
        let threadID = thread.id
        if currentThread?.id == threadID {
            setCurrentThread(nil)
        }
        receipts.pendingDeletedThreadIDs.insert(threadID)
        Haptic.pick.play()
        let center = receipts
        let context = modelContext
        center.show(.init(
            message: "Chat deleted",
            undo: {
                center.pendingDeletedThreadIDs.remove(threadID)
                return true
            },
            onSettle: {
                Task { @MainActor in
                    await Self.performDeletion(threadID: threadID, context: context)
                    center.pendingDeletedThreadIDs.remove(threadID)
                }
            }
        ))
    }

    private static func performDeletion(threadID: UUID, context: ModelContext) async {
        let descriptor = FetchDescriptor<Thread>(predicate: #Predicate { $0.id == threadID })
        guard let thread = try? context.fetch(descriptor).first else { return }
        await ThreadContextAttachmentStore.shared.clear(threadID: threadID)
        for message in thread.messages where message.role == .assistant {
            let renderModel = ChatMessageRenderModel(message: message)
            if let answer = renderModel.answerText,
               answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                await EvaSpokenOutputController.shared.deleteCachedSpeech(for: answer)
            }
        }
        context.delete(thread)
        do {
            try context.save()
        } catch {
            logError(
                event: "chat_thread_delete_save_failed",
                message: "Failed to save chat thread deletion",
                fields: ["thread_id": threadID.uuidString, "error": error.localizedDescription]
            )
        }
    }

    /// Executes setCurrentThread.
    private func setCurrentThread(_ thread: Thread? = nil) {
        currentThread = thread
        isPromptFocused = true
        // History is a sheet at every width now, so picking a thread closes it.
        dismiss()
        appManager.playHaptic()
    }
}

#Preview {
    @FocusState var isPromptFocused: Bool
    ChatsListView(currentThread: .constant(nil), isPromptFocused: $isPromptFocused)
}
