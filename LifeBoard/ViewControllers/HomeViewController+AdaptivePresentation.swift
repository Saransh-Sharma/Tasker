//
//  HomeViewController+AdaptivePresentation.swift
//  LifeBoard
//
//  Move-only HomeViewController adaptive presentation delegate support.
//

import UIKit
import SwiftUI
@preconcurrency import Combine
import SwiftData

extension HomeViewController {
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        if presentationController.presentedViewController === presentedCalendarScheduleController {
            presentedCalendarScheduleController = nil
            faceCoordinator.bottomBarState.select(faceCoordinator.activeFace.selectedBottomBarItem)
        } else if presentationController.presentedViewController === presentedEvaChatController {
            resetHomeSelectionAfterEvaChatDismissal()
        }
        resetPendingIPadModalWaitState()
        processPendingIPadModalRequest()
        scheduleOnboardingEvaluationIfNeeded()
        onboardingCoordinator?.drainPendingPresentationIfPossible()
    }
}
