import SwiftUI

struct ChatStorageDegradedBanner: View {
    let reason: String

    var body: some View {
        Label {
            Text("New messages may not save. Restart LifeBoard.")
                .font(.lifeboard(.caption1))
                .foregroundStyle(Color.lifeboard(.textPrimary))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        } icon: {
            Image(systemName: "externaldrive.badge.exclamationmark")
                .font(.lifeboard(.caption1))
                .foregroundStyle(Color.lifeboard(.statusWarning))
        }
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, Theme.Spacing.xs)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.sm, style: .continuous)
                .fill(ClayColorTokens.role(.warning).softSurface.opacity(0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.sm, style: .continuous)
                .stroke(ClayColorTokens.role(.warning).border.opacity(0.76), lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("New messages may not save. Restart LifeBoard.")
    }
}
