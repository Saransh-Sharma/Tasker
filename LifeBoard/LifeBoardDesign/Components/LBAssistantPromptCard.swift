import SwiftUI

struct LBAssistantPromptCard: View {
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            LBGlassCard(
                cornerRadius: 20,
                borderColor: LBColorTokens.violetSoft.opacity(0.88),
                fill: Color.white.opacity(0.76),
                shadow: nil,
                usesMaterialBackground: false
            ) {
                HStack(spacing: LBSpacingTokens.md) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(LBColorTokens.violet)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(LBTypographyTokens.bodyStrong)
                            .foregroundStyle(LBColorTokens.navy)
                        Text(subtitle)
                            .font(LBTypographyTokens.meta)
                            .foregroundStyle(LBColorTokens.navyMuted)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(LBColorTokens.textTertiary)
                }
                .padding(.horizontal, LBSpacingTokens.md)
                .padding(.vertical, LBSpacingTokens.sm)
            }
        }
        .buttonStyle(.plain)
    }
}
