import SwiftUI

struct ChatsSettingsView: View {
    @EnvironmentObject var appManager: AppManager
    @Environment(\.lifeboardTokens) private var tokens
    @Environment(\.lifeboardLayoutClass) private var layoutClass
    @State private var isEditingPrompt = false
    @State private var draftPrompt = ""
    @State private var showsAdvanced = false
    @StateObject private var assistantIdentity = AssistantIdentityModel()

    @Binding var currentThread: Thread?

    private var spacing: SemanticSpacingTokens {
        tokens.spacing
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                SettingsSectionHeader(
                    title: String(localized: "Chat behavior"),
                    subtitle: ""
                )
                .padding(.top, spacing.s16)

                VStack(spacing: spacing.cardStackVertical) {
                    if layoutClass == .phone {
                        hapticsCard
                    }

                    // The instructions editor is for people who want to
                    // rewrite them; everyone else never needs to see it.
                    SurfaceCard {
                        DisclosureGroup(isExpanded: $showsAdvanced) {
                            promptCard
                                .padding(.top, spacing.s12)
                        } label: {
                            Text("Advanced")
                                .font(.lifeboard(.bodyEmphasis))
                                .foregroundStyle(Color.lifeboard(.textPrimary))
                        }
                        .tint(Color.lifeboard(.accentPrimary))
                        .accessibilityIdentifier("chatsSettings.advanced")
                    }
                }
                .lifeboardReadableContent(maxWidth: layoutClass.isPad ? 860 : .infinity, alignment: .center)
                .padding(.horizontal, spacing.screenHorizontal)
                .padding(.top, spacing.s12)
            }
            .padding(.bottom, spacing.s24)
        }
        .background(Color.lifeboard(.bgCanvas))
        .navigationTitle("Chat behavior")
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
        SettingsFieldCard(
            title: String(localized: "Instructions"),
            subtitle: String(localized: "Sent to \(assistantIdentity.snapshot.displayName) before every chat."),
            footer: ""
        ) {
            VStack(alignment: .leading, spacing: spacing.s12) {
                promptBadge(title: promptStateLabel, tone: appManager.systemPrompt == AppManager.defaultSystemPrompt ? .neutral : .accent)

                Text(appManager.systemPrompt)
                    .font(.lifeboard(.callout))
                    .foregroundStyle(Color.lifeboard(.textPrimary))
                    .lineLimit(4)
                    .frame(maxWidth: .infinity, minHeight: 118, alignment: .topLeading)
                    .padding(spacing.s12)
                    .background(
                        RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                            .fill(Color.lifeboard(.surfaceSecondary))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                            .stroke(Color.lifeboard(.strokeHairline), lineWidth: 1)
                    )

                HStack(spacing: spacing.s8) {
                    Button("Edit instructions") {
                        draftPrompt = appManager.systemPrompt
                        isEditingPrompt = true
                    }
                    .font(.lifeboard(.buttonSmall))
                    .buttonStyle(.lifeBoardPrimaryCompact)
                    .tint(Color.lifeboard(.accentPrimary))

                    if appManager.systemPrompt != AppManager.defaultSystemPrompt {
                        Button("Reset to default") {
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
        SurfaceCard {
            SettingsToggleRow(
                iconName: "waveform.path",
                title: String(localized: "Haptics in chat"),
                subtitle: String(localized: "Tap on send and when \(assistantIdentity.snapshot.displayName) replies."),
                isOn: $appManager.shouldPlayHaptics
            )
        }
    }

    private func promptBadge(title: String, tone: SettingsTone) -> some View {
        Text(title)
            .font(.lifeboard(.caption2))
            .foregroundStyle(badgeForeground(for: tone))
            .padding(.horizontal, spacing.s8)
            .padding(.vertical, spacing.s4)
            .background(badgeBackground(for: tone))
            .clipShape(Capsule())
    }

    private func badgeForeground(for tone: SettingsTone) -> Color {
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

    private func badgeBackground(for tone: SettingsTone) -> Color {
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
        appManager.systemPrompt == AppManager.defaultSystemPrompt ? String(localized: "Default") : String(localized: "Custom")
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
                // Reset sits in the bottom bar under the keyboard; Done is the
                // way back to it without dragging inside the editor.
                .keyboardBar()
                .foregroundStyle(Color.lifeboard(.textPrimary))
                .padding(16)
                .background(Color.lifeboard(.surfaceSecondary))
                .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                .lifeboardReadableContent(maxWidth: layoutClass.isPad ? 900 : .infinity, alignment: .center)
                .padding(.horizontal, SettingsMetrics.screenHorizontal)
                .padding(.top, 16)
        }
        .background(Color.lifeboard(.bgCanvas))
        .navigationTitle("Edit instructions")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Done", action: onSave)
            }
            ToolbarItem(placement: .bottomBar) {
                Button("Reset to default", action: onReset)
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
