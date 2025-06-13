//
//  ModelsSettingsView.swift
//  fullmoon
//
//  Created by Jordan Singer on 10/5/24.
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
                        }
                    }
                    #if os(macOS)
                    .buttonStyle(.borderless)
                    #endif
                }
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
