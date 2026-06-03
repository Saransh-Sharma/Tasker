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

public struct CelebrationEvent: Equatable {
    public let kind: CelebrationKind
    public let awardedXP: Int
    public let level: Int
    public let milestone: XPCalculationEngine.Milestone?
    public let achievementKey: String?
    public let occurredAt: Date
    public let signature: String

    public static func from(_ result: XPEventResult) -> CelebrationEvent? {
        guard result.awardedXP > 0 else { return nil }
        let unlockedKey = result.unlockedAchievements
            .map(\.achievementKey)
            .sorted()
            .first

        if let milestone = result.crossedMilestone {
            return CelebrationEvent(
                kind: .milestone,
                awardedXP: result.awardedXP,
                level: result.level,
                milestone: milestone,
                achievementKey: unlockedKey,
                occurredAt: result.celebration?.occurredAt ?? Date(),
                signature: "milestone:\(result.totalXP):\(milestone.xpThreshold)"
            )
        }
        if result.didLevelUp {
            return CelebrationEvent(
                kind: .levelUp,
                awardedXP: result.awardedXP,
                level: result.level,
                milestone: nil,
                achievementKey: unlockedKey,
                occurredAt: result.celebration?.occurredAt ?? Date(),
                signature: "levelup:\(result.totalXP):\(result.level)"
            )
        }
        if let unlockedKey {
            return CelebrationEvent(
                kind: .achievementUnlock,
                awardedXP: result.awardedXP,
                level: result.level,
                milestone: nil,
                achievementKey: unlockedKey,
                occurredAt: result.celebration?.occurredAt ?? Date(),
                signature: "achievement:\(result.totalXP):\(unlockedKey)"
            )
        }
        return CelebrationEvent(
            kind: .xpBurst,
            awardedXP: result.awardedXP,
            level: result.level,
            milestone: nil,
            achievementKey: nil,
            occurredAt: result.celebration?.occurredAt ?? Date(),
            signature: "xpburst:\(result.totalXP):\(result.awardedXP):\(result.level)"
        )
    }
}
