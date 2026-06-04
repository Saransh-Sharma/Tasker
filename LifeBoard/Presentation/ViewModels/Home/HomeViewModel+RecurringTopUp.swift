//
//  HomeViewModel.swift
//  LifeBoard
//
//  ViewModel for Home screen - manages task display, focus filters, and interactions
//

import Foundation
import Combine
#if canImport(UIKit)
import UIKit
#endif
#if canImport(WidgetKit)
import WidgetKit
#endif

extension HomeViewModel {
    func scheduleRecurringTopUpIfNeeded() {
        let now = Date()
        if let lastRecurringTopUpAt,
           now.timeIntervalSince(lastRecurringTopUpAt) < recurringTopUpThrottleSeconds {
            return
        }
        pendingRecurringTopUpTask?.cancel()
        pendingRecurringTopUpTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: Self.recurringTopUpDelay)
            } catch {
                return
            }
            guard Task.isCancelled == false, let self else { return }
            self.lastRecurringTopUpAt = Date()
            self.useCaseCoordinator.createTaskDefinition.maintainRecurringSeries(daysAhead: 45) { _ in }
            self.pendingRecurringTopUpTask = nil
        }
    }

    /// Toggle task completion.

}
