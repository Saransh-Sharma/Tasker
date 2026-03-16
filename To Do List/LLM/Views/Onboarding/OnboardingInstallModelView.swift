import MLXLMCommon
import SwiftUI

struct TwoQwenModelInstallCatalog {
    let installedModels: [String]
    let installableModels: [ModelConfiguration]

    static func make(installedModelNames: [String], availableMemory: Double) -> Self {
        let maxSupportedSizeGB: Decimal
        if availableMemory < 4 {
            maxSupportedSizeGB = 0.5
        } else if availableMemory < 6 {
            maxSupportedSizeGB = 0.7
        } else {
            maxSupportedSizeGB = 1.2
        }

        let installableModels = ModelConfiguration.availableModels.filter { model in
            guard installedModelNames.contains(model.name) == false else { return false }
            guard let size = model.modelSize else { return false }
            return size <= maxSupportedSizeGB
        }

        return Self(
            installedModels: installedModelNames,
            installableModels: installableModels
        )
    }
}

struct OnboardingInstallModelView: View {
    @EnvironmentObject var appManager: AppManager
    @State private var deviceSupportsMetal3 = true
    @Binding var showOnboarding: Bool
    @State private var selectedModelNames: Set<String> = [ModelConfiguration.defaultModel.name]

    private var catalog: TwoQwenModelInstallCatalog {
        TwoQwenModelInstallCatalog.make(
            installedModelNames: appManager.installedModels,
            availableMemory: appManager.availableMemory
        )
    }

    private var selectedModels: [ModelConfiguration] {
        ModelConfiguration.availableModels.filter { selectedModelNames.contains($0.name) }
    }

    private var canInstall: Bool {
        selectedModels.isEmpty == false
    }

    var body: some View {
        ZStack {
            if deviceSupportsMetal3 {
                content
                    .task {
                        syncSelection()
                    }
            } else {
                DeviceNotSupportedView()
            }
        }
        .onAppear {
            checkMetal3Support()
        }
    }

    private var content: some View {
        Form {
            Section {
                VStack(spacing: TaskerTheme.Spacing.lg) {
                    ZStack {
                        Circle()
                            .fill(Color.tasker(.accentWash))
                            .frame(width: 80, height: 80)
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 34, weight: .medium))
                            .foregroundStyle(Color.tasker(.accentPrimary))
                    }

                    VStack(spacing: TaskerTheme.Spacing.xs) {
                        Text("choose your local models")
                            .font(.tasker(.title1))
                            .foregroundStyle(Color.tasker(.textPrimary))
                        Text("install one or both qwen models. all AI features use the active model you choose later.")
                            .font(.tasker(.callout))
                            .foregroundStyle(Color.tasker(.textSecondary))
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.vertical, TaskerTheme.Spacing.lg)
                .frame(maxWidth: .infinity)
            }
            .listRowBackground(Color.clear)

            if catalog.installedModels.isEmpty == false {
                Section("installed") {
                    ForEach(catalog.installedModels, id: \.self) { modelName in
                        let title = appManager.modelDisplayName(modelName)
                        HStack(spacing: TaskerTheme.Spacing.md) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.tasker(.accentPrimary))
                            Text(title)
                                .font(.tasker(.bodyEmphasis))
                                .foregroundStyle(Color.tasker(.textPrimary))
                            Spacer()
                            Text("installed")
                                .font(.tasker(.caption1))
                                .foregroundStyle(Color.tasker(.textTertiary))
                        }
                    }
                }
            }

            Section("available") {
                ForEach(catalog.installableModels, id: \.name) { model in
                    TwoQwenModelOptionCard(
                        model: model,
                        isSelected: selectedModelNames.contains(model.name)
                    ) {
                        toggleSelection(for: model)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    .listRowBackground(Color.clear)
                }
            }

            #if os(macOS)
            Section {} footer: {
                NavigationLink(
                    destination: OnboardingDownloadingModelProgressView(
                        showOnboarding: $showOnboarding,
                        selectedModels: selectedModels
                    )
                ) {
                    Text("install selected models")
                }
                .disabled(!canInstall)
            }
            #endif
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Color.tasker(.bgCanvas))
        .accessibilityIdentifier("llm.modelPicker.view")
        #if os(iOS) || os(visionOS)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(
                    destination: OnboardingDownloadingModelProgressView(
                        showOnboarding: $showOnboarding,
                        selectedModels: selectedModels
                    )
                ) {
                    Text("install")
                        .font(.tasker(.button))
                        .foregroundStyle(Color.tasker(.accentPrimary))
                }
                .disabled(!canInstall)
            }
        }
        .listStyle(.insetGrouped)
        #endif
    }

    private func toggleSelection(for model: ModelConfiguration) {
        if selectedModelNames.contains(model.name) {
            selectedModelNames.remove(model.name)
        } else {
            selectedModelNames.insert(model.name)
        }
    }

    private func syncSelection() {
        let installableNames = Set(catalog.installableModels.map(\.name))
        selectedModelNames = selectedModelNames.intersection(installableNames)
        if selectedModelNames.isEmpty,
           let defaultInstall = catalog.installableModels.first(where: { $0 == .defaultModel }) ?? catalog.installableModels.first {
            selectedModelNames = [defaultInstall.name]
        }
    }

    private func checkMetal3Support() {
        #if os(iOS)
        if let device = MTLCreateSystemDefaultDevice() {
            deviceSupportsMetal3 = device.supportsFamily(.metal3)
        }
        #endif
    }
}

private struct TwoQwenModelOptionCard: View {
    let model: ModelConfiguration
    let isSelected: Bool
    let action: () -> Void

    private var sizeLabel: String {
        "\(model.modelSize.map { NSDecimalNumber(decimal: $0).stringValue } ?? "?") GB"
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: TaskerTheme.Spacing.md) {
                HStack(spacing: TaskerTheme.Spacing.sm) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(isSelected ? Color.tasker(.accentPrimary) : Color.tasker(.textQuaternary))

                    Text(model.displayName)
                        .font(.tasker(.headline))
                        .foregroundStyle(Color.tasker(.textPrimary))

                    Spacer()

                    Text(model.onboardingBadgeTitle)
                        .font(.tasker(.caption1))
                        .foregroundStyle(Color.tasker(.accentPrimary))
                        .padding(.horizontal, TaskerTheme.Spacing.sm)
                        .padding(.vertical, TaskerTheme.Spacing.xs)
                        .background(Color.tasker(.accentWash))
                        .clipShape(Capsule())
                }

                Text(model.shortDescription)
                    .font(.tasker(.callout))
                    .foregroundStyle(Color.tasker(.textSecondary))
                    .multilineTextAlignment(.leading)

                HStack {
                    Text(sizeLabel)
                        .font(.tasker(.caption1))
                        .foregroundStyle(Color.tasker(.textTertiary))
                    Spacer()
                    Text(model.onboardingSubtitle)
                        .font(.tasker(.caption2))
                        .foregroundStyle(Color.tasker(.textQuaternary))
                        .multilineTextAlignment(.trailing)
                }
            }
            .padding(TaskerTheme.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.lg, style: .continuous)
                    .fill(isSelected ? Color.tasker(.accentWash) : Color.tasker(.bgElevated))
            )
            .overlay(
                RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.lg, style: .continuous)
                    .stroke(isSelected ? Color.tasker(.accentPrimary) : Color.tasker(.borderSubtle), lineWidth: 1)
            )
        }
        #if os(macOS)
        .buttonStyle(.plain)
        #endif
    }
}

#Preview {
    NavigationStack {
        OnboardingInstallModelView(showOnboarding: .constant(true))
            .environmentObject(AppManager())
    }
}
