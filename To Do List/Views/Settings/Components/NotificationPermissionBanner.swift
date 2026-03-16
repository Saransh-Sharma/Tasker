import SwiftUI

struct NotificationPermissionBanner: View {
    let status: TaskerNotificationAuthorizationStatus
    var onAction: () -> Void

    var body: some View {
        HStack(spacing: TaskerSwiftUITokens.spacing.s12) {
            Image(systemName: iconName)
                .font(.tasker(.sectionTitle))
                .foregroundColor(iconColor)

            VStack(alignment: .leading, spacing: TaskerSwiftUITokens.spacing.s2) {
                Text(titleText)
                    .font(.tasker(.bodyEmphasis))
                    .foregroundColor(.tasker(.textPrimary))

                Text(subtitleText)
                    .font(.tasker(.callout))
                    .foregroundColor(.tasker(.textSecondary))
            }

            Spacer()

            Button {
                onAction()
            } label: {
                Text(buttonText)
                    .font(.tasker(.buttonSmall))
                    .foregroundColor(.tasker(.accentOnPrimary))
                    .padding(.horizontal, TaskerSwiftUITokens.spacing.s16)
                    .padding(.vertical, TaskerSwiftUITokens.spacing.s8)
                    .background(buttonBackground)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(TaskerSwiftUITokens.spacing.cardPadding)
        .background(bannerBackground)
        .clipShape(RoundedRectangle(cornerRadius: TaskerSwiftUITokens.corner.r3, style: .continuous))
        .taskerElevation(.e1, cornerRadius: TaskerSwiftUITokens.corner.r3, includesBorder: false)
    }

    private var iconName: String {
        status == .denied ? "shield.slash.fill" : "bell.badge.fill"
    }

    private var iconColor: Color {
        status == .denied ? .tasker(.statusWarning) : .tasker(.stateInfo)
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
        status == .denied ? .tasker(.statusWarning) : .tasker(.actionPrimary)
    }

    private var bannerBackground: Color {
        status == .denied
            ? .tasker(.statusWarning).opacity(0.12)
            : .tasker(.accentWash)
    }
}
