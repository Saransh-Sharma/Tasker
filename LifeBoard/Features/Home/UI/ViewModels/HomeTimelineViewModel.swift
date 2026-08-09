//
//  HomeTimelineViewModel.swift
//  LifeBoard
//
//  Move-only HomeViewModel decomposition.
//

import Foundation
import Combine
#if canImport(UIKit)
import UIKit
#endif
#if canImport(WidgetKit)
import WidgetKit
#endif

@MainActor
final class HomeTimelineViewModel: ObservableObject {
    @Published private(set) var selectedDate: Date
    @Published private(set) var sunriseAnchor: SunriseAnchor
    @Published private(set) var dragTranslation: CGFloat

    init(
        selectedDate: Date = Date(),
        sunriseAnchor: SunriseAnchor = .collapsed,
        dragTranslation: CGFloat = 0
    ) {
        self.selectedDate = selectedDate
        self.sunriseAnchor = sunriseAnchor
        self.dragTranslation = dragTranslation
    }

    func syncSelectedDate(_ date: Date) {
        guard Calendar.current.isDate(date, inSameDayAs: selectedDate) == false else { return }
        selectedDate = date
    }

    func snap(to anchor: SunriseAnchor) {
        sunriseAnchor = anchor
        dragTranslation = 0
    }

    func updateDrag(_ translation: CGFloat, metrics: HomeSunriseLayoutMetrics) {
        let baseOffset = metrics.offset(for: sunriseAnchor)
        let proposed = baseOffset + translation
        let clamped = min(max(proposed, metrics.offset(for: .collapsed)), metrics.offset(for: .fullReveal))
        dragTranslation = clamped - baseOffset
    }

    func endDrag(predictedTranslation: CGFloat, metrics: HomeSunriseLayoutMetrics) {
        let current = interactiveOffset(metrics: metrics)
        let projected = min(
            max(current + (predictedTranslation - dragTranslation), metrics.offset(for: .collapsed)),
            metrics.offset(for: .fullReveal)
        )
        let anchors: [SunriseAnchor] = [.collapsed, .midReveal, .fullReveal]
        let target = anchors.min { lhs, rhs in
            abs(metrics.offset(for: lhs) - projected) < abs(metrics.offset(for: rhs) - projected)
        } ?? .collapsed
        sunriseAnchor = target
        dragTranslation = 0
    }

    func interactiveOffset(metrics: HomeSunriseLayoutMetrics) -> CGFloat {
        let baseOffset = metrics.offset(for: sunriseAnchor)
        let proposed = baseOffset + dragTranslation
        return min(max(proposed, metrics.offset(for: .collapsed)), metrics.offset(for: .fullReveal))
    }
}

