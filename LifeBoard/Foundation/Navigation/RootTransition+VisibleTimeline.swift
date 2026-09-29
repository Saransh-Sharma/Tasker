import SwiftUI

// MARK: - Display panel

/// Visual clock only. Domain sessions always retain their canonical timestamps.
struct ActiveVisibleTimeline<Content: View>: View {
    let interval: TimeInterval
    var isActive: Bool
    let content: (VisibleTimelineContext) -> Content
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.lifeBoardRootActivity) private var rootActivity
    @State private var isVisible = true

    init(every interval: TimeInterval, isActive: Bool = true,
         @ViewBuilder content: @escaping (VisibleTimelineContext) -> Content) {
        self.interval = interval
        self.isActive = isActive
        self.content = content
    }

    var body: some View {
        let active = isActive && isVisible && scenePhase == .active && rootActivity.performsContinuousWork
        TimelineView(VisiblePeriodicSchedule(interval: interval, active: active)) { context in
            content(VisibleTimelineContext(date: context.date))
        }
        .modifier(VisualTimelineRegistration(isActive: active))
        .onScrollVisibilityChange(threshold: 0.001) { isVisible = $0 }
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false }
    }
}

struct VisibleTimelineContext { let date: Date }

struct VisiblePeriodicSchedule: TimelineSchedule {
    let interval: TimeInterval
    let active: Bool
    func entries(from startDate: Date, mode: TimelineScheduleMode) -> AnySequence<Date> {
        if !active { return AnySequence([startDate]) }
        return AnySequence(PeriodicTimelineSchedule(from: startDate, by: interval).entries(from: startDate, mode: mode))
    }
}

struct ActiveVisibleAnimationTimeline<Content: View>: View {
    var minimumInterval: Double? = nil
    let content: (VisibleTimelineContext) -> Content

    init(minimumInterval: Double? = nil,
         @ViewBuilder content: @escaping (VisibleTimelineContext) -> Content) {
        self.minimumInterval = minimumInterval
        self.content = content
    }
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.lifeBoardRootActivity) private var rootActivity
    @State private var isVisible = true

    var body: some View {
        let active = isVisible && scenePhase == .active && rootActivity.performsContinuousWork
        TimelineView(.animation(minimumInterval: minimumInterval, paused: !active)) { context in
            content(VisibleTimelineContext(date: context.date))
        }
        .modifier(VisualTimelineRegistration(isActive: active))
        .onScrollVisibilityChange(threshold: 0.001) { isVisible = $0 }
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false }
    }
}

@MainActor
enum VisualTimelineDiagnostics {
    private(set) static var activeIDs: Set<UUID> = []

    static func setActive(_ active: Bool, id: UUID) {
        let changed = active ? activeIDs.insert(id).inserted : activeIDs.remove(id) != nil
        if changed { PerformanceTrace.event("ActiveVisualTimelines", value: activeIDs.count) }
    }
}

struct VisualTimelineRegistration: ViewModifier {
    let isActive: Bool
    @State private var id = UUID()
    func body(content: Content) -> some View {
        content
            .onChange(of: isActive, initial: true) { _, active in
                VisualTimelineDiagnostics.setActive(active, id: id)
            }
            .onAppear { VisualTimelineDiagnostics.setActive(isActive, id: id) }
            .onDisappear { VisualTimelineDiagnostics.setActive(false, id: id) }
    }
}
