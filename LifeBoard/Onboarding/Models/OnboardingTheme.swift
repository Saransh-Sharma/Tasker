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
    static let canvas = LBColorTokens.warmCanvas
    static let canvasSecondary = LBColorTokens.coolCanvas
    static let canvasElevated = LBColorTokens.canvas
    static let surface = LBColorTokens.glass
    static let surfaceElevated = LBColorTokens.glassStrong
    static let surfaceMuted = LBColorTokens.glass.opacity(0.72)
    static let borderSoft = LBColorTokens.hairline.opacity(0.62)
    static let border = LBColorTokens.hairline
    static let textPrimary = LBColorTokens.navy
    static let textSecondary = LBColorTokens.navyMuted
    static let textTertiary = LBColorTokens.textTertiary
    static let accent = Color.lifeboard(.actionPrimary)
    static let accentPressed = Color.lifeboard(.actionPrimaryPressed)
    static let accentSecondary = Color.lifeboard(.accentSecondary)
    static let accentOnPrimary = Color.lifeboard(.accentOnPrimary)
    static let sunriseGold = LBColorTokens.sunriseGold
    static let marigold = sunriseGold
    static let headerAccent = sunriseGold
    /// Deep gold for warm text/icon accents that must stay readable on the
    /// light canvas — bright `sunriseGold` is a fill color, not an ink.
    static let goldInk = LBColorTokens.role(.routine).deep
    static let success = Color.lifeboard(.statusSuccess)
    static let danger = Color.lifeboard(.statusDanger)

    /// Text and strokes rendered directly over the dark welcome video.
    static let onMediaTextPrimary = Color.white.opacity(0.96)
    static let onMediaTextSecondary = Color.white.opacity(0.76)
    static let onMediaBorder = Color.white.opacity(0.24)
}
