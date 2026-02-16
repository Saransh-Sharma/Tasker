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

    @Environment(\.requestReview) private var requestReview

    var body: some View {
        NavigationStack {
            ZStack {
                Color.tasker(.bgCanvas)
                    .ignoresSafeArea()

                if filteredThreads.isEmpty {
                    emptyState
                } else {
                    List(selection: $selection) {
                        #if os(macOS)
                        Section {} // adds some space below the search bar on mac
                        #endif
                        ForEach(Array(filteredThreads.enumerated()), id: \.element.id) { index, thread in
                            HStack(spacing: TaskerTheme.Spacing.md) {
                                ZStack {
                                    Circle()
                                        .fill(Color.tasker(.accentWash))
                                        .frame(width: 40, height: 40)
                                    Image(systemName: "bubble.left.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(Color.tasker(.accentPrimary))
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    if let firstMessage = thread.sortedMessages.first {
                                        Text(firstMessage.content)
                                            .lineLimit(1)
                                            .font(.tasker(.bodyEmphasis))
                                            .foregroundColor(Color.tasker(.textPrimary))
                                    } else {
                                        Text("untitled")
                                            .font(.tasker(.bodyEmphasis))
                                            .foregroundColor(Color.tasker(.textPrimary))
                                    }

                                    Text(thread.timestamp.formatted())
                                        .font(.tasker(.caption1))
                                        .foregroundColor(Color.tasker(.textTertiary))
                                }

                                Spacer()
                            }
                            .padding(.vertical, TaskerTheme.Spacing.xs)
                            .staggeredAppearance(index: index)
                            #if os(macOS)
                                .swipeActions {
                                    Button("Delete") {
                                        deleteThread(thread)
                                    }
                                    .tint(Color.tasker(.statusDanger))
                                }
                                .contextMenu {
                                    Button {
                                        deleteThread(thread)
                                    } label: {
                                        Text("delete")
                                    }
                                }
                            #endif
                                .tag(thread)
                                .listRowBackground(Color.tasker(.bgElevated))
                        }
                        .onDelete(perform: deleteThreads)
                    }
                    .onChange(of: selection) {
                        setCurrentThread(selection)
                    }
                    .scrollContentBackground(.hidden)
                    .background(Color.tasker(.bgCanvas))
                    #if os(iOS)
                    .listStyle(.plain)
                    #elseif os(macOS) || os(visionOS)
                    .listStyle(.sidebar)
                    #endif
                }
            }
            .navigationTitle("chats")
            #if os(iOS) || os(visionOS)
                .navigationBarTitleDisplayMode(.inline)
                .searchable(text: $search, prompt: "search")
            #elseif os(macOS)
                .searchable(text: $search, placement: .sidebar, prompt: "search")
            #endif
                .toolbar {
                    #if os(iOS) || os(visionOS)
                    if appManager.userInterfaceIdiom == .phone {
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
                                .foregroundColor(Color.tasker(.accentPrimary))
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
                            Label("new", systemImage: "plus")
                        }
                        .keyboardShortcut("N", modifiers: [.command])
                    }
                    #endif
                }
        }
        .tint(Color.tasker(.accentPrimary))
    }

    private var emptyState: some View {
        VStack(spacing: TaskerTheme.Spacing.lg) {
            ZStack {
                Circle()
                    .fill(Color.tasker(.accentWash))
                    .frame(width: 80, height: 80)
                Image(systemName: "message")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(Color.tasker(.accentPrimary))
            }

            VStack(spacing: TaskerTheme.Spacing.xs) {
                Text(threads.isEmpty ? "no chats yet" : "no results")
                    .font(.tasker(.headline))
                    .foregroundColor(Color.tasker(.textPrimary))
                Text(threads.isEmpty ? "start a conversation with Eva" : "try a different search term")
                    .font(.tasker(.callout))
                    .foregroundColor(Color.tasker(.textSecondary))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var filteredThreads: [Thread] {
        threads.filter { thread in
            search.isEmpty || thread.messages.contains { message in
                message.content.localizedCaseInsensitiveContains(search)
            }
        }
    }

    func requestReviewIfAppropriate() {
        if appManager.numberOfVisits - appManager.numberOfVisitsOfLastRequest >= 5 {
            requestReview() // can only be prompted if the user hasn't given a review in the last year, so it will prompt again when apple deems appropriate
            appManager.numberOfVisitsOfLastRequest = appManager.numberOfVisits
        }
    }

    private func deleteThreads(at offsets: IndexSet) {
        for offset in offsets {
            let thread = threads[offset]

            if let currentThread = currentThread {
                if currentThread.id == thread.id {
                    setCurrentThread(nil)
                }
            }

            // Adding a delay fixes a crash on iOS following a deletion
            let delay = appManager.userInterfaceIdiom == .phone ? 1.0 : 0.0
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                modelContext.delete(thread)
            }
        }
    }

    private func deleteThread(_ thread: Thread) {
        if let currentThread = currentThread {
            if currentThread.id == thread.id {
                setCurrentThread(nil)
            }
        }
        modelContext.delete(thread)
    }

    private func setCurrentThread(_ thread: Thread? = nil) {
        currentThread = thread
        isPromptFocused = true
        #if os(iOS)
        dismiss()
        #endif
        appManager.playHaptic()
    }
}

#Preview {
    @FocusState var isPromptFocused: Bool
    ChatsListView(currentThread: .constant(nil), isPromptFocused: $isPromptFocused)
}
