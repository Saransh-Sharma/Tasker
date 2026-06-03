import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

@MainActor
enum OnboardingTheme {
    static let canvas = Color(uiColor: UIColor(lifeboardHex: "#05070D"))
    static let canvasSecondary = Color(uiColor: UIColor(lifeboardHex: "#080C14"))
    static let canvasElevated = Color(uiColor: UIColor(lifeboardHex: "#101722"))
    static let surface = Color(uiColor: UIColor(lifeboardHex: "#101722")).opacity(0.78)
    static let surfaceElevated = Color(uiColor: UIColor(lifeboardHex: "#151E2C")).opacity(0.88)
    static let surfaceMuted = Color(uiColor: UIColor(lifeboardHex: "#0D131D")).opacity(0.74)
    static let borderSoft = Color.white.opacity(0.16)
    static let border = Color.white.opacity(0.24)
    static let textPrimary = Color.white.opacity(0.96)
    static let textSecondary = Color.white.opacity(0.76)
    static let textTertiary = Color.white.opacity(0.58)
    static let accent = Color.lifeboard(.actionPrimary)
    static let accentPressed = Color.lifeboard(.actionPrimaryPressed)
    static let accentSecondary = Color.lifeboard(.accentSecondary)
    static let accentOnPrimary = Color.lifeboard(.accentOnPrimary)
    static let sunriseGold = Color(uiColor: UIColor(lifeboardHex: "#FFB300"))
    static let marigold = sunriseGold
    static let headerAccent = sunriseGold
    static let success = Color.lifeboard(.statusSuccess)
    static let danger = Color.lifeboard(.statusDanger)
}
