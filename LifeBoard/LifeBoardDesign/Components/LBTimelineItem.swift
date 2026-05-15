import SwiftUI

struct LBTimelineItem<Content: View>: View {
    let timeText: String
    let role: LBRole
    var tintHex: String?
    var temporalState: LBTimelineTemporalState = .future
    @ViewBuilder let content: Content

    var body: some View {
        HStack(alignment: .top, spacing: LBSpacingTokens.timelineCardGap) {
            Text(timeText)
                .font(LBTypographyTokens.numeric)
                .foregroundStyle(timeColor)
                .lineLimit(2)
                .minimumScaleFactor(0.72)
                .multilineTextAlignment(.trailing)
                .frame(width: LBSpacingTokens.timelineTimeColumnWidth, alignment: .trailing)
                .padding(.top, LBSpacingTokens.sm)

            LBTimelineSpine(role: role, tintHex: tintHex, temporalState: temporalState)
                .frame(width: LBSpacingTokens.timelineRailWidth)

            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var timeColor: Color {
        switch temporalState {
        case .past:
            return LBColorTokens.textTertiary
        case .current:
            return LBColorTokens.violetDeep
        case .future:
            return LBColorTokens.navyMuted
        }
    }
}
