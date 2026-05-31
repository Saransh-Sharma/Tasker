//
//  HomeShellTypes.swift
//  LifeBoard
//
//  Shell layout and hosting support for HomeViewController.
//

import Foundation
import SwiftUI

struct HomeLayoutMetrics: Equatable {
    let width: CGFloat
    let height: CGFloat
    let safeAreaTop: CGFloat
    let safeAreaBottom: CGFloat
    let keyboardOverlapHeight: CGFloat
    let backdropGradientHeight: CGFloat
    let taskListBottomInset: CGFloat
    let chatComposerBottomInset: CGFloat
    let insightsViewportHeight: CGFloat

    static let zero = HomeLayoutMetrics(
        width: 0,
        height: 0,
        safeAreaTop: 0,
        safeAreaBottom: 0,
        keyboardOverlapHeight: 0,
        backdropGradientHeight: 0,
        taskListBottomInset: 80,
        chatComposerBottomInset: 80,
        insightsViewportHeight: 560
    )

    var isReady: Bool {
        width > 1 && height > 1
    }
}

struct HomeBottomBarVisibilityPolicy {
    static let phoneDockHostHeight: CGFloat = 82

    static func restingDockDownshift(
        safeAreaBottom: CGFloat,
        verticalLift: CGFloat
    ) -> CGFloat {
        max(0, safeAreaBottom - 10) - verticalLift
    }

    static func shouldConcealBottomBar(
        activeFace: HomeSunriseFace,
        isPromptFocused: Bool,
        keyboardOverlapHeight: CGFloat
    ) -> Bool {
        activeFace == .chat && (isPromptFocused || keyboardOverlapHeight > 0.5)
    }

    static func chatComposerClearance(
        layoutClass: LifeBoardLayoutClass,
        bottomOverlayObstruction: CGFloat,
        keyboardOverlapHeight: CGFloat,
        isBottomBarConcealed: Bool,
        idleSpacing: CGFloat,
        idleExtraSpacing: CGFloat,
        keyboardSpacing: CGFloat,
        regularSpacing: CGFloat
    ) -> CGFloat {
        guard layoutClass == .phone else { return regularSpacing }
        if keyboardOverlapHeight > 0.5 {
            return keyboardOverlapHeight + keyboardSpacing
        }
        if bottomOverlayObstruction > 0.5 {
            return bottomOverlayObstruction + idleSpacing + idleExtraSpacing
        }
        if isBottomBarConcealed {
            return regularSpacing
        }
        return regularSpacing
    }
}

struct PhoneHomeRootContainer: View {
    let root: SunriseAppShellView
    let layoutClass: LifeBoardLayoutClass

    var body: some View {
        root.lifeboardLayoutClass(layoutClass)
    }
}

struct HomeHostRootView: View {
    let layoutClass: LifeBoardLayoutClass
    let phoneRoot: SunriseAppShellView?
    let iPadRoot: AnyView?

    @ViewBuilder
    var body: some View {
        if let phoneRoot {
            PhoneHomeRootContainer(root: phoneRoot, layoutClass: layoutClass)
        } else if let iPadRoot {
            iPadRoot
        } else {
            EmptyView()
        }
    }
}

struct HomeBottomBarContainer: View {
    let state: HomeBottomBarState
    let shellPhase: HomeShellPhase
    let isConcealed: Bool
    let onHome: () -> Void
    let onCalendar: () -> Void
    let onChartsToggle: () -> Void
    let onSearch: () -> Void
    let onChat: () -> Void
    let onCreate: () -> Void
    let layoutClass: LifeBoardLayoutClass

    var body: some View {
        LBBottomDock(
            state: state,
            shellPhase: shellPhase,
            onHome: onHome,
            onCalendar: onCalendar,
            onChartsToggle: onChartsToggle,
            onSearch: onSearch,
            onChat: onChat,
            onCreate: onCreate
        )
        .padding(.horizontal, LifeBoardThemeManager.shared.tokens(for: layoutClass).spacing.s16)
        .padding(.bottom, 0)
        .ignoresSafeArea(.container, edges: .bottom)
        .offset(y: 0)
        .allowsHitTesting(isConcealed == false)
        .accessibilityHidden(isConcealed)
    }
}

struct HomeSurfacePrewarmPolicy {
    enum Surface {
        case homeBackgroundSurfaces
        case search
        case insights
    }

    func isEligible(surface: Surface) -> Bool {
        guard ProcessInfo.processInfo.isLowPowerModeEnabled == false else { return false }
        guard thermalStateAllowsPrewarm(ProcessInfo.processInfo.thermalState) else { return false }

        let physicalMemoryGB = Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824
        switch surface {
        case .homeBackgroundSurfaces:
            return physicalMemoryGB >= 4
        case .search:
            return physicalMemoryGB >= 3
        case .insights:
            return physicalMemoryGB >= 4
        }
    }

    private func thermalStateAllowsPrewarm(_ state: ProcessInfo.ThermalState) -> Bool {
        switch state {
        case .nominal, .fair:
            return true
        case .serious, .critical:
            return false
        @unknown default:
            return false
        }
    }
}
