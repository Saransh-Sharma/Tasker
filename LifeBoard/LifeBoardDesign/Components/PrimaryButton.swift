import SwiftUI

struct PrimaryButton: View {
    let title: String
    var systemImage: String?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: ClayLayoutMetrics.xs) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .font(ClayTypography.chip)
            .foregroundStyle(Color.lifeboard(.accentOnPrimary))
            .frame(minHeight: 48)
            .padding(.horizontal, ClayLayoutMetrics.lg)
            .background {
                LinearGradient(
                    colors: [ClayColorTokens.violetFill, ClayColorTokens.violetFillDeep],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(Capsule())
            }
        }
        .buttonStyle(.plain)
        .contentShape(Capsule())
    }
}
