//
//  ModelsSettingsView.swift
//
//

import SwiftUI
import MLXLMCommon

struct ModelsSettingsView: View {
    @EnvironmentObject var appManager: AppManager
    @Environment(LLMEvaluator.self) var llm
    @State var showOnboardingInstallModelView = false

    var body: some View {
        Form {
            Section(header: Text("installed")) {
                ForEach(appManager.installedModels, id: \.self) { modelName in
                    let isCurrent = (appManager.currentModelName == modelName)
                    Button {
                        _Concurrency.Task {
                            await switchModel(modelName)
                        }
                    } label: {
                        HStack(spacing: TaskerTheme.Spacing.md) {
                            Image(systemName: isCurrent ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundColor(isCurrent ? Color.tasker(.accentPrimary) : Color.tasker(.textQuaternary))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(appManager.modelDisplayName(modelName))
                                    .font(.tasker(.bodyEmphasis))
                                    .foregroundColor(Color.tasker(.textPrimary))
                                    .tint(Color.tasker(.textPrimary))

                                if isCurrent {
                                    Text("active")
                                        .font(.tasker(.caption2))
                                        .foregroundColor(Color.tasker(.accentPrimary))
                                }
                            }

                            Spacer()

                            Button {
                                deleteModel(modelName)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.callout)
                                    .foregroundColor(Color.tasker(.statusDanger).opacity(0.7))
                                    .frame(width: 36, height: 36)
                                    .background(Color.tasker(.statusDanger).opacity(0.08))
                                    .clipShape(Circle())
                            }
                            #if os(macOS)
                            .buttonStyle(.borderless)
                            #endif
                        }
                    }
                    #if os(macOS)
                    .buttonStyle(.borderless)
                    #endif
                }
                .onDelete(perform: deleteModels)
            }

            Button {
                showOnboardingInstallModelView.toggle()
            } label: {
                Label {
                    Text("install a model")
                        .font(.tasker(.bodyEmphasis))
                        .foregroundColor(Color.tasker(.accentPrimary))
                } icon: {
                    Image(systemName: "arrow.down.circle.dotted")
                        .foregroundColor(Color.tasker(.accentPrimary))
                }
            }
            #if os(macOS)
            .buttonStyle(.borderless)
            #endif
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Color.tasker(.bgCanvas))
        .navigationTitle("models")
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

    private func deleteModel(_ name: String) {
        appManager.removeInstalledModel(name)
        postDeleteAdjustments(removedNames: [name])
    }

    private func deleteModels(at offsets: IndexSet) {
        let removedNames = offsets.map { appManager.installedModels[$0] }
        for name in removedNames {
            appManager.removeInstalledModel(name)
        }
        postDeleteAdjustments(removedNames: removedNames)
    }

    private func postDeleteAdjustments(removedNames: [String]) {
        if let current = appManager.currentModelName, removedNames.contains(current) {
            appManager.currentModelName = appManager.installedModels.first
            if let newName = appManager.currentModelName,
               let newModel = ModelConfiguration.availableModels.first(where: { $0.name == newName }) {
                _Concurrency.Task { @MainActor in
                    await llm.switchModel(newModel)
                }
            }
        }
        if appManager.installedModels.isEmpty {
            showOnboardingInstallModelView = true
        }
    }

    private func switchModel(_ modelName: String) async {
        if let model = ModelConfiguration.availableModels.first(where: {
            $0.name == modelName
        }) {
            appManager.currentModelName = modelName
            appManager.playHaptic()
            await llm.switchModel(model)
        }
    }
}

#Preview {
    ModelsSettingsView()
}
