import SwiftUI

extension HabitDetailScreen {
    var weeklyDaysBinding: Binding<[Int]> {
        Binding(
            get: {
                let days = weeklyDays(from: viewModel.draft.cadence)
                return days.isEmpty ? [2, 3, 4, 5, 6] : days
            },
            set: { days in
                let time = cadenceTime(from: viewModel.draft.cadence)
                viewModel.draft.cadence = .weekly(daysOfWeek: days.sorted().isEmpty ? [2, 3, 4, 5, 6] : days.sorted(), hour: time.hour, minute: time.minute)
            }
        )
    }

    var cadenceTimeBinding: Binding<Date> {
        Binding(
            get: {
                let calendar = Calendar.current
                let time = cadenceTime(from: viewModel.draft.cadence)
                return calendar.date(bySettingHour: time.hour ?? 9, minute: time.minute ?? 0, second: 0, of: calendar.startOfDay(for: Date())) ?? Date()
            },
            set: { date in
                let calendar = Calendar.current
                let hour = calendar.component(.hour, from: date)
                let minute = calendar.component(.minute, from: date)
                switch viewModel.draft.cadence {
                case .daily:
                    viewModel.draft.cadence = .daily(hour: hour, minute: minute)
                case .weekly(let days, _, _):
                    viewModel.draft.cadence = .weekly(daysOfWeek: days, hour: hour, minute: minute)
                case .interval(let days, _, _):
                    viewModel.draft.cadence = .interval(days: days, hour: hour, minute: minute)
                }
            }
        )
    }

    func cadenceTime(from cadence: HabitCadenceDraft) -> (hour: Int?, minute: Int?) {
        switch cadence {
        case .daily(let hour, let minute): return (hour, minute)
        case .weekly(_, let hour, let minute): return (hour, minute)
        case .interval(_, let hour, let minute): return (hour, minute)
        }
    }

    func weeklyDays(from cadence: HabitCadenceDraft) -> [Int] {
        switch cadence {
        case .daily: return []
        case .weekly(let days, _, _): return days
        case .interval: return []
        }
    }

    var intervalDaysBinding: Binding<Int> {
        Binding(
            get: { intervalDays(from: viewModel.draft.cadence) },
            set: { days in
                let time = cadenceTime(from: viewModel.draft.cadence)
                viewModel.draft.cadence = .interval(days: max(2, days), hour: time.hour, minute: time.minute)
            }
        )
    }

    func intervalDays(from cadence: HabitCadenceDraft) -> Int {
        if case let .interval(days, _, _) = cadence { return max(2, days) }
        return 2
    }
}
