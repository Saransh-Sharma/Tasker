import SwiftUI

struct LoadingSkeleton: View {
    var lineCount: Int = 3

    var body: some View {
        VStack(spacing: ClayLayoutMetrics.sm) {
            ForEach(0..<lineCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [ClayColorTokens.glassStrong.opacity(0.72), ClayColorTokens.glass.opacity(0.36), ClayColorTokens.glassStrong.opacity(0.72)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: index == 0 ? 78 : 66)
                    .overlay {
                        RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                            .stroke(ClayColorTokens.hairline.opacity(0.5), lineWidth: 1)
                    }
                    .redacted(reason: .placeholder)
            }
        }
        .accessibilityLabel("Loading Home")
    }
}
