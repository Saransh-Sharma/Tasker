//
//  EvaOverdueRescueSheetV2.swift
//  LifeBoard
//
//  Screenshot-aligned Overdue Rescue decision deck.
//

import SwiftUI
import UIKit

struct OverdueRescueDragResolution: Equatable {
    let reveal: OverdueRescueSwipeRevealKind
    let progress: Double
    let visibleOffset: CGSize
    let commitAction: OverdueRescueDecisionAction?
    let tiltDegrees: Double
}
