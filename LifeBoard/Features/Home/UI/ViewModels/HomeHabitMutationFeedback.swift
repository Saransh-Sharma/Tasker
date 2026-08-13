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

public struct HomeHabitMutationFeedback: Equatable, Identifiable {
    public let id: UUID
    public let message: String
    public let haptic: HomeHabitMutationFeedbackHaptic

    public init(
        id: UUID = UUID(),
        message: String,
        haptic: HomeHabitMutationFeedbackHaptic
    ) {
        self.id = id
        self.message = message
        self.haptic = haptic
    }
}
