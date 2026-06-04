import SwiftUI
import UIKit

func lifeManagementHabitCadenceLabel(_ cadence: HabitCadenceDraft) -> String {
    switch cadence {
    case .daily:
        return "Daily"
    case .weekly(let days, _, _):
        return days.count == 1 ? "Weekly" : "\(days.count)x weekly"
    }
}
