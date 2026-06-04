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

public struct HabitRecoveryReflectionPrompt: Equatable, Identifiable, Sendable {
    public let habitID: UUID
    public let habitTitle: String
    public let date: Date

    public init(habitID: UUID, habitTitle: String, date: Date) {
        self.habitID = habitID
        self.habitTitle = habitTitle
        self.date = date
    }

    public var id: String {
        "\(habitID.uuidString):\(date.timeIntervalSince1970)"
    }
}
