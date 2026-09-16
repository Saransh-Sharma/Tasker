import SwiftUI
import UIKit

/// The staged-scenario surface. Despite the name it renders every
/// `PlanningScenarioSource` Plan can be handed, not just Minimum Viable Day —
/// the copy switches, the shape does not.
struct PlanMinimumViableDayCard: View {
    let store: PlanStore

    var body: some View {
        if let scenario = store.pendingScenario {
            VStack(alignment: .leading, spacing: 12) {
                Label(
                    Self.title(scenario.source),
                    systemImage: Self.symbol(scenario.source)
                )
                    .font(.headline)
                if let refresh = store.scenarioRefreshResult {
                    Label(
                        "Plan changed · review this refreshed proposal",
                        systemImage: "arrow.triangle.2.circlepath"
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(SemanticColorTokens.foundationApricotAccent))
                    .accessibilityIdentifier("plan.minimumViableDay.refreshed")
                    DisclosureGroup("What changed") {
                        ForEach(refresh.previousDiff) { change in
                            Text("\(change.title): \(change.after ?? "No selection")")
                                .font(.caption)
                                .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                        }
                    }
                    .font(.caption)
                }
                ForEach(scenario.diff) { change in
                    PlanScenarioDiffRow(change: change, isResolved: false)
                }
                ForEach(scenario.validationIssues, id: \.self) { issue in
                    Label(issue, systemImage: "exclamationmark.circle")
                        .font(.caption)
                        .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                }
                if scenario.source == .minimumViableDay,
                   scenario.isReadyToApply == false,
                   let snapshot = store.daySnapshot {
                    chooser(snapshot)
                }
                HStack {
                    // "Not now", the proposal contract's own words: nothing has
                    // changed, and the choice can come back later.
                    Button("Not now") {
                        Haptic.pick.play()
                        store.dismissScenario()
                    }
                        .buttonStyle(.bordered)
                        .accessibilityHint(
                            scenario.source == .minimumViableDay ? "Keeps the current day" : "Keeps the current plan"
                        )
                    Button(
                        Self.applyTitle(scenario.source)
                    ) {
                        Task { await store.applyPendingScenario() }
                    }
                    .buttonStyle(.lifeBoardPrimaryCompact)
                    .disabled(scenario.isReadyToApply == false)
                }
            }
            .foundationClayCard()
            .accessibilityIdentifier("plan.minimumViableDay.preview")
        } else {
            Button {
                store.previewMinimumViableDay()
            } label: {
                Label("Shape a Minimum Viable Day", systemImage: "leaf")
                    .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
            .accessibilityHint("Previews essential care, one achievable outcome, and protected rest before changing the plan")
            .accessibilityIdentifier("plan.minimumViableDay")
        }
    }

    private static func title(_ source: PlanningScenarioSource) -> String {
        switch source {
        case .minimumViableDay: "Minimum Viable Day"
        case .repair: "Plan repair preview"
        case .multiItemReschedule: "Reschedule preview"
        case .manual: "Plan preview"
        // Plan can render a day-close scenario if one is ever handed to it, but
        // it never builds one — Close the Day owns that surface.
        case .dayClose: "Close the day preview"
        case .dayOpen: "Today's shape"
        }
    }

    private static func symbol(_ source: PlanningScenarioSource) -> String {
        switch source {
        case .minimumViableDay: "leaf.fill"
        case .repair: "wand.and.stars"
        case .multiItemReschedule: "calendar.badge.clock"
        case .manual: "list.bullet.clipboard"
        case .dayClose: "moon.stars"
        case .dayOpen: "sunrise"
        }
    }

    private static func applyTitle(_ source: PlanningScenarioSource) -> String {
        switch source {
        case .minimumViableDay: "Apply reduced day"
        case .repair: "Apply repair"
        case .multiItemReschedule: "Apply reschedule"
        case .manual: "Apply changes"
        case .dayClose: "Close the day"
        case .dayOpen: "Start today"
        }
    }

    private func chooser(_ snapshot: PlanDaySnapshot) -> some View {
        let readyTasks = snapshot.unscheduledTasks.filter(\.dependenciesReady)
        let selected = store.minimumViableDaySelection
        return VStack(alignment: .leading, spacing: 8) {
            Text("Complete the three-part day")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
            HStack(spacing: 8) {
                Menu {
                    ForEach(readyTasks) { task in
                        Button(task.title) {
                            var next = selected
                            next.careTaskID = task.id
                            if next.outcomeTaskID == task.id {
                                next.outcomeTaskID = nil
                            }
                            store.previewMinimumViableDay(selection: next)
                        }
                    }
                } label: {
                    Label("Essential care", systemImage: "heart")
                        .frame(minHeight: 44)
                }
                .buttonStyle(.bordered)

                Menu {
                    ForEach(readyTasks.filter { $0.id != selected.careTaskID }) { task in
                        Button(task.title) {
                            var next = selected
                            next.outcomeTaskID = task.id
                            store.previewMinimumViableDay(selection: next)
                        }
                    }
                } label: {
                    Label("One outcome", systemImage: "scope")
                        .frame(minHeight: 44)
                }
                .buttonStyle(.bordered)
            }
            Menu {
                ForEach(snapshot.freeWindows.filter { $0.duration >= 15 * 60 }) { window in
                    Button("\(PlanSectionCopy.time(window.startAt))–\(PlanSectionCopy.time(window.endAt))") {
                        var next = selected
                        next.restWindowID = window.id
                        store.previewMinimumViableDay(selection: next)
                    }
                }
            } label: {
                Label("Protected rest", systemImage: "moon.zzz")
                    .frame(minHeight: 44)
            }
            .buttonStyle(.bordered)
        }
        .accessibilityIdentifier("plan.minimumViableDay.chooser")
    }
}

/// One proposed change: what it is, what it was, what it becomes.
///
/// Shared by Plan's staged scenario and Home's in-place repair. `isResolved`
/// is the after-apply state: the old value fades and is struck through while
/// the new one settles in, so "what changed" is shown rather than asserted.
struct PlanScenarioDiffRow: View {
    let change: PlanningScenarioDiff
    let isResolved: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(change.title)
                .lifeboardFont(.support)
                .fontWeight(.semibold)
                .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if let before = change.before {
                    Text(before)
                        .strikethrough(isResolved)
                        .opacity(isResolved ? 0.5 : 1)
                    Image(systemName: "arrow.right")
                        .lifeboardFont(.caption2)
                        .accessibilityHidden(true)
                }
                if let after = change.after {
                    Text(after)
                        .fontWeight(isResolved ? .semibold : .regular)
                        .foregroundStyle(Color(isResolved ? SemanticColorTokens.inkPrimary : SemanticColorTokens.inkSecondary))
                        .contentTransition(.opacity)
                }
            }
            .lifeboardFont(.caption1)
            .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(PlanScenarioDiffRow.accessibilityText(change, isResolved: isResolved))
    }

    static func accessibilityText(_ change: PlanningScenarioDiff, isResolved: Bool) -> String {
        let movement: String
        switch (change.before, change.after) {
        case let (before?, after?): movement = isResolved ? "moved from \(before) to \(after)" : "from \(before) to \(after)"
        case let (nil, after?): movement = after
        case let (before?, nil): movement = isResolved ? "removed from \(before)" : "remove from \(before)"
        case (nil, nil): movement = ""
        }
        return movement.isEmpty ? change.title : "\(change.title), \(movement)"
    }
}
