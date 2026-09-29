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
                        "Plan changed · Preview updated",
                        systemImage: "arrow.triangle.2.circlepath"
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(SemanticColorTokens.foundationApricotInk))
                    .accessibilityIdentifier("plan.minimumViableDay.refreshed")
                    DisclosureGroup("What changed") {
                        ForEach(refresh.previousDiff) { change in
                            Text("\(change.title): \(change.after ?? String(localized: "None"))")
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
                        .buttonStyle(.lifeBoardChip)
                        .accessibilityHint(
                            scenario.source == .minimumViableDay ? "Keeps the current day" : "Keeps the current plan"
                        )
                    Button(
                        store.isApplyingScenario ? "Applying…" : Self.applyTitle(scenario.source)
                    ) {
                        Task {
                            await store.applyPendingScenario()
                            // Persistence first: the haptic follows a change
                            // that actually landed.
                            if store.pendingScenario == nil, store.errorMessage == nil {
                                Haptic.commit.play()
                            }
                        }
                    }
                    .buttonStyle(.lifeBoardPrimaryCompact)
                    // Busy while applying, so a second tap cannot apply twice.
                    .disabled(scenario.isReadyToApply == false || store.isApplyingScenario)
                }
            }
            .foundationClayCard()
            .accessibilityIdentifier("plan.minimumViableDay.preview")
        } else {
            Button {
                store.previewMinimumViableDay()
            } label: {
                Label("Plan a lighter day", systemImage: "leaf")
                    .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
            .accessibilityHint("Shows a preview first")
            .accessibilityIdentifier("plan.minimumViableDay")
        }
    }

    private static func title(_ source: PlanningScenarioSource) -> String {
        switch source {
        case .minimumViableDay: String(localized: "Lighter day")
        case .repair: String(localized: "Repair preview")
        case .multiItemReschedule: String(localized: "Reschedule preview")
        case .manual: String(localized: "Plan preview")
        // Plan can render a day-close scenario if one is ever handed to it, but
        // it never builds one — Close the Day owns that surface.
        case .dayClose: String(localized: "Close the day")
        case .dayOpen: String(localized: "Start the day")
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
        case .minimumViableDay: String(localized: "Apply lighter day")
        case .repair: String(localized: "Apply repair")
        case .multiItemReschedule: String(localized: "Apply reschedule")
        case .manual: String(localized: "Apply changes")
        case .dayClose: String(localized: "Close the day")
        case .dayOpen: String(localized: "Start the day")
        }
    }

    private func chooser(_ snapshot: PlanDaySnapshot) -> some View {
        let readyTasks = snapshot.unscheduledTasks.filter(\.dependenciesReady)
        let selected = store.minimumViableDaySelection
        return VStack(alignment: .leading, spacing: 8) {
            Text("Pick 3 parts")
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
                    Label("Care", systemImage: "heart")
                        .frame(minHeight: 44)
                }
                .buttonStyle(.lifeBoardChip)

                Menu {
                    ForEach(readyTasks.filter { $0.id != selected.careTaskID }) { task in
                        Button(task.title) {
                            var next = selected
                            next.outcomeTaskID = task.id
                            store.previewMinimumViableDay(selection: next)
                        }
                    }
                } label: {
                    Label("Outcome", systemImage: "scope")
                        .frame(minHeight: 44)
                }
                .buttonStyle(.lifeBoardChip)
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
                Label("Rest", systemImage: "moon.zzz")
                    .frame(minHeight: 44)
            }
            .buttonStyle(.lifeBoardChip)
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
