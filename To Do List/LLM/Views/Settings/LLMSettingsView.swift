//
//  LLMSettingsView.swift
//
//

import SwiftUI

struct LLMSettingsView: View {
    @EnvironmentObject var appManager: AppManager
    @Environment(\.dismiss) var dismiss
    @Environment(LLMEvaluator.self) var llm
    @Binding var currentThread: Thread?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NavigationLink(destination: ChatsSettingsView(currentThread: $currentThread)) {
                        HStack(spacing: TaskerTheme.Spacing.md) {
                            ZStack {
                                RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.sm, style: .continuous)
                                    .fill(Color.tasker(.accentWash))
                                    .frame(width: 32, height: 32)
                                Image(systemName: "message.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color.tasker(.accentPrimary))
                            }
                            Text("chats")
                                .font(.tasker(.body))
                                .foregroundColor(Color.tasker(.textPrimary))
                        }
                    }
                    .accessibilityIdentifier("llmSettings.chatsSettingsRow")

                    NavigationLink(destination: ModelsSettingsView()) {
                        HStack(spacing: TaskerTheme.Spacing.md) {
                            ZStack {
                                RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.sm, style: .continuous)
                                    .fill(Color.tasker(.accentWash))
                                    .frame(width: 32, height: 32)
                                Image(systemName: "arrow.down.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color.tasker(.accentPrimary))
                            }
                            Text("models")
                                .font(.tasker(.body))
                                .foregroundColor(Color.tasker(.textPrimary))
                                .fixedSize()
                            Spacer()
                            Text(appManager.modelDisplayName(appManager.currentModelName ?? ""))
                                .font(.tasker(.caption1))
                                .foregroundColor(Color.tasker(.textTertiary))
                        }
                    }
                    .accessibilityIdentifier("llmSettings.modelsSettingsRow")

                    NavigationLink(destination: LLMPersonalMemorySettingsView()) {
                        HStack(spacing: TaskerTheme.Spacing.md) {
                            ZStack {
                                RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.sm, style: .continuous)
                                    .fill(Color.tasker(.accentWash))
                                    .frame(width: 32, height: 32)
                                Image(systemName: "person.text.rectangle.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color.tasker(.accentPrimary))
                            }
                            Text("memory")
                                .font(.tasker(.body))
                                .foregroundColor(Color.tasker(.textPrimary))
                            Spacer()
                            Text(memorySummary)
                                .font(.tasker(.caption1))
                                .foregroundColor(Color.tasker(.textTertiary))
                        }
                    }
                    .accessibilityIdentifier("llmSettings.memorySettingsRow")
                }

                Section {} footer: {
                    HStack {
                        Spacer()
                        Text("made with care by Saransh")
                            .font(.tasker(.caption2))
                            .foregroundColor(Color.tasker(.textQuaternary))
                        Spacer()
                    }
                    .padding(.vertical, TaskerTheme.Spacing.lg)
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(Color.tasker(.bgCanvas))
            .navigationTitle("settings")
            .accessibilityIdentifier("llmSettings.view")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar {
                    #if os(iOS) || os(visionOS)
                    ToolbarItem(placement: .topBarLeading) {
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                        }
                    }
                    #elseif os(macOS)
                    ToolbarItem(placement: .destructiveAction) {
                        Button(action: { dismiss() }) {
                            Text("close")
                        }
                    }
                    #endif
                }
        }
        .tint(Color.tasker(.accentPrimary))
    }

    private var memorySummary: String {
        let memory = LLMPersonalMemoryDefaultsStore.load()
        let count = LLMPersonalMemorySection.allCases.reduce(0) { partial, section in
            partial + memory.entries(for: section).filter { $0.text.isEmpty == false }.count
        }
        return count == 0 ? "empty" : "\(count) items"
    }
}

extension Bundle {
    var releaseVersionNumber: String? {
        return infoDictionary?["CFBundleShortVersionString"] as? String
    }

    var buildVersionNumber: String? {
        return infoDictionary?["CFBundleVersion"] as? String
    }
}

#Preview {
    LLMSettingsView(currentThread: .constant(nil))
        .environmentObject(AppManager())
        .environment(LLMEvaluator())
}

private struct LLMPersonalMemorySettingsView: View {
    @State private var store = LLMPersonalMemoryDefaultsStore.load()

    var body: some View {
        Form {
            ForEach(LLMPersonalMemorySection.allCases) { section in
                Section {
                    ForEach(store.entries(for: section)) { entry in
                        TextField(
                            "add \(section.title.dropLast())",
                            text: binding(for: section, entryID: entry.id)
                        )
                    }
                    .onDelete { offsets in
                        deleteEntries(for: section, offsets: offsets)
                    }

                    if store.entries(for: section).count < LLMPersonalMemoryStoreV1.maxEntriesPerSection {
                        Button("add item") {
                            addEntry(to: section)
                        }
                    }
                } header: {
                    Text(section.title)
                } footer: {
                    Text("Up to \(LLMPersonalMemoryStoreV1.maxEntriesPerSection) items, \(LLMPersonalMemoryStoreV1.maxEntryCharacters) chars each.")
                }
            }

            Section {
                Button("clear all", role: .destructive) {
                    store = LLMPersonalMemoryStoreV1()
                    persist()
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("memory")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func binding(for section: LLMPersonalMemorySection, entryID: UUID) -> Binding<String> {
        Binding(
            get: {
                store.entries(for: section).first(where: { $0.id == entryID })?.text ?? ""
            },
            set: { newValue in
                var entries = store.entries(for: section)
                guard let index = entries.firstIndex(where: { $0.id == entryID }) else { return }
                entries[index].text = String(newValue.prefix(LLMPersonalMemoryStoreV1.maxEntryCharacters))
                store.setEntries(entries, for: section)
                persist()
            }
        )
    }

    private func addEntry(to section: LLMPersonalMemorySection) {
        var entries = store.entries(for: section)
        entries.append(LLMPersonalMemoryEntry(text: ""))
        store.setEntries(entries, for: section)
        persist()
    }

    private func deleteEntries(for section: LLMPersonalMemorySection, offsets: IndexSet) {
        var entries = store.entries(for: section)
        entries.remove(atOffsets: offsets)
        store.setEntries(entries, for: section)
        persist()
    }

    private func persist() {
        LLMPersonalMemoryDefaultsStore.save(store)
    }
}
