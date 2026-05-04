import SwiftUI

struct ChatsSettingsView: View {
    @EnvironmentObject var appManager: AppManager
    @Environment(\.lifeboardLayoutClass) private var layoutClass
    @State private var isEditingPrompt = false
    @State private var draftPrompt = ""
    @StateObject private var assistantIdentity = AssistantIdentityModel()

    @Binding var currentThread: Thread?

    private var spacing: LifeBoardSpacingTokens {
        LifeBoardThemeManager.shared.tokens(for: layoutClass).spacing
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                SettingsSectionHeader(
                    title: "Chat Behavior",
                    subtitle: "Set the prompt and feedback touches that shape \(assistantIdentity.snapshot.displayName)’s replies."
                )
                .padding(.top, spacing.s16)

                VStack(spacing: spacing.cardStackVertical) {
                    promptCard

                    if layoutClass == .phone {
                        hapticsCard
                    }
                }
                .lifeboardReadableContent(maxWidth: layoutClass.isPad ? 860 : .infinity, alignment: .center)
                .padding(.horizontal, spacing.screenHorizontal)
                .padding(.top, spacing.s12)
            }
            .padding(.bottom, spacing.s24)
        }
        .background(Color.lifeboard(.bgCanvas))
        .navigationTitle("Chat Behavior")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .sheet(isPresented: $isEditingPrompt) {
            NavigationStack {
                PromptEditorView(
                    prompt: $draftPrompt,
                    onSave: {
                        appManager.systemPrompt = draftPrompt
                        isEditingPrompt = false
                    },
                    onCancel: {
                        isEditingPrompt = false
                    },
                    onReset: {
                        draftPrompt = AppManager.defaultSystemPrompt
                    }
                )
            }
            .presentationBackground(Color.lifeboard(.bgCanvas))
        }
    }

    private var promptCard: some View {
        LifeBoardSettingsFieldCard(
            title: "System Prompt",
            subtitle: "Sets \(assistantIdentity.snapshot.displayName)’s baseline tone before task context is added.",
            footer: "Use Default for concise planning help."
        ) {
            VStack(alignment: .leading, spacing: spacing.s12) {
                HStack(spacing: spacing.s8) {
                    promptBadge(title: promptStateLabel, tone: appManager.systemPrompt == AppManager.defaultSystemPrompt ? .neutral : .accent)
                    promptBadge(title: "\(appManager.systemPrompt.count) chars", tone: .neutral)
                }

                Text(appManager.systemPrompt)
                    .font(.lifeboard(.callout))
                    .foregroundStyle(Color.lifeboard(.textPrimary))
                    .lineLimit(4)
                    .frame(maxWidth: .infinity, minHeight: 118, alignment: .topLeading)
                    .padding(spacing.s12)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.lifeboard(.surfaceSecondary))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.lifeboard(.strokeHairline), lineWidth: 1)
                    )

                HStack(spacing: spacing.s8) {
                    Button("Edit Prompt") {
                        draftPrompt = appManager.systemPrompt
                        isEditingPrompt = true
                    }
                    .font(.lifeboard(.buttonSmall))
                    .buttonStyle(.borderedProminent)
                    .tint(Color.lifeboard(.accentPrimary))

                    if appManager.systemPrompt != AppManager.defaultSystemPrompt {
                        Button("Reset to Default") {
                            draftPrompt = AppManager.defaultSystemPrompt
                            isEditingPrompt = true
                        }
                        .font(.lifeboard(.buttonSmall))
                        .buttonStyle(.bordered)
                        .tint(Color.lifeboard(.accentPrimary))
                    }
                }
            }
        }
    }

    private var hapticsCard: some View {
        LifeBoardCard {
            LifeBoardSettingsToggleRow(
                iconName: "waveform.path",
                title: "Chat Haptics",
                subtitle: "Play light haptic feedback when \(assistantIdentity.snapshot.displayName) switches models or finishes key actions.",
                isOn: $appManager.shouldPlayHaptics
            )
        }
    }

    private func promptBadge(title: String, tone: LifeBoardSettingsTone) -> some View {
        Text(title)
            .font(.lifeboard(.caption2))
            .foregroundStyle(badgeForeground(for: tone))
            .padding(.horizontal, spacing.s8)
            .padding(.vertical, spacing.s4)
            .background(badgeBackground(for: tone))
            .clipShape(Capsule())
    }

    private func badgeForeground(for tone: LifeBoardSettingsTone) -> Color {
        switch tone {
        case .accent:
            return Color.lifeboard(.accentPrimary)
        case .neutral:
            return Color.lifeboard(.textSecondary)
        case .success:
            return Color.lifeboard(.statusSuccess)
        case .warning:
            return Color.lifeboard(.statusWarning)
        case .danger:
            return Color.lifeboard(.statusDanger)
        }
    }

    private func badgeBackground(for tone: LifeBoardSettingsTone) -> Color {
        switch tone {
        case .accent:
            return Color.lifeboard(.accentWash)
        case .neutral:
            return Color.lifeboard(.surfaceSecondary)
        case .success:
            return Color.lifeboard(.statusSuccess).opacity(0.14)
        case .warning:
            return Color.lifeboard(.statusWarning).opacity(0.14)
        case .danger:
            return Color.lifeboard(.statusDanger).opacity(0.14)
        }
    }

    private var promptStateLabel: String {
        appManager.systemPrompt == AppManager.defaultSystemPrompt ? "Default" : "Custom"
    }
}

private struct PromptEditorView: View {
    @Environment(\.lifeboardLayoutClass) private var layoutClass
    @Binding var prompt: String
    let onSave: () -> Void
    let onCancel: () -> Void
    let onReset: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            TextEditor(text: $prompt)
                .font(.lifeboard(.callout))
                .foregroundStyle(Color.lifeboard(.textPrimary))
                .padding(16)
                .background(Color.lifeboard(.surfaceSecondary))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .lifeboardReadableContent(maxWidth: layoutClass.isPad ? 900 : .infinity, alignment: .center)
                .padding(.horizontal, LifeBoardSettingsMetrics.screenHorizontal)
                .padding(.top, 16)
        }
        .background(Color.lifeboard(.bgCanvas))
        .navigationTitle("Edit Prompt")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", action: onCancel)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Done", action: onSave)
            }
            ToolbarItem(placement: .bottomBar) {
                Button("Reset to Default", action: onReset)
                    .tint(Color.lifeboard(.accentPrimary))
            }
        }
    }
}

#Preview {
    NavigationStack {
        ChatsSettingsView(currentThread: .constant(nil))
            .environmentObject(AppManager())
    }
}
