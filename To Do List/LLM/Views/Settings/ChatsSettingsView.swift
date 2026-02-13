//
//  ChatsSettingsView.swift
//
//

import SwiftUI

struct ChatsSettingsView: View {
    @EnvironmentObject var appManager: AppManager
    @Environment(\.modelContext) var modelContext
    @State var systemPrompt = ""
    @State var deleteAllChats = false
    @Binding var currentThread: Thread?

    var body: some View {
        Form {
            Section(header: Text("system prompt")
                .font(.tasker(.caption1))
                .foregroundColor(Color.tasker(.textTertiary))
            ) {
                TextEditor(text: $appManager.systemPrompt)
                    .font(.tasker(.callout))
                    .foregroundColor(Color.tasker(.textPrimary))
                    .frame(minHeight: 150)
                    .textEditorStyle(.plain)
                    .tint(Color.tasker(.accentPrimary))
            }

            if appManager.userInterfaceIdiom == .phone {
                Section {
                    Toggle("haptics", isOn: $appManager.shouldPlayHaptics)
                        .font(.tasker(.body))
                        .tint(Color.tasker(.accentPrimary))
                }
            }

            Section {
                Button {
                    deleteAllChats.toggle()
                } label: {
                    Label {
                        Text("delete all chats")
                            .font(.tasker(.body))
                    } icon: {
                        Image(systemName: "trash")
                    }
                    .foregroundColor(Color.tasker(.statusDanger))
                }
                .alert("are you sure?", isPresented: $deleteAllChats) {
                    Button("cancel", role: .cancel) {
                        deleteAllChats = false
                    }
                    Button("delete", role: .destructive) {
                        deleteChats()
                    }
                }
                .buttonStyle(.borderless)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Color.tasker(.bgCanvas))
        .navigationTitle("chats")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    func deleteChats() {
        do {
            currentThread = nil
            try modelContext.delete(model: Thread.self)
            try modelContext.delete(model: Message.self)
        } catch {
            logError("Failed to delete.")
        }
    }
}

#Preview {
    ChatsSettingsView(currentThread: .constant(nil))
}
