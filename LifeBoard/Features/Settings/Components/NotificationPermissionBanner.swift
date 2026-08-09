import SwiftUI

struct NotificationPermissionBanner: View {
    let status: NotificationAuthorizationStatus
    var onAction: () -> Void

    var body: some View {
        HStack(spacing: SwiftUITokens.spacing.s12) {
            Image(systemName: iconName)
                .font(.lifeboard(.sectionTitle))
                .foregroundColor(iconColor)

            VStack(alignment: .leading, spacing: SwiftUITokens.spacing.s2) {
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
                    .padding(.horizontal, SwiftUITokens.spacing.s16)
                    .padding(.vertical, SwiftUITokens.spacing.s8)
                    .background(buttonBackground)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(SwiftUITokens.spacing.cardPadding)
        .background(bannerBackground)
        .clipShape(RoundedRectangle(cornerRadius: SwiftUITokens.corner.r3, style: .continuous))
        .lifeboardElevation(.e1, cornerRadius: SwiftUITokens.corner.r3, includesBorder: false)
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
