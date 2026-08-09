import SwiftUI

struct AssistantPromptCard: View {
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        let style = ClayColorTokens.role(.assistant)
        Button(action: action) {
            GlassCard(
                cornerRadius: 20,
                borderColor: style.border.opacity(0.82),
                fill: style.softSurface.opacity(0.52),
                shadow: nil,
                usesMaterialBackground: false
            ) {
                HStack(spacing: ClayLayoutMetrics.md) {
                    Image(systemName: style.symbolName)
                        .font(ClayTypography.bodyStrong)
                        .foregroundStyle(style.deep)
                        .frame(width: 34, height: 34)
                        .background(style.softSurface.opacity(0.82), in: Circle())
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(ClayTypography.bodyStrong)
                            .foregroundStyle(ClayColorTokens.navy)
                        Text(subtitle)
                            .font(ClayTypography.meta)
                            .foregroundStyle(ClayColorTokens.navyMuted)
                    }
                    Spacer()
                    Text("Add")
                        .font(ClayTypography.meta)
                        .foregroundStyle(style.deep)
                        .padding(.horizontal, ClayLayoutMetrics.sm)
                        .padding(.vertical, ClayLayoutMetrics.xs)
                        .background(ClayColorTokens.glassStrong.opacity(0.62), in: Capsule())
                        .overlay {
                            Capsule()
                                .stroke(style.border.opacity(0.62), lineWidth: 1)
                        }
                }
                .padding(.horizontal, ClayLayoutMetrics.md)
                .padding(.vertical, ClayLayoutMetrics.sm)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Assistant prompt, \(title), \(subtitle)")
    }
}
