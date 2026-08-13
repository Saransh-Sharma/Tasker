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
    typealias OperationID = UUID

    let onComplete: () -> Void
    var pendingOperationIDs: Set<OperationID> = []
    var finishedScheduling = false
    var completed = false

    init(onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
    }

    func registerOperation() -> OperationID {
        let id = OperationID()
        pendingOperationIDs.insert(id)
        return id
    }

    func completeOperation(_ id: OperationID) {
        guard pendingOperationIDs.remove(id) != nil else {
            logWarning(
                event: "home_reload_batch_unknown_operation",
                message: "Ignored completion for an unknown Home reload batch operation",
                fields: ["operation_id": id.uuidString]
            )
            assertionFailure("Unknown Home reload batch operation completed")
            return
        }
        if finishedScheduling && pendingOperationIDs.isEmpty && completed == false {
            finish()
        }
    }

    func finishSchedulingOperations() {
        finishedScheduling = true
        if pendingOperationIDs.isEmpty && completed == false {
            finish()
        }
    }

    func finish() {
        guard completed == false else { return }
        completed = true
        onComplete()
    }
}
