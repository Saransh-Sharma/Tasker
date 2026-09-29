import SwiftUI
import UIKit

func lifeManagementHabitCadenceLabel(_ cadence: HabitCadenceDraft) -> String {
    switch cadence {
    case .daily:
        return String(localized: "Daily")
    case .weekly(let days, _, _):
        return days.count == 1 ? String(localized: "Weekly") : String(localized: "\(days.count) days a week")
    case .interval(let days, _, _):
        return String(localized: "Every \(max(1, days)) days")
    }
}
