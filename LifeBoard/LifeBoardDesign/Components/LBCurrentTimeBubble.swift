import SwiftUI

struct LBCurrentTimeBubble: View {
    struct Model: Equatable {
        let timeText: String
        let label: String
    }

    let model: Model

    var body: some View {
        VStack(spacing: 2) {
            Text(model.timeText)
                .font(LBTypographyTokens.numeric)
            Text(model.label)
                .font(LBTypographyTokens.meta)
        }
        .foregroundStyle(LBColorTokens.violetDeep)
        .padding(.horizontal, LBSpacingTokens.xs)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(LBColorTokens.violetSoft.opacity(0.82), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(LBColorTokens.violet, lineWidth: 1)
        }
    }
}
