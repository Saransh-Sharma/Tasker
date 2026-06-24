//
//  CaptureInboxDrain.swift
//  LifeBoard
//
//  Drains captures queued into the App Group by out-of-process surfaces (Control
//  Center controls, interactive widgets, Share Extension fallback) and turns each
//  into a real Inbox task. Run on `didBecomeActive`. Decoupled from the persistence
//  path via an injected capture closure so it stays testable.
//

import Foundation

@MainActor
public final class CaptureInboxDrain {

    /// Persists a single queued capture. Typically forwards `rawText` to
    /// `InboxTaskCaptureService.createTask(title:details:)`, which applies NL date parsing.
    public typealias CaptureHandler = (PendingCapture) async throws -> Void

    private let handler: CaptureHandler
    private var isDraining = false

    public init(handler: @escaping CaptureHandler) {
        self.handler = handler
    }

    /// Drains all currently-queued captures. Re-entrancy-safe; captures that arrive
    /// during a drain are picked up on the next call. Only successfully-handled
    /// captures are removed, so a transient failure leaves the item for a later retry.
    public func drain() {
        guard isDraining == false else { return }
        let queued = PendingCaptureInbox.read()
        guard queued.isEmpty == false else { return }
        isDraining = true

        Task {
            var handledIDs: Set<UUID> = []
            for capture in queued {
                do {
                    try await handler(capture)
                    handledIDs.insert(capture.id)
                } catch {
                    // Leave unhandled captures in the queue for the next drain.
                    continue
                }
            }
            if handledIDs.isEmpty == false {
                PendingCaptureInbox.remove(ids: handledIDs)
            }
            isDraining = false
        }
    }
}
