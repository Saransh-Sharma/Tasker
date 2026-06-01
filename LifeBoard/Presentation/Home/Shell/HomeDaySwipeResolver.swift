//
//  HomeDaySwipeResolver.swift
//  LifeBoard
//
//  Pure day-swipe gesture resolution for the Home shell.
//

import SwiftUI

struct HomeDaySwipeResolver {
    let minimumTranslation: CGFloat
    let minimumPredictedTranslation: CGFloat
    let horizontalDominanceRatio: CGFloat
    let liquidActivationMinimumTranslation: CGFloat
    let liquidActivationHorizontalDominanceRatio: CGFloat

    static let `default` = HomeDaySwipeResolver(
        minimumTranslation: 56,
        minimumPredictedTranslation: 92,
        horizontalDominanceRatio: 1.35,
        liquidActivationMinimumTranslation: 8,
        liquidActivationHorizontalDominanceRatio: 1.0
    )

    func resolvedDirection(
        translation: CGSize,
        predictedEndTranslation: CGSize
    ) -> HomeDayNavigationDirection? {
        let horizontal = translation.width
        let predictedHorizontal = predictedEndTranslation.width
        let vertical = translation.height
        let dominantDistance = max(abs(horizontal), abs(predictedHorizontal))

        guard isHorizontallyDominant(translation: translation) else { return nil }
        guard dominantDistance >= minimumTranslation || abs(predictedHorizontal) >= minimumPredictedTranslation else {
            return nil
        }

        let resolvedHorizontal = abs(predictedHorizontal) >= minimumPredictedTranslation
            ? predictedHorizontal
            : horizontal
        guard abs(resolvedHorizontal) >= max(abs(vertical) * horizontalDominanceRatio, minimumTranslation) else {
            return nil
        }

        return resolvedHorizontal < 0 ? .next : .previous
    }

    func isHorizontallyDominant(translation: CGSize) -> Bool {
        abs(translation.width) > max(abs(translation.height) * horizontalDominanceRatio, 28)
    }

    func liquidActivationSide(
        startLocation: CGPoint,
        translation: CGSize,
        containerSize: CGSize
    ) -> SunriseDaySwipeSide? {
        guard isLiquidActivationCandidate(translation: translation) else { return nil }
        guard let side = SunriseDaySwipeData.side(
            forStartLocation: startLocation,
            containerSize: containerSize
        ) else {
            return nil
        }
        guard side.horizontalSign * translation.width > 0 else { return nil }
        return side
    }

    func liquidActivationSide(
        startLocation: CGPoint,
        translation: CGSize,
        velocity: CGPoint,
        containerSize: CGSize
    ) -> SunriseDaySwipeSide? {
        guard let side = SunriseDaySwipeData.side(
            forStartLocation: startLocation,
            containerSize: containerSize
        ) else {
            return nil
        }

        let intent = liquidIntentTranslation(translation: translation, velocity: velocity)
        guard isLiquidActivationCandidate(translation: intent) else { return nil }
        guard side.horizontalSign * intent.width > 0 else { return nil }
        return side
    }

    func isLiquidActivationCandidate(translation: CGSize) -> Bool {
        let horizontalDistance = abs(translation.width)
        let verticalDistance = abs(translation.height)
        guard horizontalDistance >= liquidActivationMinimumTranslation else { return false }
        return horizontalDistance > verticalDistance * liquidActivationHorizontalDominanceRatio
    }

    func predictedEndTranslation(translation: CGSize, velocity: CGPoint) -> CGSize {
        let projectionDuration: CGFloat = 0.18
        return CGSize(
            width: translation.width + velocity.x * projectionDuration,
            height: translation.height + velocity.y * projectionDuration
        )
    }

    private func liquidIntentTranslation(translation: CGSize, velocity: CGPoint) -> CGSize {
        let horizontal = abs(translation.width) >= liquidActivationMinimumTranslation
            ? translation.width
            : velocity.x
        let vertical = abs(translation.height) >= liquidActivationMinimumTranslation
            ? translation.height
            : velocity.y
        return CGSize(width: horizontal, height: vertical)
    }
}
