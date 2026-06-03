import SwiftUI

struct TimelineRailLabel: View {
    let text: String
    let kind: TimelineRailLabelKind
    let isEmphasized: Bool
    let color: Color
    let metrics: TimelineRailMetrics
    var leadingX: CGFloat? = nil

    var body: some View {
        Text(text)
            .font(font)
            .monospacedDigit()
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .multilineTextAlignment(.trailing)
            .frame(width: metrics.labelWidth, alignment: .trailing)
            .offset(x: leadingX ?? metrics.labelLeadingX)
    }

    var font: Font {
        TimelineRailTypography.font(for: kind, isEmphasized: isEmphasized)
    }
}
