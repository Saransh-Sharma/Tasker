//
//  LLMSettingsView.swift
//
//

import SwiftUI

struct LLMSettingsView: View {
    @EnvironmentObject var appManager: AppManager
    @Environment(\.dismiss) var dismiss
    @Environment(LLMEvaluator.self) var llm
    @Binding var currentThread: Thread?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NavigationLink(destination: AppearanceSettingsView()) {
                        Label("appearance", systemImage: "paintpalette")
                    }

                    NavigationLink(destination: ChatsSettingsView(currentThread: $currentThread)) {
                        Label("chats", systemImage: "message")
                    }

                    NavigationLink(destination: ModelsSettingsView()) {
                        Label {
                            Text("models")
                                .fixedSize()
                        } icon: {
                            Image(systemName: "arrow.down.circle")
                        }
                        .badge(appManager.modelDisplayName(appManager.currentModelName ?? ""))
                    }
                }

                Section {
                    NavigationLink(destination: CreditsView()) {
                        Text("credits")
                    }
                }

                Section {} footer: {
                    HStack {
                        Spacer()
                        VStack(spacing: 4) {
                            Image(systemName: appManager.getMoonPhaseIcon())
                                .foregroundStyle(.quaternary)
                            Text("v\(Bundle.main.releaseVersionNumber ?? "0").\(Bundle.main.buildVersionNumber ?? "0")")
                                .font(.footnote)
                                .foregroundStyle(.tertiary)
                            Text("made by Mainframe")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            #if os(macOS)
                                .padding(.top, 11)
                            #else
                                .padding(.top, 16)
                            #endif
                        }
                        Spacer()
                    }
                    .padding(.vertical)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("settings")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar {
                    #if os(iOS) || os(visionOS)
                    ToolbarItem(placement: .topBarLeading) {
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                        }
                    }
                    #elseif os(macOS)
                    ToolbarItem(placement: .destructiveAction) {
                        Button(action: { dismiss() }) {
                            Text("close")
                        }
                    }
                    #endif
                }
        }
        #if !os(visionOS)
        .tint(appManager.appTintColor.getColor())
        #endif
        .environment(\.dynamicTypeSize, appManager.appFontSize.getFontSize())
    }
}

extension Bundle {
    var releaseVersionNumber: String? {
        return infoDictionary?["CFBundleShortVersionString"] as? String
    }

    var buildVersionNumber: String? {
        return infoDictionary?["CFBundleVersion"] as? String
    }
}

#Preview {
    LLMSettingsView(currentThread: .constant(nil))
        .environmentObject(AppManager())
        .environment(LLMEvaluator())
}
