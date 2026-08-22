import SwiftUI
import UIKit

/// The staged-scenario surface. Despite the name it renders every
/// `PlanningScenarioSource` Plan can be handed, not just Minimum Viable Day —
/// the copy switches, the shape does not.
struct PlanMinimumViableDayCard: View {
    let store: PlanStore

    var body: some View {
        if let scenario = store.pendingScenario {
            VStack(alignment: .leading, spacing: 10) {
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
                    VStack(alignment: .leading, spacing: 2) {
                        Text(change.title).font(.subheadline.weight(.semibold))
                        if let after = change.after {
                            Text(after)
                                .font(.caption)
                                .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                        }
                    }
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
                    Button(
                        scenario.source == .minimumViableDay
                            ? "Keep current day"
                            : "Keep current plan"
                    ) { store.dismissScenario() }
                        .buttonStyle(.bordered)
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
