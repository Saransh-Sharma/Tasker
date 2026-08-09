import SwiftUI

struct CurrentTimeBubble: View {
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
        .foregroundStyle(ClayColorTokens.violetDeep)
        .padding(.horizontal, ClayLayoutMetrics.xxs)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity)
        .background(ClayColorTokens.violetSoft.opacity(0.82), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(ClayColorTokens.violet, lineWidth: 1)
        }
    }
}
