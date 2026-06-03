import SwiftUI

enum TimelineVisualTokens {
    @MainActor
    static var neutralStem: Color { Color.lifeboard.strokeHairline.opacity(0.42) }

    @MainActor
    static var gapPastStem: Color { Color.lifeboard.accentPrimary.opacity(0.18) }

    @MainActor
    static var futureCapsule: Color { Color.lifeboard.surfacePrimary.opacity(0.9) }

    @MainActor
    static var futureCapsuleStroke: Color { Color.lifeboard.strokeHairline.opacity(0.58) }

    @MainActor
    static var anchorCapsuleFill: Color { Color.lifeboard.surfacePrimary.opacity(0.94) }

    @MainActor
    static var metaText: Color { Color.lifeboard.textSecondary }

    @MainActor
    static var utilityText: Color { Color.lifeboard.textTertiary }
}
