import SwiftUI

struct ChatStorageDegradedBanner: View {
    let reason: String

    var body: some View {
        Label {
            Text("Chat history is temporarily limited.")
                .font(.lifeboard(.caption1))
                .foregroundStyle(Color.lifeboard(.textPrimary))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        } icon: {
            Image(systemName: "externaldrive.badge.exclamationmark")
                .font(.lifeboard(.caption1))
                .foregroundStyle(Color.lifeboard(.statusWarning))
        }
        .padding(.horizontal, LifeBoardTheme.Spacing.sm)
        .padding(.vertical, LifeBoardTheme.Spacing.xs)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: LifeBoardTheme.CornerRadius.sm, style: .continuous)
                .fill(LBColorTokens.role(.warning).softSurface.opacity(0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: LifeBoardTheme.CornerRadius.sm, style: .continuous)
                .stroke(LBColorTokens.role(.warning).border.opacity(0.76), lineWidth: 1)
        )
        .accessibilityLabel("Chat history is temporarily limited")
        .accessibilityHint("Storage fallback reason: \(reason)")
    }
}
