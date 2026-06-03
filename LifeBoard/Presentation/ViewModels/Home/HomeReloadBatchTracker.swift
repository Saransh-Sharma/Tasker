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

final class HomeReloadBatchTracker: @unchecked Sendable {
    let lock = NSLock()
    let onComplete: @Sendable () -> Void
    var pendingOperations: Int = 0
    var finishedScheduling = false
    var completed = false

    init(onComplete: @escaping @Sendable () -> Void) {
        self.onComplete = onComplete
    }

    func registerOperation() {
        lock.lock()
        pendingOperations += 1
        lock.unlock()
    }

    func completeOperation() {
        let shouldComplete: Bool = lock.withLock {
            pendingOperations = max(0, pendingOperations - 1)
            return finishedScheduling && pendingOperations == 0 && completed == false
        }
        if shouldComplete {
            finish()
        }
    }

    func finishSchedulingOperations() {
        let shouldComplete: Bool = lock.withLock {
            finishedScheduling = true
            return pendingOperations == 0 && completed == false
        }
        if shouldComplete {
            finish()
        }
    }

    func finish() {
        let shouldRun: Bool = lock.withLock {
            guard completed == false else { return false }
            completed = true
            return true
        }
        if shouldRun {
            onComplete()
        }
    }
}
