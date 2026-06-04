import SwiftUI

@MainActor
func timelineStemColor(for state: TimelineStemSegmentState, fallbackPalette: TimelinePalette) -> Color {
    switch state {
    case .pastCompletedSegment(let tintHex):
        return TimelinePalette.resolve(from: tintHex).progress
    case .pastIncompleteSegment(let tintHex):
        return TimelinePalette.resolve(from: tintHex).progress.opacity(0.46)
    case .currentElapsedSegment(let tintHex, _):
        return TimelinePalette.resolve(from: tintHex).progress
    case .currentRemainingSegment, .futureSegment, .gapFutureSegment:
        return TimelineVisualTokens.neutralStem
    case .gapPastSegment:
        return TimelineVisualTokens.gapPastStem
    }
}
