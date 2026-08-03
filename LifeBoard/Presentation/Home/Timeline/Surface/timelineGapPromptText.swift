import SwiftUI

@MainActor
func timelineGapPromptText(for gap: TimelineGap, row: TimelineRenderableRow) -> Text {
    let duration = gap.compactDurationText
    let promptSource = gap.supportingText.localizedCaseInsensitiveContains(duration)
        ? gap.supportingText
        : "\(gap.supportingText) \(duration)"
    guard let range = promptSource.range(of: duration) else {
        return Text(promptSource)
    }

    let prefix = String(promptSource[..<range.lowerBound])
    let suffix = String(promptSource[range.upperBound...])
    let emphasizedDuration = Text(duration)
        .foregroundStyle(row.temporalState == .activeGap ? Color.lifeboard.textPrimary : gapPromptTint(for: gap))
        .font(.lifeboard(.callout).weight(.semibold))
    return Text("\(Text(prefix))\(emphasizedDuration)\(Text(suffix))")
}
