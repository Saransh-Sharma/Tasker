//
//  OnboardingInstallModelView.swift
//
//

import MLXLMCommon
import os
import SwiftUI

struct OnboardingInstallModelView: View {
    @EnvironmentObject var appManager: AppManager
    @State private var deviceSupportsMetal3: Bool = true
    @Binding var showOnboarding: Bool
    @State var selectedModel = ModelConfiguration.defaultModel
    let suggestedModel = ModelConfiguration.defaultModel

    func sizeBadge(_ model: ModelConfiguration?) -> String? {
        guard let size = model?.modelSize else { return nil }
        return "\(size) GB"
    }

    let modelMemoryThreshold = 0.6

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

            if appManager.installedModels.count > 0 {
                Section(header: Text("installed")) {
                    ForEach(appManager.installedModels, id: \.self) { modelName in
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
            } else {
                Section(header: Text("suggested")) {
                    Button { selectedModel = suggestedModel } label: {
                        Label {
                            Text(appManager.modelDisplayName(suggestedModel.name))
                                .font(.tasker(.body))
                                .tint(Color.tasker(.textPrimary))
                        } icon: {
                            Image(systemName: selectedModel.name == suggestedModel.name ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(selectedModel.name == suggestedModel.name ? Color.tasker(.accentPrimary) : Color.tasker(.textQuaternary))
                        }
                    }
                    .badge(sizeBadge(suggestedModel))
                    #if os(macOS)
                        .buttonStyle(.borderless)
                    #endif
                }
            }

            if filteredModels.count > 0 {
                Section(header: Text("other")) {
                    ForEach(filteredModels, id: \.name) { model in
                        Button { selectedModel = model } label: {
                            Label {
                                Text(appManager.modelDisplayName(model.name))
                                    .font(.tasker(.body))
                                    .tint(Color.tasker(.textPrimary))
                            } icon: {
                                Image(systemName: selectedModel.name == model.name ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(selectedModel.name == model.name ? Color.tasker(.accentPrimary) : Color.tasker(.textQuaternary))
                            }
                        }
                        .badge(sizeBadge(model))
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
                .disabled(filteredModels.isEmpty)
            }
            .padding()
            #endif
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Color.tasker(.bgCanvas))
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
                        .disabled(filteredModels.isEmpty)
                    }
                }
                .listStyle(.insetGrouped)
                #endif
                .task {
                    checkModels()
                }
            } else {
                DeviceNotSupportedView()
            }
        }
        .onAppear {
            checkMetal3Support()
        }
    }

    var filteredModels: [ModelConfiguration] {
        ModelConfiguration.availableModels
            .filter { !appManager.installedModels.contains($0.name) }
            .filter { model in
                !(appManager.installedModels.isEmpty && model.name == suggestedModel.name)
            }
            .filter { model in
                guard let size = model.modelSize else { return false }
                return size <= Decimal(modelMemoryThreshold * appManager.availableMemory)
            }
            .sorted { $0.name < $1.name }
    }

    func checkModels() {
        if appManager.installedModels.contains(suggestedModel.name) {
            if let model = filteredModels.first {
                selectedModel = model
            }
        }
    }

    func checkMetal3Support() {
        #if os(iOS)
        if let device = MTLCreateSystemDefaultDevice() {
            deviceSupportsMetal3 = device.supportsFamily(.metal3)
        }
        #endif
    }
}

#Preview {
    @Previewable @State var appManager = AppManager()

    OnboardingInstallModelView(showOnboarding: .constant(true))
        .environmentObject(appManager)
}
