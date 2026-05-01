import SwiftUI

struct HomeEvaChatTopChromeView: View {
    let chromeState: EvaChatNavigationChromeState
    let onBack: () -> Void
    let onSettings: () -> Void
    let onHistory: () -> Void
    let onNewChat: () -> Void

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }

    var body: some View {
        HStack(alignment: .center, spacing: spacing.s12) {
            iconButton(
                systemName: "chevron.left",
                identifier: "home.chat.back",
                label: "Back to Home",
                action: onBack
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(chromeState.title)
                    .font(.tasker(.headline))
                    .foregroundStyle(Color.tasker.textPrimary)
                    .lineLimit(1)

                Text(chromeState.subtitle)
                    .font(.tasker(.caption1))
                    .foregroundStyle(Color.tasker.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if chromeState.showsUtilityActions {
                HStack(spacing: spacing.s4) {
                    iconButton(
                        systemName: "gearshape",
                        identifier: "chat.header.settings",
                        label: "Settings",
                        action: onSettings
                    )

                    if chromeState.showsHistoryAction {
                        iconButton(
                            systemName: "text.below.folder",
                            identifier: "chat.header.history",
                            label: "History",
                            action: onHistory
                        )
                    }

                    if chromeState.showsNewChatAction {
                        iconButton(
                            systemName: "plus.message",
                            identifier: "chat.header.new_chat",
                            label: "New chat",
                            action: onNewChat
                        )
                    }
                }
            }
        }
        .padding(.horizontal, spacing.s16)
        .padding(.top, spacing.s8)
        .padding(.bottom, spacing.s8)
        .accessibilityIdentifier("home.chat.topChrome")
    }

    private func iconButton(
        systemName: String,
        identifier: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.tasker.textSecondary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .scaleOnPress()
        .accessibilityIdentifier(identifier)
        .accessibilityLabel(label)
    }
}
