//
//  HomeShellTypes.swift
//  LifeBoard
//
//  Shell layout and hosting support shared by native LifeBoard roots.
//

import Foundation
import SwiftUI

public enum HomeShellPhase: String, Equatable {
    case startup
    case interactive
}

public enum HomeScrollChromeState: String, Equatable {
    case nearTop
    case expanded
    case collapsed
    case idle
}

enum HomeAnalyticsSurfaceState: Equatable {
    case idle
    case placeholder
    case loading
    case ready
}

enum HomeSearchSurfaceState: Equatable {
    case idle
    case presenting
    case preparing
    case ready
}

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
    static let usesOpaqueHostBackground = false
    static let chromeBackdropMaximumOpacity: Double = 0.16

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
        return regularSpacing
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
        .offset(y: 0)
        .allowsHitTesting(isConcealed == false)
        .accessibilityHidden(isConcealed)
    }
}

struct HomeSurfacePrewarmPolicy {
    private static let bytesPerGib = 1_073_741_824.0

    enum Surface {
        case homeBackgroundSurfaces
        case search
        case insights
    }

    func isEligible(surface: Surface) -> Bool {
        guard ProcessInfo.processInfo.isLowPowerModeEnabled == false else { return false }
        guard thermalStateAllowsPrewarm(ProcessInfo.processInfo.thermalState) else { return false }

        let physicalMemoryGB = Double(ProcessInfo.processInfo.physicalMemory) / Self.bytesPerGib
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
