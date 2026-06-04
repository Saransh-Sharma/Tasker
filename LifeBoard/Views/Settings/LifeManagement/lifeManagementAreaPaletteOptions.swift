import SwiftUI
import UIKit

@MainActor
func lifeManagementAreaPaletteOptions() -> [LifeManagementAreaPaletteOption] {
    HabitColorFamily.allCases.map { family in
        LifeManagementAreaPaletteOption(
            id: family.rawValue,
            title: family.title,
            hex: family.canonicalHex
        )
    }
}
