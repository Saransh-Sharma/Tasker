import SwiftUI
import UIKit

func lifeManagementAreaAccentHex(_ area: LifeArea?) -> String {
    guard let area else { return HabitColorFamily.green.canonicalHex }
    return LifeAreaColorPalette.normalizeOrMap(hex: area.color, for: area.id)
}
