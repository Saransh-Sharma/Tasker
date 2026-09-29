import SwiftUI
import UIKit

func lifeManagementHabitStatusText(_ row: HabitLibraryRow) -> String {
    if row.isArchived { return String(localized: "Archived", defaultValue: "Archived") }
    if row.isPaused { return String(localized: "Paused") }
    if row.currentStreak > 0 {
        return row.currentStreak == 1
            ? String(localized: "1-day streak")
            : String(localized: "\(row.currentStreak)-day streak")
    }
    return lifeManagementHabitCadenceLabel(row.cadence)
}
