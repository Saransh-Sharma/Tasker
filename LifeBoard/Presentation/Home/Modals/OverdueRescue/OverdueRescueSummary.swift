//
//  EvaOverdueRescueSheetV2.swift
//  LifeBoard
//
//  Screenshot-aligned Overdue Rescue decision deck.
//

import SwiftUI
import UIKit

struct OverdueRescueSummary: Equatable, Sendable {
    var kept = 0
    var moved = 0
    var edited = 0
    var deleted = 0

    var reviewed: Int { kept + moved + edited + deleted }
}
