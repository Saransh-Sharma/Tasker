//
//  EvaOverdueRescueSheetV2.swift
//  LifeBoard
//
//  Screenshot-aligned Overdue Rescue decision deck.
//

import SwiftUI
import UIKit

enum OverdueRescueDecisionSource: String, Codable, Sendable {
    case swipe
    case tap
    case edit
    case delete
    case bulk
}
