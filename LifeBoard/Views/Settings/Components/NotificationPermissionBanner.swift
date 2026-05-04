import SwiftUI

struct NotificationPermissionBanner: View {
    let status: LifeBoardNotificationAuthorizationStatus
    var onAction: () -> Void

    var body: some View {
        HStack(spacing: LifeBoardSwiftUITokens.spacing.s12) {
            Image(systemName: iconName)
                .font(.lifeboard(.sectionTitle))
                .foregroundColor(iconColor)

            VStack(alignment: .leading, spacing: LifeBoardSwiftUITokens.spacing.s2) {
                Text(titleText)
                    .font(.lifeboard(.bodyEmphasis))
                    .foregroundColor(.lifeboard(.textPrimary))

                Text(subtitleText)
                    .font(.lifeboard(.callout))
                    .foregroundColor(.lifeboard(.textSecondary))
            }

            Spacer()

            Button {
                onAction()
            } label: {
                Text(buttonText)
                    .font(.lifeboard(.buttonSmall))
                    .foregroundColor(.lifeboard(.accentOnPrimary))
                    .padding(.horizontal, LifeBoardSwiftUITokens.spacing.s16)
                    .padding(.vertical, LifeBoardSwiftUITokens.spacing.s8)
                    .background(buttonBackground)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(LifeBoardSwiftUITokens.spacing.cardPadding)
        .background(bannerBackground)
        .clipShape(RoundedRectangle(cornerRadius: LifeBoardSwiftUITokens.corner.r3, style: .continuous))
        .lifeboardElevation(.e1, cornerRadius: LifeBoardSwiftUITokens.corner.r3, includesBorder: false)
    }

    private var iconName: String {
        status == .denied ? "shield.slash.fill" : "bell.badge.fill"
    }

    private var iconColor: Color {
        status == .denied ? .lifeboard(.statusWarning) : .lifeboard(.stateInfo)
    }

    private var titleText: String {
        status == .denied ? "Notifications Disabled" : "Enable Notifications"
    }

    private var subtitleText: String {
        status == .denied ? "Open Settings to re-enable" : "Stay on top of your tasks"
    }

    private var buttonText: String {
        status == .denied ? "Open Settings" : "Enable"
    }

    private var buttonBackground: Color {
        status == .denied ? .lifeboard(.statusWarning) : .lifeboard(.actionPrimary)
    }

    private var bannerBackground: Color {
        status == .denied
            ? .lifeboard(.statusWarning).opacity(0.12)
            : .lifeboard(.accentWash)
    }
}
