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
                        HStack {
                            Image(systemName: isCurrent ? "checkmark.circle.fill" : "circle")
                            Text(appManager.modelDisplayName(modelName))
                                .tint(.primary)
                            Spacer()
                            Button {
                                deleteModel(modelName)
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(.red)
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
                Label("install a model", systemImage: "arrow.down.circle.dotted")
            }
            #if os(macOS)
            .buttonStyle(.borderless)
            #endif
        }
        .formStyle(.grouped)
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
        }
    }
    
    private func deleteModel(_ name: String) {
        appManager.removeInstalledModel(name)
        postDeleteAdjustments(removedNames: [name])
    }
    
    private func deleteModels(at offsets: IndexSet) {
        // Remove models at specified offsets
        let removedNames = offsets.map { appManager.installedModels[$0] }
        for name in removedNames {
            appManager.removeInstalledModel(name)
        }
        postDeleteAdjustments(removedNames: removedNames)
    }
    
    private func postDeleteAdjustments(removedNames: [String]) {
        // If the current active model was deleted, clear selection or pick first available
        if let current = appManager.currentModelName, removedNames.contains(current) {
            appManager.currentModelName = appManager.installedModels.first
            if let newName = appManager.currentModelName,
               let newModel = ModelConfiguration.availableModels.first(where: { $0.name == newName }) {
                _Concurrency.Task { @MainActor in
                    await llm.switchModel(newModel)
                }
            }
        }
        // Trigger onboarding if no models remain
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
