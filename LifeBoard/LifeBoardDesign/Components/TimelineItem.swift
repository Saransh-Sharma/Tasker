import SwiftUI

struct TimelineItem<Content: View>: View {
    let timeText: String
    let role: ClayRole
    var tintHex: String?
    var temporalState: ClayTimelineTemporalState = .future
    var spineIconSystemName: String?
    var spineIconAccessibilityLabel: String?
    var spineIconAccessibilityValue: String?
    var spineIconAction: (() -> Void)?
    var spineIconIsCompleted: Bool?
    @ViewBuilder let content: Content

    init(
        timeText: String,
        role: ClayRole,
        tintHex: String? = nil,
        temporalState: ClayTimelineTemporalState = .future,
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
        HStack(alignment: .top, spacing: ClayLayoutMetrics.timelineCardGap) {
            Text(timeText)
                .font(ClayTypography.numeric)
                .foregroundStyle(timeColor)
                .lineLimit(2)
                .minimumScaleFactor(0.72)
                .multilineTextAlignment(.trailing)
                .frame(width: ClayLayoutMetrics.timelineTimeColumnWidth, alignment: .trailing)
                .padding(.top, ClayLayoutMetrics.sm)

            spine
                .frame(width: ClayLayoutMetrics.timelineRailWidth)

            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var spine: some View {
        TimelineSpine(
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
            return ClayColorTokens.textTertiary
        case .current:
            return ClayColorTokens.violetDeep
        case .future:
            return ClayColorTokens.navyMuted
        }
    }
}
