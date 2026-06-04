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

public final class DefaultCelebrationRouter: CelebrationRouter {
    var lastShownAtByKind: [CelebrationKind: Date] = [:]
    var lastSignature: String?

    let cooldownByKind: [CelebrationKind: TimeInterval] = [
        .milestone: 0,
        .levelUp: 0.4,
        .achievementUnlock: 1.0,
        .xpBurst: 4.0
    ]

    public init() {}

    public func route(event: CelebrationEvent) -> CelebrationPresentation? {
        if lastSignature == event.signature {
            return nil
        }
        let cooldown = cooldownByKind[event.kind] ?? 0
        if let last = lastShownAtByKind[event.kind],
           cooldown > 0,
           event.occurredAt.timeIntervalSince(last) < cooldown {
            return nil
        }

        lastShownAtByKind[event.kind] = event.occurredAt
        lastSignature = event.signature
        return CelebrationPresentation(event: event)
    }
}
