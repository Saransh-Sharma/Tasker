import SwiftUI

/// Shared tactile palette for Eva's compact sheets. The name deliberately
/// describes its surviving owner after the legacy Reflect & Plan flow retired.
enum EvaClayStyle {
    static let canvas = Color.lifeboard(.bgCanvas)
    static let cream = Color.lifeboard(.surfacePrimary)
    static let peachSurface = Color.lifeboard(.accentSecondaryWash)
    static let peachSurfaceStrong = Color.lifeboard(.surfaceSecondary)
    static let peachBorder = Color.lifeboard(.strokeHairline)
    static let blueSurface = Color.lifeboard(.accentWash)
    static let blueSurfaceStrong = Color.lifeboard(.surfaceTertiary)
    static let blueBorder = Color.lifeboard(.strokeHairline)
    static let greenCTA = Color.lifeboard(.actionPrimary)
    static let greenCTAPressed = Color.lifeboard(.actionPrimaryPressed)
    static let disabledCTA = Color.lifeboard(.textDisabled)
    static let goldSurface = Color.lifeboard(.accentSecondaryWash)
    static let goldBorder = Color.lifeboard(.statusWarning)
    static let selectedChip = Color.lifeboard(.chipSelectedBackground)
    static let selectedChipBorder = Color.lifeboard(.strokeHairline)
    static let shadow = Color.lifeboard(.overlayScrim).opacity(0.10)
}
