import SwiftUI

enum EvaChatSunriseGlass {
    static let canvasTop = LBColorTokens.adaptive(light: "#FFF8EF", dark: "#10101A")
    static let canvasMid = LBColorTokens.adaptive(light: "#FFFDFC", dark: "#080C17")
    static let canvasBottom = LBColorTokens.adaptive(light: "#F7FBFF", dark: "#07111E")
    static let assistantSurface = LBColorTokens.role(.assistant).softSurface
    static let assistantBorder = LBColorTokens.role(.assistant).border
    static let glassFill = LBColorTokens.glassStrong
    static let glassBorder = LBColorTokens.glassBorder
    static let primary = LBColorTokens.violet
    static let primaryDeep = LBColorTokens.violetDeep
    static let navy = LBColorTokens.navy
    static let navyMuted = LBColorTokens.navyMuted
    static let gold = LBColorTokens.sunriseGold

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
