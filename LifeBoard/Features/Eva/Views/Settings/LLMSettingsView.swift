import SwiftData
import SwiftUI

struct LLMSettingsView: View {
    @EnvironmentObject var appManager: AppManager
    @Environment(\.dismiss) private var dismiss
    @Environment(LLMEvaluator.self) var llm
    @Environment(\.lifeboardTokens) private var tokens
    @Environment(\.lifeboardLayoutClass) private var layoutClass

    @Binding var currentThread: Thread?
    var showsCloseButton: Bool = false
    @StateObject private var assistantIdentity = AssistantIdentityModel()
    @State private var cloudAccount = EvaCloudAccountState.shared
    @AppStorage("eva.cloud.migration.notice.dismissed.v1") private var dismissedCloudMigrationNotice = false

    private var spacing: SemanticSpacingTokens {
        tokens.spacing
    }

    private var heroItems: [SettingsStatusDescriptor] {
        [
            SettingsStatusDescriptor(
                id: "model",
                title: "Model",
                value: appManager.compactModelDisplayName(appManager.currentModelName ?? ""),
                systemImage: "brain.head.profile",
                tone: .accent
            ),
            SettingsStatusDescriptor(
                id: "prompt",
                title: "Prompt",
                value: promptStatus,
                systemImage: "slider.horizontal.3",
                tone: appManager.systemPrompt == AppManager.defaultSystemPrompt ? .neutral : .success
            ),
            SettingsStatusDescriptor(
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
                SettingsHeroCard(
                    eyebrow: assistantIdentity.snapshot.uppercaseName,
                    title: "Run your day with \(assistantIdentity.snapshot.displayName)",
                    subtitle: "Manage Cloud EVA, Offline EVA, behavior, and the context you choose to share.",
                    statusItems: heroItems
                )
                .padding(.horizontal, spacing.screenHorizontal)
                .padding(.top, spacing.s16)

                evaIdentityCard
                    .padding(.horizontal, spacing.screenHorizontal)
                    .padding(.top, spacing.s12)

                if layoutClass == .padRegular || layoutClass == .padExpanded {
                    padContent
                } else {
                    phoneContent
                }

                footer
            }
            .padding(.bottom, spacing.s24)
        }
        .background(Color.lifeboard(.bgCanvas))
        .navigationTitle(assistantIdentity.snapshot.displayName)
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

    private var evaIdentityCard: some View {
        SurfaceCard {
            HStack(alignment: .center, spacing: spacing.s12) {
                EvaMascotView(placement: .settingsIdentity, size: .inline)
                VStack(alignment: .leading, spacing: spacing.s4) {
                    Text("\(assistantIdentity.snapshot.displayName) profile")
                        .font(.lifeboard(.headline))
                        .foregroundStyle(Color.lifeboard(.textPrimary))
                    Text("This assistant manages planning, review, memory, and local model behavior.")
                        .font(.lifeboard(.caption1))
                        .foregroundStyle(Color.lifeboard(.textSecondary))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }
        .accessibilityIdentifier("llmSettings.evaIdentity.card")
    }

    private var phoneContent: some View {
        VStack(spacing: 0) {
            cloudSection(baseIndex: 1)
            behaviorSection(baseIndex: 3)
            modelsSection(baseIndex: 6)
            privacySection(baseIndex: 8)
        }
    }

    private var padContent: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: spacing.sectionGap) {
                VStack(spacing: 0) {
                    cloudSection(baseIndex: 1, includeHorizontalPadding: false)
                    behaviorSection(baseIndex: 3, includeHorizontalPadding: false)
                }
                .frame(maxWidth: 560, alignment: .top)

                VStack(spacing: 0) {
                    modelsSection(baseIndex: 6, includeHorizontalPadding: false)
                    privacySection(baseIndex: 8, includeHorizontalPadding: false)
                }
                .frame(maxWidth: 560, alignment: .top)
            }
            .padding(.horizontal, spacing.screenHorizontal)
        }
    }

    private func cloudSection(baseIndex: Int, includeHorizontalPadding: Bool = true) -> some View {
        VStack(spacing: 0) {
            SettingsSectionHeader(
                title: "Cloud & Offline EVA",
                subtitle: "Connect Luna, review rolling quota and consent, or keep using an installed local model."
            )
            .enhancedStaggeredAppearance(index: baseIndex)
            .padding(.top, spacing.sectionGap)

            if appManager.installedModels.isEmpty == false,
               cloudAccount.isAuthenticated == false,
               dismissedCloudMigrationNotice == false {
                SurfaceCard(active: true) {
                    VStack(alignment: .leading, spacing: spacing.s12) {
                        HStack(alignment: .top, spacing: spacing.s12) {
                            Image(systemName: "cloud.sun.fill")
                                .foregroundStyle(Color.lifeboard(.accentPrimary))
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: spacing.s4) {
                                Text("Cloud EVA is now available")
                                    .font(.lifeboard(.headline))
                                    .foregroundStyle(Color.lifeboard(.textPrimary))
                                Text("Your installed model remains available as Offline EVA. Connect Luna when you want stronger cloud answers and spoken output.")
                                    .font(.lifeboard(.caption1))
                                    .foregroundStyle(Color.lifeboard(.textSecondary))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        Button("Dismiss") { dismissedCloudMigrationNotice = true }
                            .font(.lifeboard(.button))
                            .foregroundStyle(Color.lifeboard(.accentPrimary))
                            .accessibilityIdentifier("llmSettings.cloudMigration.dismiss")
                    }
                }
                .accessibilityIdentifier("llmSettings.cloudMigration.notice")
                .padding(.horizontal, includeHorizontalPadding ? spacing.screenHorizontal : 0)
                .padding(.top, spacing.s12)
            }

            SurfaceCard(active: cloudAccount.canUseCloud) {
                NavigationLink {
                    EvaCloudSettingsView()
                } label: {
                    SettingsNavigationRow(
                        descriptor: SettingsDestinationDescriptor(
                            iconName: "cloud.fill",
                            title: "Cloud EVA",
                            subtitle: "Start as a guest, choose context, manage Luna's rolling quota, and optionally protect EVA with Apple.",
                            trailingStatus: cloudAccount.isAuthenticated ? "Connected" : "Set up",
                            inlineBadge: cloudAccount.quota.map { SettingsInlineBadge(title: "\($0.remaining) answers") },
                            tone: cloudAccount.canUseCloud ? .success : .accent,
                            accessibilityIdentifier: "llmSettings.cloudEvaRow"
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

    private func behaviorSection(baseIndex: Int, includeHorizontalPadding: Bool = true) -> some View {
        VStack(spacing: 0) {
            SettingsSectionHeader(
                title: "Behavior & Memory",
                subtitle: "Shape how direct, structured, and momentum-focused \(assistantIdentity.snapshot.displayName) feels."
            )
            .enhancedStaggeredAppearance(index: baseIndex)
            .padding(.top, spacing.sectionGap)

            VStack(spacing: spacing.cardStackVertical) {
                SurfaceCard {
                    NavigationLink {
                        ChatsSettingsView(currentThread: $currentThread)
                            .environmentObject(appManager)
                    } label: {
                        SettingsNavigationRow(
                            descriptor: SettingsDestinationDescriptor(
                                iconName: "text.bubble.fill",
                                title: "Chat Behavior",
                                subtitle: "Tune how direct, structured, and momentum-focused \(assistantIdentity.snapshot.displayName) feels.",
                                trailingStatus: promptStatus,
                                inlineBadge: layoutClass == .phone ? SettingsInlineBadge(title: hapticsStatus) : nil,
                                tone: .accent,
                                accessibilityIdentifier: "llmSettings.chatsSettingsRow"
                            )
                        )
                    }
                    .buttonStyle(.plain)
                }
                .enhancedStaggeredAppearance(index: baseIndex + 1)

                SurfaceCard(active: memoryItemCount > 0) {
                    NavigationLink {
                        LLMPersonalMemorySettingsView()
                    } label: {
                        SettingsNavigationRow(
                            descriptor: SettingsDestinationDescriptor(
                                iconName: "person.text.rectangle.fill",
                                title: "Personal Memory",
                                subtitle: "Save stable context so \(assistantIdentity.snapshot.displayName) can support your goals, routines, and working style.",
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
                subtitle: "Choose \(assistantIdentity.snapshot.displayName)’s default local model and review compatibility."
            )
            .enhancedStaggeredAppearance(index: baseIndex)
            .padding(.top, spacing.sectionGap)

            SurfaceCard {
                NavigationLink {
                    ModelsSettingsView()
                        .environmentObject(appManager)
                        .environment(llm)
                } label: {
                    SettingsNavigationRow(
                        descriptor: SettingsDestinationDescriptor(
                            iconName: "cpu.fill",
                            title: "Models",
                            subtitle: "Choose \(assistantIdentity.snapshot.displayName)’s default local model and manage installed models.",
                            trailingStatus: appManager.compactModelDisplayName(appManager.currentModelName ?? ""),
                            inlineBadge: appManager.installedModels.isEmpty ? SettingsInlineBadge(title: "None installed") : SettingsInlineBadge(title: "\(appManager.installedModels.count) installed"),
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

            SurfaceCard {
                NavigationLink {
                    LLMDataPrivacySettingsView(currentThread: $currentThread)
                } label: {
                    SettingsNavigationRow(
                        descriptor: SettingsDestinationDescriptor(
                            iconName: "trash.fill",
                            title: "Data & Privacy",
                            subtitle: "Delete chat history and review \(assistantIdentity.snapshot.displayName)’s local-only data.",
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
            Text("Offline EVA stays local. Cloud EVA sends only the request context you authorize.")
                .font(.lifeboard(.caption2))
                .foregroundStyle(Color.lifeboard(.textQuaternary))

            Text("Tune behavior carefully so \(assistantIdentity.snapshot.displayName) stays clear, useful, and brief.")
                .font(.lifeboard(.caption2))
                .foregroundStyle(Color.lifeboard(.textQuaternary))
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
        EvaMemoryDefaultsStoreV3.load().statements.count
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
    @State private var store = EvaMemoryDefaultsStoreV3.load()
    @State private var candidateInbox = EvaMemoryCandidateDefaultsStore.load()
    @State private var excludedEvidence = EvaEvidenceExclusionStore.all()
    @Environment(\.lifeboardLayoutClass) private var layoutClass
    @Environment(\.lifeboardTokens) private var tokens
    @StateObject private var assistantIdentity = AssistantIdentityModel()

    private var spacing: SemanticSpacingTokens {
        tokens.spacing
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                SettingsSectionHeader(
                    title: "Personal Memory",
                    subtitle: "Save durable context \(assistantIdentity.snapshot.displayName) should remember across chats."
                )
                .padding(.top, spacing.s16)

                VStack(spacing: spacing.cardStackVertical) {
                    helperCopy

                    if excludedEvidence.isEmpty == false {
                        excludedEvidenceCard
                    }

                    if candidateInbox.pending.isEmpty == false {
                        pendingMemoryCard
                    }

                    ForEach(EvaMemoryStatement.Section.allCases, id: \.self) { section in
                        memorySectionCard(section)
                    }

                    SettingsDangerZoneCard(
                        title: "Clear All Personal Memory",
                        subtitle: "Remove every saved preference, routine, and goal from \(assistantIdentity.snapshot.displayName)’s memory.",
                        buttonTitle: "Clear all memory"
                    ) {
                        store = EvaMemoryStoreV3()
                        persist()
                    }
                }
                .padding(.horizontal, spacing.screenHorizontal)
                .padding(.top, spacing.s12)
            }
            .padding(.bottom, spacing.s24)
        }
        .background(Color.lifeboard(.bgCanvas))
        .navigationTitle("What Eva knows about you")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private var helperCopy: some View {
        SettingsCard {
            Text("Every memory is editable. ‘You told me’ is kept separate from ‘Eva noticed,’ and a noticed pattern is never promoted without your confirmation.")
                .font(.lifeboard(.caption1))
                .foregroundStyle(Color.lifeboard(.textSecondary))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var excludedEvidenceCard: some View {
        SettingsFieldCard(
            title: "Signals Eva won't use",
            subtitle: "Excluded from Eva, Insights, and smart Home suggestions until you restore them."
        ) {
            VStack(alignment: .leading, spacing: spacing.s8) {
                ForEach(excludedEvidence) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.display)
                                .font(.lifeboard(.callout))
                            Text(item.kind.replacingOccurrences(of: "_", with: " ").capitalized)
                                .font(.lifeboard(.caption2))
                                .foregroundStyle(Color.lifeboard(.textTertiary))
                        }
                        Spacer()
                        Button("Use again") {
                            EvaEvidenceExclusionStore.restore(id: item.id)
                            excludedEvidence = EvaEvidenceExclusionStore.all()
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
    }

    private var pendingMemoryCard: some View {
        SettingsFieldCard(
            title: "Memory suggestions",
            subtitle: "Suggestions stay out of EVA context until you save them. They expire after 30 days."
        ) {
            VStack(spacing: spacing.s12) {
                ForEach(candidateInbox.pending) { candidate in
                    VStack(alignment: .leading, spacing: spacing.s8) {
                        TextField("Suggested memory", text: candidateBinding(candidate.id), axis: .vertical)
                            .font(.lifeboard(.callout))
                            .lineLimit(2...4)
                        HStack {
                            Button("Save") { saveCandidate(candidate.id) }
                                .buttonStyle(.lifeBoardPrimaryCompact)
                            Button("Later") { deferCandidate(candidate.id) }
                                .buttonStyle(.bordered)
                            Button("Dismiss", role: .destructive) { dismissCandidate(candidate.id) }
                                .buttonStyle(.borderless)
                        }
                    }
                    .padding(spacing.s12)
                    .background(Color.lifeboard(.surfaceSecondary), in: RoundedRectangle(cornerRadius: 16))
                }
            }
        }
    }

    private func candidateBinding(_ id: UUID) -> Binding<String> {
        Binding(
            get: { candidateInbox.pending.first(where: { $0.id == id })?.text ?? "" },
            set: { value in
                guard let index = candidateInbox.pending.firstIndex(where: { $0.id == id }) else { return }
                candidateInbox.pending[index].text = String(value.prefix(EvaMemoryStoreV3.maxStatementCharacters))
                EvaMemoryCandidateDefaultsStore.save(candidateInbox)
            }
        )
    }

    private func saveCandidate(_ id: UUID) {
        guard let candidate = candidateInbox.pending.first(where: { $0.id == id }) else { return }
        if store.statements.count >= EvaMemoryStoreV3.maxStatements,
           let replaceID = store.statements.last(where: { $0.provenance != .userStated })?.id
            ?? store.statements.last?.id {
            store.remove(id: replaceID)
        }
        store.upsert(EvaMemoryStatement(
            section: candidate.section,
            text: candidate.text,
            provenance: .inferredCandidate
        ))
        candidateInbox.pending.removeAll { $0.id == id }
        persist()
        EvaMemoryCandidateDefaultsStore.save(candidateInbox)
    }

    private func deferCandidate(_ id: UUID) {
        candidateInbox.deferCandidate(id: id)
        EvaMemoryCandidateDefaultsStore.save(candidateInbox)
    }

    private func dismissCandidate(_ id: UUID) {
        candidateInbox.dismiss(id: id)
        EvaMemoryCandidateDefaultsStore.save(candidateInbox)
    }

    private func memorySectionCard(_ section: EvaMemoryStatement.Section) -> some View {
        SettingsFieldCard(
            title: section.displayTitle,
            subtitle: section.supportingCopy
        ) {
            VStack(alignment: .leading, spacing: spacing.s12) {
                if store.statements(in: section).isEmpty {
                    Text("No saved memories in this section.")
                        .font(.lifeboard(.caption1))
                        .foregroundStyle(Color.lifeboard(.textTertiary))
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    ForEach(store.statements(in: section)) { entry in
                        HStack(alignment: .top, spacing: spacing.s8) {
                            TextField(
                                "Memory",
                                text: binding(for: section, entryID: entry.id),
                                axis: .vertical
                            )
                            .font(.lifeboard(.callout))
                            .foregroundStyle(Color.lifeboard(.textPrimary))
                            .lineLimit(2...4)

                            Text(entry.provenance == .userStated ? "You told me" : "Eva noticed · confirmed")
                                .font(.lifeboard(.caption2))
                                .foregroundStyle(Color.lifeboard(.textTertiary))

                            Button(role: .destructive) {
                                deleteEntry(for: section, entryID: entry.id)
                            } label: {
                                Image(systemName: "minus.circle")
                                    .lifeboardFont(.headline)
                                    .frame(width: 28, height: 28)
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 2)
                            .accessibilityLabel("Remove memory item")
                        }
                        .padding(spacing.s12)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.lifeboard(.surfaceSecondary))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.lifeboard(.strokeHairline), lineWidth: 1)
                        )
                    }
                }

                if store.statements.count < EvaMemoryStoreV3.maxStatements {
                    Button("Add item") {
                        addEntry(to: section)
                    }
                    .font(.lifeboard(.buttonSmall))
                    .buttonStyle(.bordered)
                    .tint(Color.lifeboard(.accentPrimary))
                }
            }
        }
    }

    private func binding(for section: EvaMemoryStatement.Section, entryID: UUID) -> Binding<String> {
        Binding(
            get: {
                store.statements.first(where: { $0.id == entryID })?.text ?? ""
            },
            set: { newValue in
                guard let index = store.statements.firstIndex(where: { $0.id == entryID }) else { return }
                store.statements[index].text = String(newValue.prefix(EvaMemoryStoreV3.maxStatementCharacters))
                persist()
            }
        )
    }

    private func addEntry(to section: EvaMemoryStatement.Section) {
        store.upsert(EvaMemoryStatement(
            section: section,
            text: "New memory",
            provenance: .userStated
        ))
        persist()
    }

    private func deleteEntry(for section: EvaMemoryStatement.Section, entryID: UUID) {
        store.remove(id: entryID)
        persist()
    }

    private func persist() {
        EvaMemoryDefaultsStoreV3.save(store)
    }
}

struct LLMDataPrivacySettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.lifeboardLayoutClass) private var layoutClass
    @Environment(\.lifeboardTokens) private var tokens

    @State private var deleteAllChats = false
    @StateObject private var assistantIdentity = AssistantIdentityModel()
    @Binding var currentThread: Thread?

    private var spacing: SemanticSpacingTokens {
        tokens.spacing
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                SettingsSectionHeader(
                    title: "Data & Privacy",
                    subtitle: "Use destructive actions carefully. Clearing transcripts removes your saved AI conversation history."
                )
                .padding(.top, spacing.s16)

                SettingsDangerZoneCard(
                    title: "Delete All Chats",
                    subtitle: "Permanently delete every saved \(assistantIdentity.snapshot.displayName) thread and message from this device. This cannot be undone.",
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
        .background(Color.lifeboard(.bgCanvas))
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
        Task { @MainActor in
            do {
                let messages = try modelContext.fetch(FetchDescriptor<Message>())
                for message in messages where message.role == .assistant {
                    let renderModel = ChatMessageRenderModel(message: message)
                    if let answer = renderModel.answerText,
                       answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                        await EvaSpokenOutputController.shared.deleteCachedSpeech(for: answer)
                    }
                }
                currentThread = nil
                try modelContext.delete(model: Thread.self)
                try modelContext.delete(model: Message.self)
                try modelContext.save()
            } catch {
                logError("Failed to delete chats.")
            }
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
            return "Save active priorities \(AssistantIdentityText.currentSnapshot().displayName) should keep in view."
        }
    }

    var emptyStateCopy: String {
        switch self {
        case .preferences:
            return "No preferences saved yet. Add the communication style, planning bias, or defaults \(AssistantIdentityText.currentSnapshot().displayName) should remember."
        case .routines:
            return "No routines saved yet. Add recurring rhythms like workout windows, review habits, or shutdown rituals."
        case .currentGoals:
            return "No goals saved yet. Add what matters most right now so \(AssistantIdentityText.currentSnapshot().displayName) can keep advice aligned."
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
