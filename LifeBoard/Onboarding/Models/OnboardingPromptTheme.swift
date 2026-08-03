import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

enum OnboardingPromptTheme {
    static let canvasBase = Color.lifeboard(.bgCanvas)
    static let canvasWarm = Color.lifeboard(.bgCanvasSecondary)
    static let canvasCool = Color.lifeboard(.bgElevated)
    static let surfaceGlass = Color.lifeboard(.surfacePrimary)
    static let surfaceStrongGlass = Color.lifeboard(.bgElevated)
    static let surfaceSolid = Color.lifeboard(.bgElevated)
    static let textPrimary = Color.lifeboard(.textPrimary)
    static let textSecondary = Color.lifeboard(.textSecondary)
    static let textTertiary = Color.lifeboard(.textTertiary)
    static let accent = Color.lifeboard(.accentPrimary)
    static let accentPressed = Color.lifeboard(.accentPrimaryPressed)
    static let accentOnPrimary = Color.lifeboard(.accentOnPrimary)
    static let sunriseGold = Color.lifeboard(.accentSecondary)
    static let assistantSoft = Color.lifeboard(.accentWash)
    static let taskSoft = Color.lifeboard(.accentSecondaryWash)
    static let shadow = Color.lifeboard(.overlayScrim)

    static func border(reduceTransparency: Bool) -> Color {
        reduceTransparency ? Color.lifeboard(.borderStrong) : Color.lifeboard(.borderDefault)
    }
}
