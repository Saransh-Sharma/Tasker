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

public struct InsightsLaunchRequest: Equatable {
    public let token: UUID
    public let targetTab: InsightsViewModel.InsightsTab
    public let highlightedAchievementKey: String?

    public init(
        token: UUID = UUID(),
        targetTab: InsightsViewModel.InsightsTab = .today,
        highlightedAchievementKey: String? = nil
    ) {
        self.token = token
        self.targetTab = targetTab
        self.highlightedAchievementKey = highlightedAchievementKey
    }

    public static var `default`: InsightsLaunchRequest {
        InsightsLaunchRequest(targetTab: .today)
    }
}
