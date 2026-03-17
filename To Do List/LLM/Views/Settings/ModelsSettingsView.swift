import MLXLMCommon
import SwiftUI

struct ModelsSettingsView: View {
    @EnvironmentObject var appManager: AppManager
    @Environment(LLMEvaluator.self) var llm
    @Environment(\.taskerLayoutClass) private var layoutClass

    @State private var showOnboardingInstallModelView = false

    private var spacing: TaskerSpacingTokens {
        TaskerThemeManager.shared.tokens(for: layoutClass).spacing
    }

    private var catalog: LocalModelInstallCatalog {
        LocalModelInstallCatalog.make(
            installedModelNames: appManager.installedModels,
            availableMemory: appManager.availableMemory
        )
    }

    private var heroItems: [TaskerSettingsStatusDescriptor] {
        [
            TaskerSettingsStatusDescriptor(
                id: "active",
                title: "Active",
                value: activeModelName,
                systemImage: "brain.head.profile",
                tone: .accent
            ),
            TaskerSettingsStatusDescriptor(
                id: "installed",
                title: "Installed",
                value: "\(catalog.installedEntries.count) local",
                systemImage: "arrow.down.circle.fill",
                tone: catalog.installedEntries.isEmpty ? .warning : .success
            ),
            TaskerSettingsStatusDescriptor(
                id: "device",
                title: "Device",
                value: deviceCompatibilitySummary,
                systemImage: "checkmark.shield.fill",
                tone: deviceCompatibilitySummary == "Compatible" ? .success : .warning
            ),
        ]
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                TaskerSettingsHeroCard(
                    eyebrow: "Models",
                    title: "Choose Eva’s model",
                    subtitle: "Keep the default model fast, or install stronger local models when needed.",
                    statusItems: heroItems
                )
                .padding(.horizontal, spacing.screenHorizontal)
                .padding(.top, spacing.s16)

                if catalog.installedEntries.isEmpty == false {
                    section(
                        title: "Installed",
                        subtitle: "Ready to use now.",
                        entries: catalog.installedEntries,
                        baseIndex: 1
                    )
                }

                ForEach(Array(catalog.sections.enumerated()), id: \.offset) { index, section in
                    self.section(
                        title: sectionTitle(for: section.kind),
                        subtitle: sectionSubtitle(for: section.kind),
                        entries: section.entries,
                        baseIndex: 4 + (index * 3)
                    )
                }
            }
            .padding(.bottom, spacing.s24)
        }
        .background(Color.tasker(.bgCanvas))
        .navigationTitle("Models")
        .accessibilityIdentifier("llmSettings.modelsView")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .sheet(isPresented: $showOnboardingInstallModelView) {
            NavigationStack {
                OnboardingInstallModelView(showOnboarding: $showOnboardingInstallModelView)
                    .environment(llm)
                    .toolbar {
                        #if os(iOS) || os(visionOS)
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { showOnboardingInstallModelView = false }
                        }
                        #elseif os(macOS)
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showOnboardingInstallModelView = false }
                        }
                        #endif
                    }
            }
            #if os(iOS)
            .presentationBackground(Color.tasker(.bgElevated))
            .presentationCornerRadius(TaskerTheme.CornerRadius.xl)
            #endif
        }
    }

    private func section(
        title: String,
        subtitle: String,
        entries: [LLMCatalogEntry],
        baseIndex: Int
    ) -> some View {
        VStack(spacing: 0) {
            SettingsSectionHeader(title: title, subtitle: subtitle)
                .enhancedStaggeredAppearance(index: baseIndex)
                .padding(.top, spacing.sectionGap)

            VStack(spacing: spacing.cardStackVertical) {
                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    modelCard(for: entry)
                        .enhancedStaggeredAppearance(index: baseIndex + index + 1)
                }
            }
            .padding(.horizontal, spacing.screenHorizontal)
            .padding(.top, spacing.s12)
        }
    }

    @ViewBuilder
    private func modelCard(for entry: LLMCatalogEntry) -> some View {
        let model = entry.model
        let isInstalled = entry.isInstalled
        let isActive = appManager.currentModelName == model.name
        let compatibility = entry.compatibility

        TaskerCard(active: isActive, elevated: true) {
            VStack(alignment: .leading, spacing: spacing.s12) {
                HStack(alignment: .top, spacing: spacing.s12) {
                    SettingsRowIcon(
                        iconName: isActive ? "brain.fill" : "cpu.fill",
                        tone: isActive ? .accent : .neutral
                    )

                    VStack(alignment: .leading, spacing: spacing.s4) {
                        Text(model.displayName)
                            .font(.tasker(.headline))
                            .foregroundStyle(Color.tasker(.textPrimary))

                        Text(modelCardDescription(for: model))
                            .font(.tasker(.callout))
                            .foregroundStyle(Color.tasker(.textSecondary))
                            .lineLimit(2)
                    }

                    Spacer(minLength: spacing.s8)
                }

                modelBadges(
                    isInstalled: isInstalled,
                    isActive: isActive,
                    statusBadgeTitle: compatibility.statusBadgeTitle,
                    canActivate: compatibility.canActivate
                )

                if let statusReason = compatibility.statusReason,
                   compatibility.canActivate == false {
                    Text(statusReason)
                        .font(.tasker(.caption1))
                        .foregroundStyle(Color.tasker(.statusWarning))
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: spacing.s8) {
                    if isInstalled == false && compatibility.canInstall {
                        Button("Install") {
                            showOnboardingInstallModelView = true
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.tasker(.accentPrimary))
                        .accessibilityIdentifier("llmSettings.installModelButton")
                    } else if isInstalled && isActive == false && compatibility.canActivate {
                        Button("Set Active") {
                            Task {
                                await switchModel(model.name)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.tasker(.accentPrimary))
                    }

                    if isInstalled && isActive == false {
                        Button(role: .destructive) {
                            deleteModel(model.name)
                        } label: {
                            Text("Remove")
                        }
                        .buttonStyle(.bordered)
                    } else if isInstalled && isActive {
                        Menu {
                            Button(role: .destructive) {
                                deleteModel(model.name)
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(Color.tasker(.textSecondary))
                                .frame(width: 44, height: 44)
                        }
                    }
                }
            }
        }
    }

    private func modelBadges(
        isInstalled: Bool,
        isActive: Bool,
        statusBadgeTitle: String?,
        canActivate: Bool
    ) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: spacing.s8) {
                if isActive {
                    modelBadge("Active", tone: .accent)
                }

                if isInstalled {
                    modelBadge("Installed", tone: .success)
                }

                if let statusBadgeTitle {
                    modelBadge(statusBadgeTitle, tone: canActivate ? .neutral : .warning)
                }
            }
        }
    }

    private func modelBadge(_ title: String, tone: TaskerSettingsTone) -> some View {
        Text(title)
            .font(.tasker(.caption2))
            .foregroundStyle(badgeForeground(for: tone))
            .padding(.horizontal, spacing.s8)
            .padding(.vertical, spacing.s4)
            .background(badgeBackground(for: tone))
            .clipShape(Capsule())
    }

    private func badgeForeground(for tone: TaskerSettingsTone) -> Color {
        switch tone {
        case .accent:
            return Color.tasker(.accentPrimary)
        case .neutral:
            return Color.tasker(.textSecondary)
        case .success:
            return Color.tasker(.statusSuccess)
        case .warning:
            return Color.tasker(.statusWarning)
        case .danger:
            return Color.tasker(.statusDanger)
        }
    }

    private func badgeBackground(for tone: TaskerSettingsTone) -> Color {
        switch tone {
        case .accent:
            return Color.tasker(.accentWash)
        case .neutral:
            return Color.tasker(.surfaceSecondary)
        case .success:
            return Color.tasker(.statusSuccess).opacity(0.14)
        case .warning:
            return Color.tasker(.statusWarning).opacity(0.14)
        case .danger:
            return Color.tasker(.statusDanger).opacity(0.14)
        }
    }

    private var activeModelName: String {
        guard let current = appManager.currentModelName, !current.isEmpty else {
            return "No active model"
        }
        return appManager.compactModelDisplayName(current)
    }

    private var deviceCompatibilitySummary: String {
        guard let currentModel = appManager.currentModelName,
              let compatibility = LLMRuntimeSupportMatrix.compatibility(for: currentModel) else {
            return "Compatible"
        }
        return compatibility.canActivate ? "Compatible" : (compatibility.statusBadgeTitle ?? "Limited")
    }

    private func sectionTitle(for kind: LLMCatalogSectionKind) -> String {
        switch kind {
        case .availableNow:
            return "Available"
        case .additionalTextModels:
            return "Alternatives"
        }
    }

    private func sectionSubtitle(for kind: LLMCatalogSectionKind) -> String {
        switch kind {
        case .availableNow:
            return "Install another local model."
        case .additionalTextModels:
            return "Other lightweight text models."
        }
    }

    private func modelCardDescription(for model: ModelConfiguration) -> String {
        switch model {
        case .qwen_3_0_6b_4bit:
            return "Fastest and lightest. Best default for all devices."
        case .qwen_3_5_0_8b_claude_4_6_opus_reasoning_distilled_4bit:
            return "Stronger reasoning model. Slightly slower and uses more memory."
        case .qwen_3_5_0_8b_optiq_4bit:
            return "More capable, slightly slower, and uses more RAM."
        case .qwen_3_5_0_8b_nexveridian_4bit:
            return "Lightweight alternative with a different response style."
        default:
            return model.shortDescription
        }
    }

    private func deleteModel(_ name: String) {
        appManager.removeInstalledModel(name)
        if appManager.currentModelName == name {
            let fallback = appManager.preferredFallbackModelName(excluding: name)
            appManager.setActiveModel(fallback)
            if let fallback {
                Task {
                    _ = await LLMRuntimeCoordinator.shared.switchModelIfNeeded(modelName: fallback)
                }
            } else {
                showOnboardingInstallModelView = true
            }
        }
    }

    private func switchModel(_ modelName: String) async {
        guard appManager.installedModels.contains(modelName) else {
            showOnboardingInstallModelView = true
            return
        }
        guard LLMRuntimeSupportMatrix.compatibility(for: modelName)?.canActivate == true else {
            return
        }
        appManager.setActiveModel(modelName)
        appManager.playHaptic()
        _ = await LLMRuntimeCoordinator.shared.switchModelIfNeeded(modelName: modelName)
    }
}

#Preview {
    NavigationStack {
        ModelsSettingsView()
            .environmentObject(AppManager())
    }
}
