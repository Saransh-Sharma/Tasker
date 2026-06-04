import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

enum OnboardingPromptTheme {
    static let canvasBase = Color(uiColor: UIColor(lifeboardHex: "#FFFDFC"))
    static let canvasWarm = Color(uiColor: UIColor(lifeboardHex: "#FFF8EF"))
    static let canvasCool = Color(uiColor: UIColor(lifeboardHex: "#F7FBFF"))
    static let surfaceGlass = Color.white.opacity(0.88)
    static let surfaceStrongGlass = Color.white.opacity(0.95)
    static let surfaceSolid = Color.white
    static let textPrimary = Color(uiColor: UIColor(lifeboardHex: "#071B52"))
    static let textSecondary = Color(uiColor: UIColor(lifeboardHex: "#48607F"))
    static let textTertiary = Color(uiColor: UIColor(lifeboardHex: "#7A8BA5"))
    static let accent = Color(uiColor: UIColor(lifeboardHex: "#6842FF"))
    static let accentPressed = Color(uiColor: UIColor(lifeboardHex: "#4F2CFF"))
    static let accentOnPrimary = Color.white
    static let sunriseGold = Color(uiColor: UIColor(lifeboardHex: "#FFB300"))
    static let assistantSoft = Color(uiColor: UIColor(lifeboardHex: "#F6F2FF"))
    static let taskSoft = Color(uiColor: UIColor(lifeboardHex: "#EFF9EC"))
    static let shadow = Color(uiColor: UIColor(lifeboardHex: "#071B52"))

    static func border(reduceTransparency: Bool) -> Color {
        reduceTransparency
            ? Color(uiColor: UIColor(lifeboardHex: "#DDE3EE"))
            : Color.white.opacity(0.82)
    }
}
