import MLXLMCommon
import SwiftUI

struct ModelsSettingsView: View {
    @EnvironmentObject var appManager: AppManager
    @Environment(LLMEvaluator.self) var llm
    @State private var showOnboardingInstallModelView = false

    private var catalog: LocalModelInstallCatalog {
        LocalModelInstallCatalog.make(
            installedModelNames: appManager.installedModels,
            availableMemory: appManager.availableMemory
        )
    }

    var body: some View {
        Form {
            Section {
                Text("All AI features use the active model below. Qwen3 0.6B is the default fast path, while the Qwen 3.5 text models are available for higher-quality local responses.")
                    .font(.tasker(.callout))
                    .foregroundStyle(Color.tasker(.textSecondary))
            }

            if catalog.installedEntries.isEmpty == false {
                Section("installed") {
                    ForEach(catalog.installedEntries) { entry in
                        modelRow(for: entry)
                    }
                }
            }

            ForEach(catalog.sections) { section in
                Section(section.kind.title) {
                    ForEach(section.entries) { entry in
                        modelRow(for: entry)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Color.tasker(.bgCanvas))
        .navigationTitle("models")
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
                        ToolbarItem(placement: .topBarLeading) {
                            Button(action: { showOnboardingInstallModelView = false }) {
                                Image(systemName: "xmark")
                            }
                        }
                        #elseif os(macOS)
                        ToolbarItem(placement: .destructiveAction) {
                            Button(action: { showOnboardingInstallModelView = false }) {
                                Text("close")
                            }
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

    @ViewBuilder
    private func modelRow(for entry: LLMCatalogEntry) -> some View {
        let model = entry.model
        let isInstalled = entry.isInstalled
        let isActive = appManager.currentModelName == model.name
        let compatibility = entry.compatibility

        VStack(alignment: .leading, spacing: TaskerTheme.Spacing.sm) {
            HStack(spacing: TaskerTheme.Spacing.md) {
                VStack(alignment: .leading, spacing: TaskerTheme.Spacing.xs) {
                    Text(model.displayName.lowercased())
                        .font(.tasker(.bodyEmphasis))
                        .foregroundStyle(Color.tasker(.textPrimary))
                    Text(model.shortDescription.lowercased())
                        .font(.tasker(.caption1))
                        .foregroundStyle(Color.tasker(.textSecondary))
                    if let statusReason = compatibility.statusReason,
                       compatibility.canActivate == false {
                        Text(statusReason)
                            .font(.tasker(.caption1))
                            .foregroundStyle(Color.tasker(.statusWarning))
                    }
                }

                Spacer()

                if isActive {
                    Text("active")
                        .font(.tasker(.caption1))
                        .foregroundStyle(Color.tasker(.accentPrimary))
                        .padding(.horizontal, TaskerTheme.Spacing.sm)
                        .padding(.vertical, TaskerTheme.Spacing.xs)
                        .background(Color.tasker(.accentWash))
                        .clipShape(Capsule())
                } else if let statusBadgeTitle = compatibility.statusBadgeTitle {
                    Text(statusBadgeTitle.lowercased())
                        .font(.tasker(.caption1))
                        .foregroundStyle(Color.tasker(.textTertiary))
                        .padding(.horizontal, TaskerTheme.Spacing.sm)
                        .padding(.vertical, TaskerTheme.Spacing.xs)
                        .background(Color.tasker(.accentWash))
                        .clipShape(Capsule())
                }
            }

            HStack(spacing: TaskerTheme.Spacing.sm) {
                if isInstalled == false && compatibility.canInstall {
                    Button("install") {
                        showOnboardingInstallModelView = true
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("llmSettings.installModelButton")
                } else if isInstalled && isActive == false && compatibility.canActivate {
                    Button("make active") {
                        Task {
                            await switchModel(model.name)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }

                if isInstalled {
                    Button(role: .destructive) {
                        deleteModel(model.name)
                    } label: {
                        Text("delete")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(.vertical, TaskerTheme.Spacing.xs)
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
    ModelsSettingsView()
}
