import SwiftUI

struct ChatHeaderView: View {
    let identity: AssistantIdentitySnapshot
    let title: String
    let subtitle: String
    let showsNewChatAction: Bool
    let showsUtilityActions: Bool
    let onStartNewChat: () -> Void
    let onShowSettings: () -> Void

    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        HStack(alignment: .top, spacing: LifeBoardTheme.Spacing.md) {
            VStack(alignment: .leading, spacing: 4) {
                Text(identity.displayName)
                    .lifeboardFont(.display)
                    .foregroundStyle(Color.lifeboard(.textPrimary))

                Text(title)
                    .lifeboardFont(.caption1)
                    .foregroundStyle(Color.lifeboard(.textSecondary))
                    .lineLimit(1)

                Text(subtitle)
                    .lifeboardFont(.caption1)
                    .foregroundStyle(Color.lifeboard(.textSecondary))
                    .lineLimit(2)
            }

            Spacer(minLength: LifeBoardTheme.Spacing.sm)

            if showsUtilityActions {
                HStack(spacing: LifeBoardTheme.Spacing.xs) {
                    if showsNewChatAction {
                        newChatButton
                    }

                    iconButton(
                        systemName: "gearshape",
                        identifier: "chat.header.settings",
                        label: "Settings",
                        action: onShowSettings
                    )
                }
            }
        }
        .padding(.horizontal, LifeBoardTheme.Spacing.lg)
        .padding(.top, LifeBoardTheme.Spacing.sm)
        .padding(.bottom, LifeBoardTheme.Spacing.sm)
    }

    var newChatButton: some View {
        Button(action: onStartNewChat) {
            ViewThatFits(in: .horizontal) {
                Label("New chat", systemImage: "plus.message")
                    .font(.lifeboard(.buttonSmall))
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.lifeboard(.accentPrimary))
                    .lineLimit(1)
                    .padding(.horizontal, LifeBoardTheme.Spacing.md)
                    .frame(height: 44)
                    .lifeboardChromeSurface(
                        cornerRadius: 22,
                        accentColor: Color.lifeboard(.accentSecondary),
                        level: .e1
                    )

                Image(systemName: "plus.message")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.lifeboard(.accentPrimary))
                    .frame(width: 44, height: 44)
                    .lifeboardChromeSurface(
                        cornerRadius: 22,
                        accentColor: Color.lifeboard(.accentSecondary),
                        level: .e1
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("chat.header.new_chat")
        .accessibilityLabel("New chat")
        .accessibilityHint("Starts a fresh chat without deleting this one.")
        .lifeboardPressFeedback(reduceMotion: reduceMotion)
    }

    func iconButton(
        systemName: String,
        identifier: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.lifeboard(.textSecondary))
                .frame(width: 44, height: 44)
                .lifeboardChromeSurface(
                    cornerRadius: 22,
                    accentColor: Color.lifeboard(.accentSecondary),
                    level: .e1
                )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
        .accessibilityLabel(label)
        .lifeboardPressFeedback(reduceMotion: reduceMotion)
    }
}
