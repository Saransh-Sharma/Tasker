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

struct HomeTimelineReplanCandidateSignature: Equatable {
    let taskID: UUID
    let kind: HomeReplanCandidateKind
    let anchorDate: Date?
    let anchorEndDate: Date?

    init(_ candidate: HomeReplanCandidate) {
        taskID = candidate.task.id
        kind = candidate.kind
        anchorDate = candidate.anchorDate
        anchorEndDate = candidate.anchorEndDate
    }
}
