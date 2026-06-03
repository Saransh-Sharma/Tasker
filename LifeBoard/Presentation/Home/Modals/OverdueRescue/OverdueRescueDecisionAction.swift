//
//  EvaOverdueRescueSheetV2.swift
//  LifeBoard
//
//  Screenshot-aligned Overdue Rescue decision deck.
//

import SwiftUI
import UIKit

enum OverdueRescueDecisionAction: String, Codable, Sendable {
    case keepToday
    case moveLater
    case edit
    case delete
}
