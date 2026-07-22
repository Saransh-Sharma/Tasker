import SwiftUI

struct LBPrimaryButton: View {
    let title: String
    var systemImage: String?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: LBSpacingTokens.xs) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .font(LBTypographyTokens.chip)
            .foregroundStyle(Color.lifeboard(.accentOnPrimary))
            .frame(minHeight: 48)
            .padding(.horizontal, LBSpacingTokens.lg)
            .background {
                LinearGradient(
                    colors: [LBColorTokens.violetFill, LBColorTokens.violetFillDeep],
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
