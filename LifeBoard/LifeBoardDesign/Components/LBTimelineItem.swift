import SwiftUI

struct LBTimelineItem<Content: View>: View {
    let timeText: String
    let role: LBRole
    var tintHex: String?
    var temporalState: LBTimelineTemporalState = .future
    var spineIconSystemName: String?
    var spineIconAccessibilityLabel: String?
    var spineIconAccessibilityValue: String?
    var spineIconAction: (() -> Void)?
    var spineIconIsCompleted: Bool?
    @ViewBuilder let content: Content

    init(
        timeText: String,
        role: LBRole,
        tintHex: String? = nil,
        temporalState: LBTimelineTemporalState = .future,
        spineIconSystemName: String? = nil,
        spineIconAccessibilityLabel: String? = nil,
        spineIconAccessibilityValue: String? = nil,
        spineIconAction: (() -> Void)? = nil,
        spineIconIsCompleted: Bool? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.timeText = timeText
        self.role = role
        self.tintHex = tintHex
        self.temporalState = temporalState
        self.spineIconSystemName = spineIconSystemName
        self.spineIconAccessibilityLabel = spineIconAccessibilityLabel
        self.spineIconAccessibilityValue = spineIconAccessibilityValue
        self.spineIconAction = spineIconAction
        self.spineIconIsCompleted = spineIconIsCompleted
        self.content = content()
    }

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

            spine
                .frame(width: LBSpacingTokens.timelineRailWidth)

            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var spine: some View {
        LBTimelineSpine(
            role: role,
            tintHex: tintHex,
            temporalState: temporalState,
            iconSystemName: spineIconSystemName,
            iconAccessibilityLabel: spineIconAccessibilityLabel,
            iconAccessibilityValue: spineIconAccessibilityValue,
            iconAction: spineIconAction,
            iconIsCompleted: spineIconIsCompleted
        )
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
