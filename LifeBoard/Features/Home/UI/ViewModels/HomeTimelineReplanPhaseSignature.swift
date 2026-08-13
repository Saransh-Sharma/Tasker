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

enum HomeTimelineReplanPhaseSignature: Equatable {
    case trayHidden
    case trayVisible(total: Int)
    case launcher(total: Int)
    case card(candidateIndex: Int)
    case placement(candidateID: UUID, defaultDay: Date)
    case summary(totalResolved: Int, skippedCount: Int)
    case skippedReview

    init(_ phase: HomeReplanSessionPhase) {
        switch phase {
        case .trayHidden:
            self = .trayHidden
        case .trayVisible(let summary):
            self = .trayVisible(total: summary.count)
        case .launcher(let summary):
            self = .launcher(total: summary.count)
        case .card(let candidateIndex):
            self = .card(candidateIndex: candidateIndex)
        case .placement(let candidate, let defaultDay):
            self = .placement(candidateID: candidate.id, defaultDay: defaultDay)
        case .summary(let outcomes, let skippedCount):
            self = .summary(totalResolved: outcomes.totalResolved, skippedCount: skippedCount)
        case .skippedReview:
            self = .skippedReview
        }
    }
}
