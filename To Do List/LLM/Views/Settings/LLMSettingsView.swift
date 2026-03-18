import SwiftUI

struct LLMSettingsView: View {
    @EnvironmentObject var appManager: AppManager
    @Environment(\.dismiss) private var dismiss
    @Environment(LLMEvaluator.self) var llm
    @Environment(\.taskerLayoutClass) private var layoutClass

    @Binding var currentThread: Thread?
    var showsCloseButton: Bool = false

    private var spacing: TaskerSpacingTokens {
        TaskerThemeManager.shared.tokens(for: layoutClass).spacing
    }

    private var heroItems: [TaskerSettingsStatusDescriptor] {
        [
            TaskerSettingsStatusDescriptor(
                id: "model",
                title: "Model",
                value: appManager.compactModelDisplayName(appManager.currentModelName ?? ""),
                systemImage: "brain.head.profile",
                tone: .accent
            ),
            TaskerSettingsStatusDescriptor(
                id: "prompt",
                title: "Prompt",
                value: promptStatus,
                systemImage: "slider.horizontal.3",
                tone: appManager.systemPrompt == AppManager.defaultSystemPrompt ? .neutral : .success
            ),
            TaskerSettingsStatusDescriptor(
                id: "memory",
                title: "Memory",
                value: memorySummary,
                systemImage: "person.text.rectangle.fill",
                tone: memoryItemCount == 0 ? .neutral : .accent
            ),
        ]
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                TaskerSettingsHeroCard(
                    eyebrow: "EVA",
                    title: "Run your day with Eva",
                    subtitle: "Manage behavior, local models, and memory for your private executive assistant.",
                    statusItems: heroItems
                )
                .padding(.horizontal, spacing.screenHorizontal)
                .padding(.top, spacing.s16)

                if layoutClass.isPad {
                    padContent
                } else {
                    phoneContent
                }

                footer
            }
            .padding(.bottom, spacing.s24)
        }
        .background(Color.tasker(.bgCanvas))
        .navigationTitle("Eva")
        .accessibilityIdentifier("llmSettings.view")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            if showsCloseButton {
                #if os(iOS) || os(visionOS)
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("llmSettings.doneButton")
                }
                #elseif os(macOS)
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                #endif
            }
        }
    }

    private var phoneContent: some View {
        VStack(spacing: 0) {
            behaviorSection(baseIndex: 1)
            modelsSection(baseIndex: 4)
            privacySection(baseIndex: 6)
        }
    }

    private var padContent: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: spacing.sectionGap) {
                VStack(spacing: 0) {
                    behaviorSection(baseIndex: 1, includeHorizontalPadding: false)
                }
                .frame(maxWidth: 560, alignment: .top)

                VStack(spacing: 0) {
                    modelsSection(baseIndex: 4, includeHorizontalPadding: false)
                    privacySection(baseIndex: 6, includeHorizontalPadding: false)
                }
                .frame(maxWidth: 560, alignment: .top)
            }
            .padding(.horizontal, spacing.screenHorizontal)
        }
    }

    private func behaviorSection(baseIndex: Int, includeHorizontalPadding: Bool = true) -> some View {
        VStack(spacing: 0) {
            SettingsSectionHeader(
                title: "Behavior & Memory",
                subtitle: "Shape how direct, structured, and momentum-focused Eva feels."
            )
            .enhancedStaggeredAppearance(index: baseIndex)
            .padding(.top, spacing.sectionGap)

            VStack(spacing: spacing.cardStackVertical) {
                TaskerCard {
                    NavigationLink {
                        ChatsSettingsView(currentThread: $currentThread)
                            .environmentObject(appManager)
                    } label: {
                        SettingsNavigationRow(
                            descriptor: TaskerSettingsDestinationDescriptor(
                                iconName: "text.bubble.fill",
                                title: "Chat Behavior",
                                subtitle: "Tune how direct, structured, and momentum-focused Eva feels.",
                                trailingStatus: promptStatus,
                                inlineBadge: appManager.userInterfaceIdiom == .phone ? TaskerSettingsInlineBadge(title: hapticsStatus) : nil,
                                tone: .accent,
                                accessibilityIdentifier: "llmSettings.chatsSettingsRow"
                            )
                        )
                    }
                    .buttonStyle(.plain)
                }
                .enhancedStaggeredAppearance(index: baseIndex + 1)

                TaskerCard(active: memoryItemCount > 0) {
                    NavigationLink {
                        LLMPersonalMemorySettingsView()
                    } label: {
                        SettingsNavigationRow(
                            descriptor: TaskerSettingsDestinationDescriptor(
                                iconName: "person.text.rectangle.fill",
                                title: "Personal Memory",
                                subtitle: "Save stable context so Eva can support your goals, routines, and working style.",
                                trailingStatus: memorySummary,
                                tone: .accent,
                                accessibilityIdentifier: "llmSettings.memorySettingsRow"
                            )
                        )
                    }
                    .buttonStyle(.plain)
                }
                .enhancedStaggeredAppearance(index: baseIndex + 2)
            }
            .padding(.horizontal, includeHorizontalPadding ? spacing.screenHorizontal : 0)
            .padding(.top, spacing.s12)
        }
    }

    private func modelsSection(baseIndex: Int, includeHorizontalPadding: Bool = true) -> some View {
        VStack(spacing: 0) {
            SettingsSectionHeader(
                title: "Models",
                subtitle: "Choose Eva’s default local model and review compatibility."
            )
            .enhancedStaggeredAppearance(index: baseIndex)
            .padding(.top, spacing.sectionGap)

            TaskerCard {
                NavigationLink {
                    ModelsSettingsView()
                        .environmentObject(appManager)
                        .environment(llm)
                } label: {
                    SettingsNavigationRow(
                        descriptor: TaskerSettingsDestinationDescriptor(
                            iconName: "cpu.fill",
                            title: "Models",
                            subtitle: "Choose Eva’s default local model and manage installed models.",
                            trailingStatus: appManager.compactModelDisplayName(appManager.currentModelName ?? ""),
                            inlineBadge: appManager.installedModels.isEmpty ? TaskerSettingsInlineBadge(title: "None installed") : TaskerSettingsInlineBadge(title: "\(appManager.installedModels.count) installed"),
                            tone: .accent,
                            accessibilityIdentifier: "llmSettings.modelsSettingsRow"
                        )
                    )
                }
                .buttonStyle(.plain)
            }
            .enhancedStaggeredAppearance(index: baseIndex + 1)
            .padding(.horizontal, includeHorizontalPadding ? spacing.screenHorizontal : 0)
            .padding(.top, spacing.s12)
        }
    }

    private func privacySection(baseIndex: Int, includeHorizontalPadding: Bool = true) -> some View {
        VStack(spacing: 0) {
            SettingsSectionHeader(
                title: "Data & Privacy",
                subtitle: "Review local-only assistant data and clear transcripts when needed."
            )
            .enhancedStaggeredAppearance(index: baseIndex)
            .padding(.top, spacing.sectionGap)

            TaskerCard {
                NavigationLink {
                    LLMDataPrivacySettingsView(currentThread: $currentThread)
                } label: {
                    SettingsNavigationRow(
                        descriptor: TaskerSettingsDestinationDescriptor(
                            iconName: "trash.fill",
                            title: "Data & Privacy",
                            subtitle: "Delete chat history and review Eva’s local-only data.",
                            trailingStatus: "Transcripts",
                            tone: .danger,
                            accessibilityIdentifier: "llmSettings.privacySettingsRow"
                        )
                    )
                }
                .buttonStyle(.plain)
            }
            .enhancedStaggeredAppearance(index: baseIndex + 1)
            .padding(.horizontal, includeHorizontalPadding ? spacing.screenHorizontal : 0)
            .padding(.top, spacing.s12)
        }
    }

    private var footer: some View {
        VStack(spacing: spacing.s4) {
            Text("Responses and memory stay local to your device.")
                .font(.tasker(.caption2))
                .foregroundStyle(Color.tasker(.textQuaternary))

            Text("Tune behavior carefully so Eva stays clear, useful, and brief.")
                .font(.tasker(.caption2))
                .foregroundStyle(Color.tasker(.textQuaternary))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, spacing.s20)
    }

    private var promptStatus: String {
        appManager.systemPrompt == AppManager.defaultSystemPrompt ? "Default" : "Custom"
    }

    private var hapticsStatus: String {
        appManager.shouldPlayHaptics ? "Haptics on" : "Haptics off"
    }

    private var memoryItemCount: Int {
        let memory = LLMPersonalMemoryDefaultsStore.load()
        return LLMPersonalMemorySection.allCases.reduce(0) { partial, section in
            partial + memory.entries(for: section).filter { $0.text.isEmpty == false }.count
        }
    }

    private var memorySummary: String {
        memoryItemCount == 0 ? "Empty" : "\(memoryItemCount) saved"
    }
}

#Preview {
    NavigationStack {
        LLMSettingsView(currentThread: .constant(nil), showsCloseButton: true)
            .environmentObject(AppManager())
            .environment(LLMEvaluator())
    }
}

struct LLMPersonalMemorySettingsView: View {
    @State private var store = LLMPersonalMemoryDefaultsStore.load()
    @Environment(\.taskerLayoutClass) private var layoutClass

    private var spacing: TaskerSpacingTokens {
        TaskerThemeManager.shared.tokens(for: layoutClass).spacing
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                SettingsSectionHeader(
                    title: "Personal Memory",
                    subtitle: "Save durable context Eva should remember across chats."
                )
                .padding(.top, spacing.s16)

                VStack(spacing: spacing.cardStackVertical) {
                    helperCopy

                    ForEach(LLMPersonalMemorySection.allCases) { section in
                        memorySectionCard(section)
                    }

                    TaskerSettingsDangerZoneCard(
                        title: "Clear All Personal Memory",
                        subtitle: "Remove every saved preference, routine, and goal from Eva’s memory.",
                        buttonTitle: "Clear all memory"
                    ) {
                        store = LLMPersonalMemoryStoreV1()
                        persist()
                    }
                }
                .padding(.horizontal, spacing.screenHorizontal)
                .padding(.top, spacing.s12)
            }
            .padding(.bottom, spacing.s24)
        }
        .background(Color.tasker(.bgCanvas))
        .navigationTitle("Personal Memory")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private var helperCopy: some View {
        TaskerSettingsCard {
            Text("Up to \(LLMPersonalMemoryStoreV1.maxEntriesPerSection) items per section, \(LLMPersonalMemoryStoreV1.maxEntryCharacters) characters each.")
                .font(.tasker(.caption1))
                .foregroundStyle(Color.tasker(.textSecondary))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func memorySectionCard(_ section: LLMPersonalMemorySection) -> some View {
        TaskerSettingsFieldCard(
            title: section.displayTitle,
            subtitle: section.supportingCopy
        ) {
            VStack(alignment: .leading, spacing: spacing.s12) {
                if store.entries(for: section).isEmpty {
                    Text(section.emptyStateCopy)
                        .font(.tasker(.caption1))
                        .foregroundStyle(Color.tasker(.textTertiary))
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    ForEach(store.entries(for: section)) { entry in
                        HStack(alignment: .top, spacing: spacing.s8) {
                            TextField(
                                section.placeholderText,
                                text: binding(for: section, entryID: entry.id),
                                axis: .vertical
                            )
                            .font(.tasker(.callout))
                            .foregroundStyle(Color.tasker(.textPrimary))
                            .lineLimit(2...4)

                            Button(role: .destructive) {
                                deleteEntry(for: section, entryID: entry.id)
                            } label: {
                                Image(systemName: "minus.circle")
                                    .font(.system(size: 16, weight: .semibold))
                                    .frame(width: 28, height: 28)
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 2)
                            .accessibilityLabel("Remove memory item")
                        }
                        .padding(spacing.s12)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.tasker(.surfaceSecondary))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.tasker(.strokeHairline), lineWidth: 1)
                        )
                    }
                }

                if store.entries(for: section).count < LLMPersonalMemoryStoreV1.maxEntriesPerSection {
                    Button("Add item") {
                        addEntry(to: section)
                    }
                    .font(.tasker(.buttonSmall))
                    .buttonStyle(.bordered)
                    .tint(Color.tasker(.accentPrimary))
                }
            }
        }
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

    private func deleteEntry(for section: LLMPersonalMemorySection, entryID: UUID) {
        var entries = store.entries(for: section)
        entries.removeAll { $0.id == entryID }
        store.setEntries(entries, for: section)
        persist()
    }

    private func persist() {
        LLMPersonalMemoryDefaultsStore.save(store)
    }
}

struct LLMDataPrivacySettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.taskerLayoutClass) private var layoutClass

    @State private var deleteAllChats = false
    @Binding var currentThread: Thread?

    private var spacing: TaskerSpacingTokens {
        TaskerThemeManager.shared.tokens(for: layoutClass).spacing
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                SettingsSectionHeader(
                    title: "Data & Privacy",
                    subtitle: "Use destructive actions carefully. Clearing transcripts removes your saved AI conversation history."
                )
                .padding(.top, spacing.s16)

                TaskerSettingsDangerZoneCard(
                    title: "Delete All Chats",
                    subtitle: "Permanently delete every saved Eva thread and message from this device. This cannot be undone.",
                    buttonTitle: "Delete all chats",
                    accessibilityIdentifier: "llmSettings.deleteAllChatsButton"
                ) {
                    deleteAllChats = true
                }
                .padding(.horizontal, spacing.screenHorizontal)
                .padding(.top, spacing.s12)
            }
            .padding(.bottom, spacing.s24)
        }
        .background(Color.tasker(.bgCanvas))
        .navigationTitle("Data & Privacy")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .alert("Delete all chats?", isPresented: $deleteAllChats) {
            Button("Cancel", role: .cancel) {
                deleteAllChats = false
            }
            Button("Delete all chats", role: .destructive) {
                deleteChats()
            }
        } message: {
            Text("This permanently removes every saved thread and message from this device.")
        }
    }

    private func deleteChats() {
        do {
            currentThread = nil
            try modelContext.delete(model: Thread.self)
            try modelContext.delete(model: Message.self)
            try modelContext.save()
        } catch {
            logError("Failed to delete chats.")
        }
    }
}

private extension LLMPersonalMemorySection {
    var displayTitle: String {
        switch self {
        case .preferences:
            return "Preferences"
        case .routines:
            return "Routines"
        case .currentGoals:
            return "Current Goals"
        }
    }

    var supportingCopy: String {
        switch self {
        case .preferences:
            return "Save stable likes, dislikes, and standing preferences."
        case .routines:
            return "Save recurring patterns like workout windows or shutdown routines."
        case .currentGoals:
            return "Save active priorities Eva should keep in view."
        }
    }

    var emptyStateCopy: String {
        switch self {
        case .preferences:
            return "No preferences saved yet. Add the communication style, planning bias, or defaults Eva should remember."
        case .routines:
            return "No routines saved yet. Add recurring rhythms like workout windows, review habits, or shutdown rituals."
        case .currentGoals:
            return "No goals saved yet. Add what matters most right now so Eva can keep advice aligned."
        }
    }

    var placeholderText: String {
        switch self {
        case .preferences:
            return "Example: I prefer short, direct plans."
        case .routines:
            return "Example: I do a weekly review every Sunday evening."
        case .currentGoals:
            return "Example: I’m trying to ship the April release."
        }
    }
}
