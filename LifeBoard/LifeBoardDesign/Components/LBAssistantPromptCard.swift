import SwiftUI

struct LBAssistantPromptCard: View {
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        let style = LBColorTokens.role(.assistant)
        Button(action: action) {
            LBGlassCard(
                cornerRadius: 20,
                borderColor: style.border.opacity(0.82),
                fill: style.softSurface.opacity(0.52),
                shadow: nil,
                usesMaterialBackground: false
            ) {
                HStack(spacing: LBSpacingTokens.md) {
                    Image(systemName: style.symbolName)
                        .font(LBTypographyTokens.bodyStrong)
                        .foregroundStyle(style.deep)
                        .frame(width: 34, height: 34)
                        .background(style.softSurface.opacity(0.82), in: Circle())
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(LBTypographyTokens.bodyStrong)
                            .foregroundStyle(LBColorTokens.navy)
                        Text(subtitle)
                            .font(LBTypographyTokens.meta)
                            .foregroundStyle(LBColorTokens.navyMuted)
                    }
                    Spacer()
                    Text("Add")
                        .font(LBTypographyTokens.meta)
                        .foregroundStyle(style.deep)
                        .padding(.horizontal, LBSpacingTokens.sm)
                        .padding(.vertical, LBSpacingTokens.xs)
                        .background(LBColorTokens.glassStrong.opacity(0.62), in: Capsule())
                        .overlay {
                            Capsule()
                                .stroke(style.border.opacity(0.62), lineWidth: 1)
                        }
                }
                .padding(.horizontal, LBSpacingTokens.md)
                .padding(.vertical, LBSpacingTokens.sm)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Assistant prompt, \(title), \(subtitle)")
    }
}
