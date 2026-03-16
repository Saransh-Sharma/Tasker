import MLXLMCommon
import SwiftUI

struct ModelsSettingsView: View {
    @EnvironmentObject var appManager: AppManager
    @Environment(LLMEvaluator.self) var llm
    @State private var showOnboardingInstallModelView = false

    var body: some View {
        Form {
            Section {
                Text("All AI features use the active model below.")
                    .font(.tasker(.callout))
                    .foregroundStyle(Color.tasker(.textSecondary))
            }

            Section("models") {
                ForEach(ModelConfiguration.availableModels, id: \.name) { model in
                    modelRow(for: model)
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
    private func modelRow(for model: ModelConfiguration) -> some View {
        let isInstalled = appManager.installedModels.contains(model.name)
        let isActive = appManager.currentModelName == model.name

        VStack(alignment: .leading, spacing: TaskerTheme.Spacing.sm) {
            HStack(spacing: TaskerTheme.Spacing.md) {
                VStack(alignment: .leading, spacing: TaskerTheme.Spacing.xs) {
                    Text(model.displayName.lowercased())
                        .font(.tasker(.bodyEmphasis))
                        .foregroundStyle(Color.tasker(.textPrimary))
                    Text(model.shortDescription.lowercased())
                        .font(.tasker(.caption1))
                        .foregroundStyle(Color.tasker(.textSecondary))
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
                }
            }

            HStack(spacing: TaskerTheme.Spacing.sm) {
                if isInstalled == false {
                    Button("install") {
                        showOnboardingInstallModelView = true
                    }
                    .buttonStyle(.borderedProminent)
                } else if isActive == false {
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
        appManager.setActiveModel(modelName)
        appManager.playHaptic()
        _ = await LLMRuntimeCoordinator.shared.switchModelIfNeeded(modelName: modelName)
    }
}

#Preview {
    ModelsSettingsView()
}
