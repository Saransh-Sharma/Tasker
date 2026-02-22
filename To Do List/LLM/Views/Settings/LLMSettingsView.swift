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
                    NavigationLink(destination: ChatsSettingsView(currentThread: $currentThread)) {
                        HStack(spacing: TaskerTheme.Spacing.md) {
                            ZStack {
                                RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.sm, style: .continuous)
                                    .fill(Color.tasker(.accentWash))
                                    .frame(width: 32, height: 32)
                                Image(systemName: "message.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color.tasker(.accentPrimary))
                            }
                            Text("Chats")
                                .font(.tasker(.body))
                                .foregroundColor(Color.tasker(.textPrimary))
                        }
                    }

                    NavigationLink(destination: ModelsSettingsView()) {
                        HStack(spacing: TaskerTheme.Spacing.md) {
                            ZStack {
                                RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.sm, style: .continuous)
                                    .fill(Color.tasker(.accentWash))
                                    .frame(width: 32, height: 32)
                                Image(systemName: "arrow.down.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color.tasker(.accentPrimary))
                            }
                            Text("Models")
                                .font(.tasker(.body))
                                .foregroundColor(Color.tasker(.textPrimary))
                                .fixedSize()
                            Spacer()
                            Text(appManager.modelDisplayName(appManager.currentModelName ?? ""))
                                .font(.tasker(.caption1))
                                .foregroundColor(Color.tasker(.textTertiary))
                        }
                    }
                }

                Section {} footer: {
                    HStack {
                        Spacer()
                        Text("Made with care by Saransh")
                            .font(.tasker(.caption2))
                            .foregroundColor(Color.tasker(.textQuaternary))
                        Spacer()
                    }
                    .padding(.vertical, TaskerTheme.Spacing.lg)
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(Color.tasker(.bgCanvas))
            .navigationTitle("Settings")
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
                            Text(TaskerCopy.Actions.close)
                        }
                    }
                    #endif
                }
        }
        .tint(Color.tasker(.accentPrimary))
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
