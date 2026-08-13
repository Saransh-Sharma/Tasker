import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

enum OnboardingPastelPalette {
    static let colors: [Color] = [
        Color(uiColor: UIColor(lifeboardHex: HabitColorFamily.green.canonicalHex)).opacity(0.24),
        Color(uiColor: UIColor(lifeboardHex: HabitColorFamily.teal.canonicalHex)).opacity(0.24),
        Color(uiColor: UIColor(lifeboardHex: HabitColorFamily.blue.canonicalHex)).opacity(0.24),
        Color(uiColor: UIColor(lifeboardHex: HabitColorFamily.purple.canonicalHex)).opacity(0.24),
        Color(uiColor: UIColor(lifeboardHex: HabitColorFamily.orange.canonicalHex)).opacity(0.24),
        Color(uiColor: UIColor(lifeboardHex: HabitColorFamily.coral.canonicalHex)).opacity(0.24)
    ]

    static func color(for key: String) -> Color {
        let sum = key.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return colors[sum % colors.count]
    }
}
