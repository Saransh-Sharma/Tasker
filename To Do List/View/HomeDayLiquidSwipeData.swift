 import SwiftUI

struct HomeDayLiquidSwipeRestingPosition {
    static func centerY(
        defaultCenterY: CGFloat,
        showsQuietTrackingRail: Bool,
        measuredQuietTrackingRailHeight: CGFloat,
        quietTrackingRailFallbackHeight: CGFloat,
        showsNeedsReplanTray: Bool,
        measuredNeedsReplanTrayHeight: CGFloat,
        needsReplanTrayFallbackHeight: CGFloat,
        topPadding: CGFloat,
        interModuleSpacing: CGFloat,
        buttonRadius: CGFloat,
        clearance: CGFloat
    ) -> CGFloat {
        guard showsQuietTrackingRail || showsNeedsReplanTray else {
            return defaultCenterY
        }

        var contentHeight = topPadding
        if showsQuietTrackingRail {
            contentHeight += max(measuredQuietTrackingRailHeight, quietTrackingRailFallbackHeight)
        }
        if showsQuietTrackingRail, showsNeedsReplanTray {
            contentHeight += interModuleSpacing
        }
        if showsNeedsReplanTray {
            contentHeight += max(measuredNeedsReplanTrayHeight, needsReplanTrayFallbackHeight)
        }

        return contentHeight + interModuleSpacing + buttonRadius + clearance
    }
}

enum HomeDayLiquidSwipeChromeVisibilityPolicy {
    static func nextVisibility(
        currentVisibility: Bool,
        for scrollChromeState: HomeScrollChromeState
    ) -> Bool {
        switch scrollChromeState {
        case .nearTop, .expanded:
            return true
        case .collapsed:
            return false
        case .idle:
            return currentVisibility
        }
    }
}

struct HomeDayLiquidSwipeChromePresentation: Equatable {
    let offsetX: CGFloat
    let scaleX: CGFloat
    let scaleY: CGFloat

    static func value(
        for side: HomeDayLiquidSwipeSide,
        isChromeVisible: Bool
    ) -> HomeDayLiquidSwipeChromePresentation {
        if isChromeVisible {
            return HomeDayLiquidSwipeChromePresentation(
                offsetX: 0,
                scaleX: 1,
                scaleY: 1
            )
        }

        let distance = HomeDayLiquidSwipeData.buttonRadius * 1.4
        return HomeDayLiquidSwipeChromePresentation(
            offsetX: side == .leading ? -distance : distance,
            scaleX: 0.82,
            scaleY: 0.96
        )
    }
}

struct HomeDayLiquidSwipeData: Equatable {
    static let buttonRadius: CGFloat = 24
    static let buttonVisualScale: CGFloat = 0.8
    static let buttonVisualRadius: CGFloat = buttonRadius * buttonVisualScale
    static let timelineHandleCenterY: CGFloat = buttonRadius + 16
    static let buttonMargin: CGFloat = 8
    static let swipeVelocity: CGFloat = 0.45
    static let cancelThreshold: CGFloat = 0.15
    static let edgeActivationWidth: CGFloat = (buttonVisualRadius * 2) + (buttonMargin * 4)
    static let waveMinLedge: CGFloat = 8
    static let waveMinHorizontalRadius: CGFloat = 48
    static let waveMinVerticalRadius: CGFloat = 82

    let side: HomeDayLiquidSwipeSide
    let centerY: CGFloat
    let progress: CGFloat
    let containerSize: CGSize
    let restingCenterY: CGFloat

    init(
        side: HomeDayLiquidSwipeSide,
        containerSize: CGSize = .zero,
        restingCenterY: CGFloat = Self.timelineHandleCenterY
    ) {
        self.init(
            side: side,
            centerY: restingCenterY,
            progress: 0,
            containerSize: containerSize,
            restingCenterY: restingCenterY
        )
    }

    init(
        side: HomeDayLiquidSwipeSide,
        centerY: CGFloat,
        progress: CGFloat,
        containerSize: CGSize,
        restingCenterY: CGFloat = Self.timelineHandleCenterY
    ) {
        self.side = side
        self.centerY = centerY
        self.progress = min(max(progress, 0), 1)
        self.containerSize = containerSize
        self.restingCenterY = restingCenterY
    }

    var buttonCenter: CGPoint {
        let offset = Self.buttonRadius + Self.buttonMargin
        return CGPoint(
            x: waveLedgeX + side.horizontalSign * (waveHorizontalRadius - offset),
            y: clampedCenterY
        )
    }

    var buttonOpacity: Double {
        max(1 - Double(progress * 5), 0)
    }

    var waveLedgeX: CGFloat {
        let ledge = Self.waveMinLedge.interpolate(to: width, in: progress, min: 0.2, max: 0.8)
        return side == .leading ? ledge : width - ledge
    }

    var waveHorizontalRadius: CGFloat {
        let p1: CGFloat = 0.4
        let target = width * 0.8
        if progress <= p1 {
            return Self.waveMinHorizontalRadius.interpolate(to: target, in: progress, max: p1)
        }
        if progress >= 1 {
            return target
        }

        let t = (progress - p1) / (1 - p1)
        let mass = 9.8
        let beta = 40 / (2 * mass)
        let omega = sqrt(max(0, -pow(beta, 2) + pow(50 / mass, 2)))
        let spring = exp(-beta * Double(t)) * cos(omega * Double(t))
        return target * CGFloat(spring)
    }

    var waveVerticalRadius: CGFloat {
        Self.waveMinVerticalRadius.interpolate(to: height * 0.9, in: progress, max: 0.4)
    }

    func sized(to size: CGSize) -> HomeDayLiquidSwipeData {
        HomeDayLiquidSwipeData(
            side: side,
            centerY: centerY,
            progress: progress,
            containerSize: size,
            restingCenterY: restingCenterY
        )
    }

    func resting(at restingCenterY: CGFloat) -> HomeDayLiquidSwipeData {
        HomeDayLiquidSwipeData(
            side: side,
            centerY: centerY,
            progress: progress,
            containerSize: containerSize,
            restingCenterY: restingCenterY
        )
    }

    func initial() -> HomeDayLiquidSwipeData {
        HomeDayLiquidSwipeData(
            side: side,
            centerY: restingCenterY,
            progress: 0,
            containerSize: containerSize,
            restingCenterY: restingCenterY
        )
    }

    func final() -> HomeDayLiquidSwipeData {
        HomeDayLiquidSwipeData(
            side: side,
            centerY: centerY,
            progress: 1,
            containerSize: containerSize,
            restingCenterY: restingCenterY
        )
    }

    func drag(translation: CGSize, location: CGPoint) -> HomeDayLiquidSwipeData {
        let horizontalDistance = side.horizontalSign * translation.width
        let nextProgress = min(1, max(0, horizontalDistance * Self.swipeVelocity / width))
        return HomeDayLiquidSwipeData(
            side: side,
            centerY: min(max(location.y, 0), height),
            progress: nextProgress,
            containerSize: containerSize,
            restingCenterY: restingCenterY
        )
    }

    func isCancelled(translation: CGSize, location: CGPoint) -> Bool {
        drag(translation: translation, location: location).progress < Self.cancelThreshold
    }

    static func side(forStartLocation location: CGPoint, containerSize: CGSize) -> HomeDayLiquidSwipeSide? {
        let width = max(containerSize.width, 1)
        if location.x <= edgeActivationWidth {
            return .leading
        }
        if location.x >= width - edgeActivationWidth {
            return .trailing
        }
        return nil
    }

    private var width: CGFloat {
        max(containerSize.width, 1)
    }

    private var height: CGFloat {
        max(containerSize.height, 1)
    }

    private var clampedCenterY: CGFloat {
        min(max(centerY, 0), height)
    }
}

private extension CGFloat {
    func interpolate(to target: CGFloat, in fraction: CGFloat, min: CGFloat = 0, max: CGFloat = 1) -> CGFloat {
        if fraction <= min {
            return self
        }
        if fraction >= max {
            return target
        }
        return self + (target - self) * (fraction - min) / (max - min)
    }
}
