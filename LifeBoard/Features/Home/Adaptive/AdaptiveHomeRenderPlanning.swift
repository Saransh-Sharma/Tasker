import SwiftUI
import LifeBoardDomain

struct HomeDashboardRenderPlan: Equatable {
    var budget: HomeSectionBudget
    var visible: [DashboardWidgetPlacementValue]
    var today: [DashboardWidgetPlacementValue]
    var keepSteady: [DashboardWidgetPlacementValue]
    var closeLoop: [DashboardWidgetPlacementValue]
    var supporting: [DashboardWidgetPlacementValue]
    var resolvedKinds: [UUID: DashboardWidgetKind]
    var effectivePresets: [UUID: WidgetSizePreset]
    var effectiveRoles: [UUID: HomeSectionRole]
}

extension HomeDashboardRenderPlan {
    static let empty = HomeDashboardRenderPlan(budget: .init(), visible: [], today: [], keepSteady: [],
        closeLoop: [], supporting: [], resolvedKinds: [:], effectivePresets: [:], effectiveRoles: [:])
}

struct HomeDashboardRenderPlanSignature: Equatable {
    let placements: [DashboardWidgetPlacementValue]
    let mode: DashboardMode
    let density: DashboardDensity
    let daypart: ResolvedDaypart
    let calendarDay: Date
    let isRegular: Bool
    let usesAccessibilityLayout: Bool
    let loopSpineEnabled: Bool
    let contextCandidates: [String]
    var candidateInputs: [HomeContextCandidate] = []
    var dynamicType: String = ""
    var locale: String = ""
    var timeZone: String = ""
    var permitsSensitive = false
}

@MainActor
final class HomeDashboardRenderPlanCache {
    private var signature: HomeDashboardRenderPlanSignature?
    private var plan: HomeDashboardRenderPlan?
    private(set) var buildCount = 0

    func resolve(
        signature: HomeDashboardRenderPlanSignature,
        build: () -> HomeDashboardRenderPlan
    ) -> HomeDashboardRenderPlan {
        if self.signature == signature, let plan { return plan }
        let next = build()
        self.signature = signature
        plan = next
        buildCount &+= 1
        PerformanceTrace.event("HomeDashboardRenderPlanBuilt", value: buildCount)
        return next
    }
}

/// Pure geometry boundary; SwiftUI still owns when measurements are invalidated.
enum DashboardFramePlanner {
    struct Result: Equatable {
        let frames: [CGRect]
        let height: CGFloat
    }
    static func frames(width: CGFloat, columnCount: Int, spans: [Int],
        measure: (Int, CGFloat) -> CGSize) -> Result {
        let columnCount = max(1, columnCount)
        let spacing: CGFloat = 12
        let columnWidth = max(0, (width - (CGFloat(columnCount - 1) * spacing)) / CGFloat(columnCount))
        var result = Array(repeating: CGRect.zero, count: spans.count)
        var columnHeights = Array(repeating: CGFloat.zero, count: columnCount)

        for index in spans.indices {
            let requestedSpan = spans[index]
            let itemSpan = min(columnCount, max(1, requestedSpan))
            var bestColumn = 0
            var bestY = CGFloat.greatestFiniteMagnitude

            if columnCount > itemSpan {
                for start in 0...(columnCount - itemSpan) {
                    let candidateY = columnHeights[start..<(start + itemSpan)].max() ?? 0
                    if candidateY < bestY {
                        bestY = candidateY
                        bestColumn = start
                    }
                }
            } else {
                bestY = columnHeights.max() ?? 0
            }

            let itemWidth = (columnWidth * CGFloat(itemSpan)) + (spacing * CGFloat(itemSpan - 1))
            let measured = measure(index, itemWidth)
            let x = CGFloat(bestColumn) * (columnWidth + spacing)
            result[index] = CGRect(x: x, y: bestY, width: itemWidth, height: measured.height)
            let nextHeight = bestY + measured.height + spacing
            for column in bestColumn..<(bestColumn + itemSpan) {
                columnHeights[column] = nextHeight
            }
        }

        widenRowsWithNoNeighbour(&result, fullWidth: width, measure: measure)

        return Result(frames: result, height: max(0, result.map(\.maxY).max() ?? 0))
    }
    /// Gives a card the full content width when nothing sits beside it.
    ///
    /// Spans are declared against the semantic grid, so a two-column card in a
    /// section that only ever contains one card rendered at half width with the
    /// other half left empty — Home's "Today" section did exactly that, squeezing
    /// three-word task titles onto two lines each while the space next to them
    /// stayed blank. The same happened to a trailing odd card in a longer section.
    ///
    /// A card alone in its vertical band is safe to widen: because nothing overlaps
    /// that band, re-measuring only changes its own height, so everything below it
    /// shifts by that delta and no repacking is needed. Subview order is untouched,
    /// which matters because the Home hierarchy test walks widgets top to bottom
    /// and cannot scroll back.
    private static func widenRowsWithNoNeighbour(
        _ frames: inout [CGRect],
        fullWidth: CGFloat,
        measure: (Int, CGFloat) -> CGSize
    ) {
        let tolerance: CGFloat = 0.5
        var hasNeighbour = Array(repeating: false, count: frames.count)
        var active: [Int] = []

        // Sweep top-to-bottom. The active set contains only vertical ranges
        // that can overlap the current card, replacing the previous all-pairs
        // search while preserving its exact overlap rule.
        for index in frames.indices.sorted(by: { frames[$0].minY < frames[$1].minY }) {
            let current = frames[index]
            active.removeAll { frames[$0].maxY <= current.minY + tolerance }
            for other in active {
                hasNeighbour[index] = true
                hasNeighbour[other] = true
            }
            active.append(index)
        }

        for index in frames.indices {
            let original = frames[index]
            guard original.width < fullWidth - tolerance else { continue }
            guard hasNeighbour[index] == false else { continue }

            let measured = measure(index, fullWidth)
            frames[index] = CGRect(
                x: 0,
                y: original.minY,
                width: fullWidth,
                height: measured.height
            )

            let delta = measured.height - original.height
            guard abs(delta) > tolerance else { continue }
            for other in frames.indices where other != index {
                if frames[other].minY >= original.maxY - tolerance {
                    frames[other].origin.y += delta
                }
            }
        }
    }
}

/// Home presets are defined against the canonical four-column phone grid.
/// Regular-width layouts preserve that semantic density by scaling spans into
/// their 8/12-column coordinate spaces; otherwise a standard two-column card
/// becomes an unreadable one-sixth-width strip on a wide iPad.
enum DashboardResponsiveSpanResolver {
    static func columns(for preset: WidgetSizePreset, columnCount: Int) -> Int {
        let safeColumnCount = max(1, columnCount)
        let canonicalColumnCount = 4
        let scale = max(1, safeColumnCount / canonicalColumnCount)
        return min(safeColumnCount, preset.canonicalGridSpan.columns * scale)
    }
}
/// The read-only half of Home's dashboard: which placements are visible in a
/// mode, which section each one belongs to, which widget a smart slot
/// resolves to, and the size a placement takes at accessibility sizes.
/// Captured from Home's state once per use; it owns nothing.
@MainActor
struct HomeDashboardRenderPlanner {
    let store: AdaptiveHomeStore
    let modePolicy: any DashboardModePolicy
    let dashboardDensity: DashboardDensity
    let usesAccessibilityLayout: Bool

    /// Section membership now comes from `DashboardWidgetDescriptor.sectionRole`.
    /// It used to live as three hardcoded string sets here plus a fourth copy
    /// in the layout repository — registering a new kind silently dropped it
    /// into "Your space", and the two anchored copies could drift apart.
    func descriptor(for placement: DashboardWidgetPlacementValue) -> DashboardWidgetDescriptor? {
        store.registry.descriptor(for: DashboardWidgetKind(rawValue: placement.widgetKind))
    }

    func visiblePlacements(for mode: DashboardMode) -> [DashboardWidgetPlacementValue] {
        return store.activeLayout.placements
            .filter { placement in
                guard placement.isVisible, let descriptor = descriptor(for: placement) else { return false }
                // An anchored role is rendered by its own fixed section. A card
                // the user deliberately pinned stays reachable in "Your space"
                // — the repository preserves those, so dropping them here left
                // them persisted forever and never drawn.
                if effectiveSectionRole(for: placement) == .anchored, placement.ownership != .pinned { return false }
                // The spine draws Focus Now itself, so a pinned copy rendered
                // the same `heroSnapshot` a second time on one screen. Dropped
                // at read time like `.closeLoop`, not unpinned: the placement
                // stays in the repository, so turning the spine off brings the
                // person's own arrangement back exactly as they left it.
                if V2FeatureFlags.homeLoopSpineV1Enabled, placement.widgetKind == DashboardWidgetKind.focusNow.rawValue { return false }
                return modePolicy.permits(descriptor, in: mode)
            }
            .sorted { $0.ordinal < $1.ordinal }
    }

    func effectiveSectionRole(for placement: DashboardWidgetPlacementValue) -> HomeSectionRole {
        let resolved = placement.sectionOverride ?? descriptor(for: placement)?.sectionRole ?? .userSpace
        // Under the spine, "Close the loop" is no longer a rendered section —
        // the spine is. Its placements fall into the pinned dashboard rather
        // than vanishing.
        //
        // Coalesced at *read* time on purpose. `.closeLoop` is persisted in
        // `sectionOverride`, so deleting the case or rewriting stored rows would
        // break decoding of layouts people already have; this is reversible by
        // flipping the flag and touches no data.
        guard V2FeatureFlags.homeLoopSpineV1Enabled, resolved == .closeLoop else { return resolved }
        return .userSpace
    }

    func buildDashboardRenderPlan(
        mode: DashboardMode,
        daypart: ResolvedDaypart,
        now: Date
    ) -> HomeDashboardRenderPlan {
        let visible = visiblePlacements(for: mode)
        var today: [DashboardWidgetPlacementValue] = []
        var keepSteady: [DashboardWidgetPlacementValue] = []
        var closeLoop: [DashboardWidgetPlacementValue] = []
        var supporting: [DashboardWidgetPlacementValue] = []
        var resolvedKinds: [UUID: DashboardWidgetKind] = [:]
        var effectivePresets: [UUID: WidgetSizePreset] = [:]
        var effectiveRoles: [UUID: HomeSectionRole] = [:]
        for placement in visible {
            let role = effectiveSectionRole(for: placement)
            effectiveRoles[placement.id] = role
            resolvedKinds[placement.id] = resolvedWidgetKind(
                for: placement,
                daypart: daypart,
                now: now
            )
            effectivePresets[placement.id] = effectivePreset(for: placement.semanticSize)
            switch role {
            case .today: today.append(placement)
            case .keepSteady: keepSteady.append(placement)
            case .closeLoop: closeLoop.append(placement)
            default: supporting.append(placement)
            }
        }
        return HomeDashboardRenderPlan(
            budget: modePolicy.sectionBudget(for: mode).applying(dashboardDensity),
            visible: visible,
            today: today,
            keepSteady: keepSteady,
            closeLoop: closeLoop,
            supporting: supporting,
            resolvedKinds: resolvedKinds,
            effectivePresets: effectivePresets,
            effectiveRoles: effectiveRoles
        )
    }

    func resolvedWidgetKind(
        for placement: DashboardWidgetPlacementValue,
        daypart: ResolvedDaypart,
        now: Date = HomeReferenceClock.now
    ) -> DashboardWidgetKind {
        let fallback = DashboardWidgetKind(rawValue: placement.widgetKind)
        guard placement.ownership == .smart,
              let slot = placement.smartSlot,
              smartSlotIsEligible(slot, daypart: daypart, now: now) else { return fallback }
        if let frozen = slot.frozenWidgetKind {
            return DashboardWidgetKind(rawValue: frozen)
        }
        return store.contextSelection.candidates.first(where: { candidate in
            slot.allowedDestinations.contains(candidate.destination)
                && (store.registry.descriptor(for: candidate.widgetKind)?.supportedSizes.contains(placement.semanticSize) ?? false)
        })?.widgetKind ?? fallback
    }

    func smartSlotIsEligible(
        _ slot: HomeSmartSlotConfiguration,
        daypart: ResolvedDaypart,
        now: Date = HomeReferenceClock.now
    ) -> Bool {
        switch slot.schedule {
        case .always:
            return true
        case .weekend:
            return Calendar.current.isDateInWeekend(now)
        case .morning:
            return daypart == .morning
        case .workday:
            return Calendar.current.isDateInWeekend(now) == false
                && (daypart == .morning || daypart == .afternoon)
        case .evening:
            return daypart == .evening || daypart == .night
        }
    }

    func effectivePreset(for saved: WidgetSizePreset) -> WidgetSizePreset {
        usesAccessibilityLayout ? .wide : saved
    }
}
