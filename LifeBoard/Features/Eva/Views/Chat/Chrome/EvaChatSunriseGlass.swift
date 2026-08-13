import SwiftUI

/// Eva's conversation chrome on the warm paper system: cream canvases, cocoa
/// ink, and the sun accent. Violet survives only in the assistant-evidence
/// role colors, where it encodes the assistant domain.
enum EvaChatSunriseGlass {
    static let canvasTop = ClayColorTokens.adaptive(light: "#FFF7D8", dark: "#151B2D")
    static let canvasMid = ClayColorTokens.adaptive(light: "#FAF2DA", dark: "#111624")
    static let canvasBottom = ClayColorTokens.adaptive(light: "#F5ECC9", dark: "#0E1220")
    static let assistantSurface = ClayColorTokens.role(.assistant).softSurface
    static let assistantBorder = ClayColorTokens.role(.assistant).border
    static let glassFill = ClayColorTokens.glassStrong
    static let glassBorder = ClayColorTokens.glassBorder
    static let primary = ClayColorTokens.adaptive(light: "#2B2118", dark: "#F0CD87")
    static let primaryDeep = ClayColorTokens.adaptive(light: "#4A3A2A", dark: "#E7BB7E")
    static let navy = ClayColorTokens.adaptive(light: "#2B2118", dark: "#F4EBDD")
    static let navyMuted = ClayColorTokens.adaptive(light: "#746757", dark: "#C6BBA8")
    static let gold = ClayColorTokens.adaptive(light: "#F0CD87", dark: "#E7BB7E")

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
