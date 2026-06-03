//
//  SunriseAppShellView.swift
//  LifeBoard
//
//  New SwiftUI Home shell with backdrop/sunrise pattern.
//

import SwiftUI
import UIKit
import Combine

enum HomePerformanceSignposts {
    static let habitMutationIntervalName: StaticString = "HomeHabitMutationLatency"
    static let lastCellTapIntervalName: StaticString = "HomeHabitLastCellTap"
    static let habitsSectionRenderEventName: StaticString = "home.habitsSection.render"

    // Points-of-interest signposts emit automatically while profiling with
    // Instruments. The verbose performance log still honors the explicit
    // LifeBoard performance flags.

    static func lastCellTapAccepted() {
        LifeBoardPerformanceTrace.event("home.lastCellTap.accepted")
    }

    static func beginLastCellTap() -> LifeBoardPerformanceInterval {
        LifeBoardPerformanceTrace.event("home.lastCellTap.begin")
        return LifeBoardPerformanceTrace.begin(lastCellTapIntervalName)
    }

    static func endLastCellTap(_ interval: LifeBoardPerformanceInterval?) {
        guard let interval else { return }
        LifeBoardPerformanceTrace.end(interval)
        LifeBoardPerformanceTrace.event("home.lastCellTap.end")
    }

    static func beginHabitMutation() -> LifeBoardPerformanceInterval {
        LifeBoardPerformanceTrace.event("home.habitMutation.begin")
        return LifeBoardPerformanceTrace.begin(habitMutationIntervalName)
    }

    static func endHabitMutation(_ interval: LifeBoardPerformanceInterval?) {
        guard let interval else { return }
        LifeBoardPerformanceTrace.end(interval)
        LifeBoardPerformanceTrace.event("home.habitMutation.end")
    }

    static func openDetailTap() {
        LifeBoardPerformanceTrace.event("home.openDetail.tap")
    }

    static func habitsSectionRendered(rowCount: Int) {
        LifeBoardPerformanceTrace.event(habitsSectionRenderEventName, value: rowCount)
    }
}
