import SwiftUI

enum ReflectPlanStyle {
    static let canvas = LBColorTokens.warmCanvas
    static let cream = LBColorTokens.glassStrong
    static let peachSurface = LBColorTokens.role(.personal).softSurface
    static let peachSurfaceStrong = LBColorTokens.adaptive(light: "#FFF7F1", dark: "#211A18", darkHighContrast: "#2B201D")
    static let peachBorder = LBColorTokens.role(.personal).border
    static let blueSurface = LBColorTokens.role(.focus).softSurface
    static let blueSurfaceStrong = LBColorTokens.adaptive(light: "#F5FBFF", dark: "#101F31", darkHighContrast: "#142A42")
    static let blueBorder = LBColorTokens.role(.focus).border
    static let greenCTA = LBColorTokens.adaptive(light: "#0F5B3D", dark: "#1F7A55", darkHighContrast: "#269866")
    static let greenCTAPressed = LBColorTokens.adaptive(light: "#0A442D", dark: "#17613F", darkHighContrast: "#1F8054")
    static let disabledCTA = LBColorTokens.adaptive(light: "#48607F", dark: "#56617B", darkHighContrast: "#66728E")
    static let goldSurface = LBColorTokens.role(.warning).softSurface
    static let goldBorder = LBColorTokens.role(.warning).border
    static let selectedChip = LBColorTokens.role(.task).softSurface
    static let selectedChipBorder = LBColorTokens.role(.task).border
    static let shadow = LBColorTokens.elevationShadow.opacity(0.10)
}
