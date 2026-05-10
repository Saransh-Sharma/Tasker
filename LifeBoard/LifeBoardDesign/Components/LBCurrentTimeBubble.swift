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
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .allowsTightening(true)
            Text(model.label)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .allowsTightening(true)
        }
        .foregroundStyle(LBColorTokens.violetDeep)
        .padding(.horizontal, LBSpacingTokens.xxs)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity)
        .background(LBColorTokens.violetSoft.opacity(0.82), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(LBColorTokens.violet, lineWidth: 1)
        }
    }
}
