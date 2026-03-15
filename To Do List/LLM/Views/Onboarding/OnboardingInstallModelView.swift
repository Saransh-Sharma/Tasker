//
//  OnboardingInstallModelView.swift
//
//

import MLXLMCommon
import os
import SwiftUI

struct ModelInstallPickerSections {
    let installedModels: [String]
    let recommendedModel: ModelConfiguration?
    let otherModels: [ModelConfiguration]

    static func make(
        installedModelNames: [String],
        availableModels: [ModelConfiguration] = ModelConfiguration.availableModels,
        defaultModel: ModelConfiguration = .defaultModel,
        availableMemory: Double,
        memoryThreshold: Double
    ) -> Self {
        let downloadableModels = availableModels
            .filter { installedModelNames.contains($0.name) == false }
            .filter { model in
                guard let size = model.modelSize else { return false }
                return size <= Decimal(availableMemory * memoryThreshold)
            }

        return Self(
            installedModels: installedModelNames,
            recommendedModel: downloadableModels.first(where: { $0.name == defaultModel.name }),
            otherModels: downloadableModels
                .filter { $0.name != defaultModel.name }
                .sorted { $0.name < $1.name }
        )
    }
}

struct OnboardingInstallModelView: View {
    @EnvironmentObject var appManager: AppManager
    @State private var deviceSupportsMetal3: Bool = true
    @Binding var showOnboarding: Bool
    @State var selectedModel = ModelConfiguration.defaultModel

    /// Executes sizeBadge.
    func sizeBadge(_ model: ModelConfiguration?) -> String? {
        guard let size = model?.modelSize else { return nil }
        return "\(size) GB"
    }

    let modelMemoryThreshold = 0.6

    var installSections: ModelInstallPickerSections {
        ModelInstallPickerSections.make(
            installedModelNames: appManager.installedModels,
            availableMemory: appManager.availableMemory,
            memoryThreshold: modelMemoryThreshold
        )
    }

    var downloadableModels: [ModelConfiguration] {
        [installSections.recommendedModel].compactMap { $0 } + installSections.otherModels
    }

    var modelsList: some View {
        Form {
            Section {
                VStack(spacing: TaskerTheme.Spacing.lg) {
                    ZStack {
                        Circle()
                            .fill(Color.tasker(.accentWash))
                            .frame(width: 80, height: 80)
                        Image(systemName: "arrow.down.circle.dotted")
                            .font(.system(size: 36, weight: .medium))
                            .foregroundColor(Color.tasker(.accentPrimary))
                            .symbolEffect(.wiggle.byLayer, options: .repeat(.continuous))
                    }

                    VStack(spacing: TaskerTheme.Spacing.xs) {
                        Text("install a model")
                            .font(.tasker(.title1))
                            .foregroundColor(Color.tasker(.textPrimary))
                        Text("select from models optimized for apple silicon")
                            .font(.tasker(.callout))
                            .foregroundColor(Color.tasker(.textSecondary))
                            .multilineTextAlignment(.center)
                        #if DEBUG
                        Text("ram: \(appManager.availableMemory) GB")
                            .font(.tasker(.caption2))
                            .foregroundColor(Color.tasker(.statusDanger))
                        #endif
                    }
                }
                .padding(.vertical, TaskerTheme.Spacing.lg)
                .frame(maxWidth: .infinity)
            }
            .listRowBackground(Color.clear)

            if installSections.installedModels.isEmpty == false {
                Section(header: Text("installed")) {
                    ForEach(installSections.installedModels, id: \.self) { modelName in
                        let model = ModelConfiguration.getModelByName(modelName)
                        Button {} label: {
                            Label {
                                Text(appManager.modelDisplayName(modelName))
                                    .font(.tasker(.body))
                            } icon: {
                                Image(systemName: "checkmark")
                                    .foregroundColor(Color.tasker(.accentPrimary))
                            }
                        }
                        .badge(sizeBadge(model))
                        #if os(macOS)
                            .buttonStyle(.borderless)
                        #endif
                            .foregroundStyle(Color.tasker(.textSecondary))
                            .disabled(true)
                    }
                }
            }

            if let recommendedModel = installSections.recommendedModel {
                Section(header: Text("recommended")) {
                    ModelInstallOptionRow(
                        title: appManager.modelDisplayName(recommendedModel.name),
                        subtitle: "Best default for most devices",
                        sizeText: sizeBadge(recommendedModel),
                        isSelected: selectedModel.name == recommendedModel.name,
                        isRecommended: true,
                        accessibilityIdentifier: "llm.modelPicker.recommendedRow"
                    ) {
                        selectedModel = recommendedModel
                    }
                }
            }

            if installSections.otherModels.isEmpty == false {
                Section(header: Text(installSections.recommendedModel == nil ? "available models" : "other models")) {
                    ForEach(installSections.otherModels, id: \.name) { model in
                        ModelInstallOptionRow(
                            title: appManager.modelDisplayName(model.name),
                            subtitle: nil,
                            sizeText: sizeBadge(model),
                            isSelected: selectedModel.name == model.name,
                            isRecommended: false,
                            accessibilityIdentifier: "llm.modelPicker.row.\(model.name)"
                        ) {
                            selectedModel = model
                        }
                        #if os(macOS)
                        .buttonStyle(.borderless)
                        #endif
                    }
                }
            }

            #if os(macOS)
            Section {} footer: {
                NavigationLink(destination: OnboardingDownloadingModelProgressView(showOnboarding: $showOnboarding, selectedModel: $selectedModel)) {
                    Text("install")
                        .buttonStyle(.borderedProminent)
                }
                .disabled(downloadableModels.isEmpty)
            }
            .padding()
            #endif
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Color.tasker(.bgCanvas))
        .accessibilityIdentifier("llm.modelPicker.view")
    }

    var body: some View {
        ZStack {
            if deviceSupportsMetal3 {
                modelsList
                #if os(iOS) || os(visionOS)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink(destination: OnboardingDownloadingModelProgressView(showOnboarding: $showOnboarding, selectedModel: $selectedModel)) {
                            Text("install")
                                .font(.tasker(.button))
                                .foregroundColor(Color.tasker(.accentPrimary))
                        }
                        .disabled(downloadableModels.isEmpty)
                    }
                }
                .listStyle(.insetGrouped)
                #endif
                .task {
                    syncSelectedModel()
                }
            } else {
                DeviceNotSupportedView()
            }
        }
        .onAppear {
            checkMetal3Support()
        }
    }

    /// Executes syncSelectedModel.
    func syncSelectedModel() {
        guard downloadableModels.contains(where: { $0.name == selectedModel.name }) == false else { return }
        if let recommendedModel = installSections.recommendedModel {
            selectedModel = recommendedModel
        } else if let fallbackModel = installSections.otherModels.first {
            selectedModel = fallbackModel
        }
    }

    /// Executes checkMetal3Support.
    func checkMetal3Support() {
        #if os(iOS)
        if let device = MTLCreateSystemDefaultDevice() {
            deviceSupportsMetal3 = device.supportsFamily(.metal3)
        }
        #endif
    }
}

private struct ModelInstallOptionRow: View {
    let title: String
    let subtitle: String?
    let sizeText: String?
    let isSelected: Bool
    let isRecommended: Bool
    let accessibilityIdentifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: TaskerTheme.Spacing.md) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.tasker(.accentPrimary) : Color.tasker(.textQuaternary))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: TaskerTheme.Spacing.xs) {
                    HStack(spacing: TaskerTheme.Spacing.sm) {
                        Text(title)
                            .font(.tasker(.bodyEmphasis))
                            .foregroundStyle(Color.tasker(.textPrimary))
                            .multilineTextAlignment(.leading)

                        if isRecommended {
                            Text("Recommended")
                                .font(.tasker(.caption1))
                                .foregroundStyle(Color.tasker(.accentPrimary))
                                .padding(.horizontal, TaskerTheme.Spacing.sm)
                                .padding(.vertical, TaskerTheme.Spacing.xs)
                                .background(Color.tasker(.accentWash))
                                .clipShape(Capsule())
                                .accessibilityIdentifier("llm.modelPicker.recommendedBadge")
                        }
                    }

                    if let subtitle {
                        Text(subtitle)
                            .font(.tasker(.callout))
                            .foregroundStyle(Color.tasker(.textSecondary))
                            .multilineTextAlignment(.leading)
                    }
                }

                Spacer(minLength: TaskerTheme.Spacing.md)

                if let sizeText {
                    Text(sizeText)
                        .font(.tasker(.caption1))
                        .foregroundStyle(Color.tasker(.textTertiary))
                }
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .accessibilityIdentifier(accessibilityIdentifier)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(isRecommended ? "Recommended default model for most devices." : "Double tap to select this model for download.")
        .accessibilityValue(isSelected ? "selected" : "not selected")
        #if os(iOS) || os(visionOS)
        .buttonStyle(.plain)
        #endif
    }

    private var accessibilityLabel: String {
        var components = [title]
        if let subtitle {
            components.append(subtitle)
        }
        if isRecommended {
            components.append("Recommended")
        }
        if let sizeText {
            components.append(sizeText)
        }
        return components.joined(separator: ", ")
    }
}

#Preview {
    @Previewable @State var appManager = AppManager()

    OnboardingInstallModelView(showOnboarding: .constant(true))
        .environmentObject(appManager)
}
