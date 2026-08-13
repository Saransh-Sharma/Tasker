import SwiftUI
import UIKit

@MainActor
func lifeManagementAreaPaletteMatch(for hex: String) -> LifeManagementAreaPaletteOption? {
    let normalizedHex = lifeManagementNormalizedHex(hex)
    return lifeManagementAreaPaletteOptions().first { option in
        lifeManagementNormalizedHex(option.hex) == normalizedHex
    }
}
