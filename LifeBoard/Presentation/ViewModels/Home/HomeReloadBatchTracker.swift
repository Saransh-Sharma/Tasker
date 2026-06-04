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

@MainActor
final class HomeReloadBatchTracker {
    let onComplete: () -> Void
    var pendingOperations: Int = 0
    var finishedScheduling = false
    var completed = false

    init(onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
    }

    func registerOperation() {
        pendingOperations += 1
    }

    func completeOperation() {
        pendingOperations = max(0, pendingOperations - 1)
        if finishedScheduling && pendingOperations == 0 && completed == false {
            finish()
        }
    }

    func finishSchedulingOperations() {
        finishedScheduling = true
        if pendingOperations == 0 && completed == false {
            finish()
        }
    }

    func finish() {
        guard completed == false else { return }
        completed = true
        onComplete()
    }
}
