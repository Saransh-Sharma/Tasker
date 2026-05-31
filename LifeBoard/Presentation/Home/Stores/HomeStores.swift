//
//  HomeStores.swift
//  LifeBoard
//

import Combine
import Foundation

@MainActor
final class HomeChromeStore: ObservableObject {
    @Published private(set) var snapshot: HomeChromeSnapshot = .empty

    func apply(_ snapshot: HomeChromeSnapshot) {
        guard self.snapshot != snapshot else { return }
        self.snapshot = snapshot
    }
}

@MainActor
final class HomeTasksStore: ObservableObject {
    @Published private(set) var snapshot: HomeTasksSnapshot = .empty

    func apply(_ snapshot: HomeTasksSnapshot) {
        guard self.snapshot != snapshot else { return }
        self.snapshot = snapshot
    }
}

@MainActor
final class HomeHabitsStore: ObservableObject {
    @Published private(set) var snapshot: HomeHabitsSnapshot = .empty

    func apply(_ snapshot: HomeHabitsSnapshot) {
        guard self.snapshot != snapshot else { return }
        self.snapshot = snapshot
    }
}

@MainActor
final class HomeOverlayStore: ObservableObject {
    @Published private(set) var snapshot: HomeOverlaySnapshot = .empty

    func apply(_ snapshot: HomeOverlaySnapshot) {
        guard self.snapshot != snapshot else { return }
        self.snapshot = snapshot
    }
}

@MainActor
final class HomeCalendarStore: ObservableObject {
    @Published private(set) var snapshot: HomeCalendarSnapshot = .empty

    func apply(_ snapshot: HomeCalendarSnapshot) {
        guard self.snapshot != snapshot else { return }
        self.snapshot = snapshot
    }
}

@MainActor
final class HomeTimelineStore: ObservableObject {
    @Published private(set) var state: HomeTimelineRenderState = .empty

    func apply(_ state: HomeTimelineRenderState) {
        guard self.state != state else { return }
        self.state = state
    }
}

@MainActor
final class HomeFaceCoordinator: ObservableObject {
    @Published private(set) var activeFace: HomeSunriseFace = .tasks
    @Published private(set) var shellPhase: HomeShellPhase = .startup
    @Published private(set) var layoutMetrics: HomeLayoutMetrics = .zero
    @Published private(set) var searchMutationRevision: UInt64 = 0
    @Published private(set) var analyticsSurfaceState: HomeAnalyticsSurfaceState = .idle
    @Published private(set) var searchSurfaceState: HomeSearchSurfaceState = .idle
    @Published private(set) var chatPromptFocusRequestID: UInt64 = 0
    @Published var insightsViewModel: InsightsViewModel?
    private var faceBeforeSearch: HomeSunriseFace?

    let bottomBarState = HomeBottomBarState()

    func setActiveFace(_ face: HomeSunriseFace) {
        guard activeFace != face else { return }
        if face == .search, activeFace != .search {
            faceBeforeSearch = activeFace
        }
        activeFace = face
        bottomBarState.select(face.selectedBottomBarItem)
    }

    func returnFaceAfterSearch() -> HomeSunriseFace {
        faceBeforeSearch ?? .tasks
    }

    func setShellPhase(_ phase: HomeShellPhase) {
        guard shellPhase != phase else { return }
        shellPhase = phase
    }

    func setLayoutMetrics(_ metrics: HomeLayoutMetrics) {
        guard layoutMetrics != metrics else { return }
        layoutMetrics = metrics
    }

    func setAnalyticsSurfaceState(_ state: HomeAnalyticsSurfaceState) {
        guard analyticsSurfaceState != state else { return }
        analyticsSurfaceState = state
    }

    func setSearchSurfaceState(_ state: HomeSearchSurfaceState) {
        guard searchSurfaceState != state else { return }
        searchSurfaceState = state
    }

    func recordSearchMutation() {
        searchMutationRevision &+= 1
    }

    func requestChatPromptFocus() {
        chatPromptFocusRequestID &+= 1
    }
}
