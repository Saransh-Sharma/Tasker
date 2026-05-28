import SwiftUI

struct LBLoadingSkeleton: View {
    var lineCount: Int = 3

    var body: some View {
        VStack(spacing: LBSpacingTokens.sm) {
            ForEach(0..<lineCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: LBRadiusTokens.card, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [LBColorTokens.glassStrong.opacity(0.72), LBColorTokens.glass.opacity(0.36), LBColorTokens.glassStrong.opacity(0.72)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: index == 0 ? 78 : 66)
                    .overlay {
                        RoundedRectangle(cornerRadius: LBRadiusTokens.card, style: .continuous)
                            .stroke(LBColorTokens.hairline.opacity(0.5), lineWidth: 1)
                    }
                    .redacted(reason: .placeholder)
            }
        }
        .accessibilityLabel("Loading Home")
    }
}
