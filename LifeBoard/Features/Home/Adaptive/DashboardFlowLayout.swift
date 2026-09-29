import SwiftUI
import LifeBoardDomain

struct DashboardLayoutRevision: Equatable {
    var id: UUID?
    var expanded = false
    var content: HomeCardSnapshot?
    var dynamicType = ""
    var locale = ""
}

struct DashboardLayoutRevisionKey: LayoutValueKey {
    static let defaultValue = DashboardLayoutRevision()
}

struct DashboardPresetLayoutKey: LayoutValueKey {
    static let defaultValue: WidgetSizePreset = .standard
}

extension View {
    func dashboardPreset(_ value: WidgetSizePreset) -> some View {
        layoutValue(key: DashboardPresetLayoutKey.self, value: value)
    }

}

struct DashboardFlowLayout: Layout {
    let isRegular: Bool
    let usesSingleColumn: Bool
    private let spacing: CGFloat = 12

    struct Cache {
        var signature: Signature?
        var result: LayoutResult?
        var calculationCount = 0
    }

    struct Signature: Equatable {
        let width: CGFloat
        let isRegular: Bool
        let usesSingleColumn: Bool
        let presets: [WidgetSizePreset]
        let revisions: [DashboardLayoutRevision]
    }

    struct LayoutResult {
        let frames: [CGRect]
        let height: CGFloat
    }

    func makeCache(subviews: Subviews) -> Cache {
        Cache()
    }

    func updateCache(_ cache: inout Cache, subviews: Subviews) {
        cache.signature = nil
        cache.result = nil
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize {
        let width = proposal.width ?? 360
        let result = cachedFrames(width: width, subviews: subviews, cache: &cache)
        return CGSize(width: width, height: result.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) {
        let result = cachedFrames(width: bounds.width, subviews: subviews, cache: &cache)
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                anchor: .topLeading,
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    private func cachedFrames(width: CGFloat, subviews: Subviews, cache: inout Cache) -> LayoutResult {
        let signature = Signature(
            width: width,
            isRegular: isRegular,
            usesSingleColumn: usesSingleColumn,
            presets: subviews.map { $0[DashboardPresetLayoutKey.self] },
            revisions: subviews.map { $0[DashboardLayoutRevisionKey.self] }
        )
        if cache.signature == signature, let result = cache.result {
            return result
        }
        let result = frames(width: width, subviews: subviews)
        cache.signature = signature
        cache.result = result
        cache.calculationCount &+= 1
        PerformanceTrace.event("DashboardLayoutCalculated", value: cache.calculationCount)
        return result
    }

    private func frames(width: CGFloat, subviews: Subviews) -> LayoutResult {
        let columnCount = usesSingleColumn ? 1 : (isRegular ? (width >= 1_100 ? 12 : 8) : 4)
        let spans = subviews.map {
            usesSingleColumn ? 1 : DashboardResponsiveSpanResolver.columns(
                for: $0[DashboardPresetLayoutKey.self], columnCount: columnCount)
        }
        let result = DashboardFramePlanner.frames(width: width, columnCount: columnCount, spans: spans) { index, itemWidth in
            subviews[index].sizeThatFits(ProposedViewSize(width: itemWidth, height: nil))
        }
        return LayoutResult(frames: result.frames, height: result.height)
    }
}
