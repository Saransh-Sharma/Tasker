import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

/// Onboarding rides the Sunrise Glass token layer: warm light canvases,
/// navy ink, and white glass panels. The previous dark cinematic values
/// survive only as `onMedia*` constants for text over the welcome video.
@MainActor
enum OnboardingTheme {
    static let canvas = ClayColorTokens.warmCanvas
    static let canvasSecondary = ClayColorTokens.coolCanvas
    static let canvasElevated = ClayColorTokens.canvas
    static let surface = ClayColorTokens.glass
    static let surfaceElevated = ClayColorTokens.glassStrong
    static let surfaceMuted = ClayColorTokens.glass.opacity(0.72)
    static let borderSoft = ClayColorTokens.hairline.opacity(0.62)
    static let border = ClayColorTokens.hairline
    static let textPrimary = ClayColorTokens.navy
    static let textSecondary = ClayColorTokens.navyMuted
    static let textTertiary = ClayColorTokens.textTertiary
    static let accent = Color.lifeboard(.actionPrimary)
    static let accentPressed = Color.lifeboard(.actionPrimaryPressed)
    static let accentSecondary = Color.lifeboard(.accentSecondary)
    static let accentOnPrimary = Color.lifeboard(.accentOnPrimary)
    static let sunriseGold = ClayColorTokens.sunriseGold
    static let marigold = sunriseGold
    static let headerAccent = sunriseGold
    /// Deep gold for warm text/icon accents that must stay readable on the
    /// light canvas — bright `sunriseGold` is a fill color, not an ink.
    static let goldInk = ClayColorTokens.role(.routine).deep
    static let success = Color.lifeboard(.statusSuccess)
    static let danger = Color.lifeboard(.statusDanger)

    /// Text and strokes rendered directly over the dark welcome video.
    // Fixed-white roles for text that sat over the old dark hero video. The
    // video is gone and the welcome card is now a clay surface on a cream
    // canvas, so these are decorative-only: they must never carry text again.
    static let onMediaBorder = Color.white.opacity(0.24)
    static let decorativeHighlight = Color(SemanticColorTokens.clayHighlight)
    static let mediaScrim = Color.black
}
