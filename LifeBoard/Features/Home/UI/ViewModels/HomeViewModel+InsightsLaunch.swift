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

extension HomeViewModel {
    public func dispatchCelebration(_ result: XPEventResult?) {
        guard let result else { return }
        lastXPResult = result
        // The gamification ledger publishes only after its canonical write has
        // succeeded. Keep the completion acknowledgement at that persistence
        // boundary, without exposing XP magnitude or routing a celebration on
        // Home. Insights remains the optional place to inspect XP.
        Haptic.commit.play()
    }

    func makeHomeSearchViewModel() -> HomeSearchViewModel {
        if let retainedHomeSearchViewModel {
            return retainedHomeSearchViewModel
        }

        let resolvedViewModel = HomeSearchViewModel(useCaseCoordinator: useCaseCoordinator)
        retainedHomeSearchViewModel = resolvedViewModel
        return resolvedViewModel
    }

    func releaseHomeSearchViewModel() {
        retainedHomeSearchViewModel?.purgeCaches()
        retainedHomeSearchViewModel = nil
    }

}
