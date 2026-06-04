import SwiftUI
import UIKit

func lifeManagementResolvedColor(hex: String?, fallback: Color) -> Color {
    guard let normalizedHex = lifeManagementResolvedHex(hex) else { return fallback }
    return Color(uiColor: UIColor(lifeboardHex: normalizedHex))
}
