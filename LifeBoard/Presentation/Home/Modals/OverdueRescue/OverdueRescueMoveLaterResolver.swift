//
//  EvaOverdueRescueSheetV2.swift
//  LifeBoard
//
//  Screenshot-aligned Overdue Rescue decision deck.
//

import SwiftUI
import UIKit

enum OverdueRescueMoveLaterResolver {
    static func resolveMoveDate(
        for task: TaskDefinition,
        recommendation: EvaRescueRecommendation?,
        now: Date,
        calendar: Calendar = .current
    ) -> Date {
        let today = calendar.startOfDay(for: now)
        if let suggested = recommendation?.toDate {
            let suggestedDay = calendar.startOfDay(for: suggested)
            if suggestedDay > today {
                return suggestedDay
            }
        }

        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        let lowUrgency = task.priority == .none || task.priority == .low
        if isWorkingDay(tomorrow, calendar: calendar), lowUrgency || task.priority.isHighPriority == false {
            return tomorrow
        }

        return nextWorkingDay(after: today, calendar: calendar)
    }

    static func buttonTitle(
        for date: Date?,
        now: Date,
        calendar: Calendar = .current
    ) -> String {
        guard let date else { return "Move later" }
        if calendar.isDate(date, inSameDayAs: calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now) {
            return "Move tomorrow"
        }
        let today = calendar.startOfDay(for: now)
        let days = calendar.dateComponents([.day], from: today, to: calendar.startOfDay(for: date)).day ?? 0
        if days > 0, days <= 7 {
            let weekday = calendar.component(.weekday, from: date)
            return "Move to \(calendar.weekdaySymbols[max(0, weekday - 1)])"
        }
        return "Move later"
    }

    static func nextWorkingDay(after date: Date, calendar: Calendar) -> Date {
        var candidate = calendar.date(byAdding: .day, value: 1, to: date) ?? date
        while isWorkingDay(candidate, calendar: calendar) == false {
            candidate = calendar.date(byAdding: .day, value: 1, to: candidate) ?? candidate
        }
        return candidate
    }

    static func isWorkingDay(_ date: Date, calendar: Calendar) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        return weekday != 1 && weekday != 7
    }
}
