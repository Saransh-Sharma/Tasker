import SwiftUI

/// Eva's conversation chrome on the warm paper system: cream canvases, cocoa
/// ink, and the sun accent. Violet survives only in the assistant-evidence
/// role colors, where it encodes the assistant domain.
enum EvaChatSunriseGlass {
    static let canvasTop = LBColorTokens.adaptive(light: "#FFF7D8", dark: "#151B2D")
    static let canvasMid = LBColorTokens.adaptive(light: "#FAF2DA", dark: "#111624")
    static let canvasBottom = LBColorTokens.adaptive(light: "#F5ECC9", dark: "#0E1220")
    static let assistantSurface = LBColorTokens.role(.assistant).softSurface
    static let assistantBorder = LBColorTokens.role(.assistant).border
    static let glassFill = LBColorTokens.glassStrong
    static let glassBorder = LBColorTokens.glassBorder
    static let primary = LBColorTokens.adaptive(light: "#2B2118", dark: "#F0CD87")
    static let primaryDeep = LBColorTokens.adaptive(light: "#4A3A2A", dark: "#E7BB7E")
    static let navy = LBColorTokens.adaptive(light: "#2B2118", dark: "#F4EBDD")
    static let navyMuted = LBColorTokens.adaptive(light: "#746757", dark: "#C6BBA8")
    static let gold = LBColorTokens.adaptive(light: "#F0CD87", dark: "#E7BB7E")

    static var background: LinearGradient {
        LinearGradient(
            colors: [
                canvasTop,
                canvasMid,
                canvasBottom.opacity(0.74)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
