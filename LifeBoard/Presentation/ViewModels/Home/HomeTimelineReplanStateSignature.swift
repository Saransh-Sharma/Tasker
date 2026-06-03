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

struct HomeTimelineReplanStateSignature: Equatable {
    let phase: HomeTimelineReplanPhaseSignature
    let currentCandidateID: UUID?
    let candidateIndex: Int
    let candidateTotal: Int
    let isApplying: Bool
    let applyingAction: HomeReplanApplyingAction?
    let errorMessage: String?
    let placementCandidate: TimelinePlacementCandidate?

    init(_ state: HomeReplanSessionState) {
        phase = HomeTimelineReplanPhaseSignature(state.phase)
        currentCandidateID = state.currentCandidate?.id
        candidateIndex = state.candidateIndex
        candidateTotal = state.candidateTotal
        isApplying = state.isApplying
        applyingAction = state.applyingAction
        errorMessage = state.errorMessage
        placementCandidate = state.placementCandidate
    }
}
