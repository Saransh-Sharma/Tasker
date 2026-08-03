//
//  EvaOverdueRescueSheetV2.swift
//  LifeBoard
//
//  Screenshot-aligned Overdue Rescue decision deck.
//

import SwiftUI
import UIKit

struct OverdueRescueSessionScope: Codable, Equatable, Hashable, Sendable {
    var accountScopeID: String
    var workspaceID: String?
    var rescueDay: Date
    var purpose: String? = nil

    var storageKey: String {
        let dayStamp = Int(Calendar.current.startOfDay(for: rescueDay).timeIntervalSince1970)
        let purposeSuffix = purpose.map { ".\($0)" } ?? ""
        return "overdueRescue.session.v1.\(accountScopeID).\(workspaceID ?? "default").\(dayStamp)\(purposeSuffix)"
    }
}

struct OverdueRescueLaunchContext: Equatable, Sendable {
    enum Origin: String, Codable, Sendable {
        case home
        case plan
        /// Adapted Day-Rescue variant entered from the universal input composer:
        /// reuses the same decision-deck chrome and card physics as Overdue
        /// Rescue, but pulls in today's "needs replan" candidates rather than
        /// the overdue pool. The empty-at-launch deck surfaces a different
        /// empty-state copy ("Nothing needs rescuing today") and writes a
        /// distinct `purpose` so a day-rescue run never collides with an
        /// overdue-rescue run's persisted session memory.
        case universalInputDayRescue
    }

    let origin: Origin
    let source: String
    let referenceDate: Date
    let targetPlanningDay: PlanningDay?
    let planningMetadataByTaskID: [UUID: PlanningTaskMetadata]
    let synchronizesKeptTasksWithPlan: Bool

    static func home(referenceDate: Date) -> OverdueRescueLaunchContext {
        OverdueRescueLaunchContext(
            origin: .home,
            source: "home",
            referenceDate: referenceDate,
            targetPlanningDay: nil,
            planningMetadataByTaskID: [:],
            synchronizesKeptTasksWithPlan: false
        )
    }

    static func plan(
        selectedDay: PlanningDay,
        planningMetadataByTaskID: [UUID: PlanningTaskMetadata],
        referenceDate: Date = Date()
    ) -> OverdueRescueLaunchContext {
        OverdueRescueLaunchContext(
            origin: .plan,
            source: "plan_day_open_card",
            referenceDate: referenceDate,
            targetPlanningDay: selectedDay,
            planningMetadataByTaskID: planningMetadataByTaskID,
            synchronizesKeptTasksWithPlan: true
        )
    }

    /// A modified-overdue-rescue deck scoped to today's "needs replan"
    /// candidates rather than the overdue pool. The deck reuses the existing
    /// card machinery and chrome; only the candidate source and the
    /// empty-at-launch copy differ.
    static func universalInputDayRescue(referenceDate: Date) -> OverdueRescueLaunchContext {
        OverdueRescueLaunchContext(
            origin: .universalInputDayRescue,
            source: "universal_input.day_rescue",
            referenceDate: referenceDate,
            targetPlanningDay: nil,
            planningMetadataByTaskID: [:],
            synchronizesKeptTasksWithPlan: false
        )
    }

    func decisionCalendar(base calendar: Calendar = .current) -> Calendar {
        guard let identifier = targetPlanningDay?.timeZoneIdentifier,
              let timeZone = TimeZone(identifier: identifier) else {
            return calendar
        }
        var resolved = calendar
        resolved.timeZone = timeZone
        return resolved
    }

    func targetDate(calendar: Calendar = .current) -> Date {
        let calendar = decisionCalendar(base: calendar)
        if let targetPlanningDay,
           let target = targetPlanningDay.startDate(calendar: calendar) {
            return target
        }
        return calendar.startOfDay(for: referenceDate)
    }

    func keepActionTitle(calendar: Calendar = .current) -> String {
        let calendar = decisionCalendar(base: calendar)
        let target = targetDate(calendar: calendar)
        let today = calendar.startOfDay(for: referenceDate)
        if calendar.isDate(target, inSameDayAs: today) {
            return "Keep today"
        }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: today),
           calendar.isDate(target, inSameDayAs: tomorrow) {
            return "Keep tomorrow"
        }
        return "Keep on \(target.formatted(.dateTime.weekday(.wide)))"
    }

    func keepSuccessMessage(calendar: Calendar = .current) -> String {
        let title = keepActionTitle(calendar: calendar)
        guard title.hasPrefix("Keep") else { return title }
        return "Kept\(title.dropFirst("Keep".count))"
    }

    func sessionScope(
        accountScopeID: String = "default",
        workspaceID: String? = nil,
        calendar: Calendar = .current
    ) -> OverdueRescueSessionScope {
        let calendar = decisionCalendar(base: calendar)
        let purpose: String?
        switch origin {
        case .plan:
            let target = targetDate(calendar: calendar)
            purpose = "plan-\(Int(target.timeIntervalSince1970))"
        case .universalInputDayRescue:
            purpose = "universalInput.dayRescue"
        case .home:
            purpose = nil
        }
        return OverdueRescueSessionScope(
            accountScopeID: accountScopeID,
            workspaceID: workspaceID,
            rescueDay: referenceDate,
            purpose: purpose
        )
    }
}
