import SwiftUI
import UIKit

func lifeManagementHabitStatusText(_ row: HabitLibraryRow) -> String {
    if row.isArchived { return String(localized: "Archived", defaultValue: "Archived") }
    if row.isPaused { return "Paused" }
    if row.currentStreak > 0 { return "\(row.currentStreak)d active" }
    return lifeManagementHabitCadenceLabel(row.cadence)
}
