import SwiftUI

/// The live agenda and gallery use this exact content; mutations belong to the adapter.
struct HomeTasksCardContent<DateControls: View>: View {
    let tasks: [PlanningTaskSummary]
    let title: String
    let emptyMessage: String
    let isLoading: Bool
    let hasPlanningRepository: Bool
    let collapsedLimit: Int
    let isExpanded: Bool
    let allowsCompletion: Bool
    let completedTask: PlanningTaskSummary?
    let refreshFailure: String?
    let palette: DaypartPalette
    let dateControls: DateControls
    var taskWidgetAnimation: Animation? = nil
    var onComplete: (PlanningTaskSummary) -> Void = { _ in }
    var onOpen: (PlanningTaskSummary) -> Void = { _ in }
    var onAdd: () -> Void = {}
    var onUndo: () -> Void = {}
    var onRetry: () -> Void = {}
    var onToggleExpansion: () -> Void = {}

    var body: some View {
        let visibleTasks = isExpanded ? tasks : Array(tasks.prefix(collapsedLimit))
        let hasHiddenTasks = tasks.count > collapsedLimit
        VStack(alignment: .leading, spacing: 12) {
            header(isExpanded: isExpanded)
            if hasPlanningRepository == false {
                HomeEmptyStateRow("Tasks are unavailable right now", symbol: "exclamationmark.triangle", palette: palette)
            } else if isLoading {
                HomeEmptyStateRow("Loading tasks", symbol: "hourglass", palette: palette)
            } else if tasks.isEmpty {
                HomeEmptyStateRow(emptyMessage, symbol: "checkmark.circle", palette: palette)
            } else {
                ForEach(visibleTasks) { task in
                    row(task)
                }
            }
            if let message = refreshFailure {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your change was saved. \(message)")
                        .font(.caption)
                        .foregroundStyle(palette.color(for: .foregroundSecondary))
                    Button("Refresh tasks") {
                        onRetry()
                    }
                    .accessibilityIdentifier("foundation.home.tasks.retryRefresh")
                }
            }
            // A completion is a real mutation, so it gets a receipt here rather
            // than relying on Plan's Undo, which reads a different PlanStore
            // instance and can never see a completion made from Home.
            if let completed = completedTask {
                HStack(spacing: 8) {
                    Text("Completed “\(completed.title)”")
                        .font(.caption)
                        .foregroundStyle(palette.color(for: .foregroundSecondary))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Button("Undo") {
                        onUndo()
                    }
                    .font(.subheadline.weight(.semibold))
                    .frame(minHeight: 44)
                    .accessibilityHint("Reopens \(completed.title)")
                    .accessibilityIdentifier("home.tasks.undoCompletion")
                }
                .buttonStyle(.plain)
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    addButton
                    Spacer(minLength: 8)
                    if isExpanded || hasHiddenTasks {
                        expansionButton(isExpanded: isExpanded)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    addButton
                    if isExpanded || hasHiddenTasks {
                        expansionButton(isExpanded: isExpanded)
                    }
                }
            }
        }
        .padding(16)
        .animation(taskWidgetAnimation, value: isExpanded)
        .animation(taskWidgetAnimation, value: visibleTasks.map(\.id))
    }

    @ViewBuilder
    private func header(isExpanded: Bool) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                titleLabel
                if isExpanded {
                    dateControls
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                titleLabel
                if isExpanded {
                    dateControls
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.widget.tasks")
    }

    private var titleLabel: some View {
        HStack(spacing: 9) {
            Image(systemName: "checklist")
                .foregroundStyle(palette.color(for: .foregroundSecondary))
            Text(title)
                .lifeboardFont(.headline)
                .fixedSize(horizontal: false, vertical: true)
                .homeCardEvidence("tasks.title", role: "title", copy: title, typography: .init(role: "headline", points: 17, weight: "semibold"))
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private func row(_ task: PlanningTaskSummary) -> some View {
        // The completion control is a sibling of the navigating button, never
        // nested inside it: a Button within a Button gives its tap to the outer
        // one and would silently open detail instead of completing the task.
        HStack(spacing: 11) {
            if allowsCompletion {
                CompletionControl(
                    isComplete: false,
                    title: task.title
                ) { _ in
                    onComplete(task)
                }
                .homeCardEvidence("tasks.complete.\(task.id.uuidString)", role: "control")
                .padding(.leading, -11)
            } else {
                Image(systemName: task.metadata.commitmentLevel == .mustDo ? "exclamationmark.circle.fill" : "circle")
                    .foregroundStyle(palette.color(for: .foregroundSecondary))
            }
            Button {
                onOpen(task)
            } label: {
                HStack(spacing: 11) {
                    if task.metadata.commitmentLevel == .mustDo {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(palette.color(for: .foregroundSecondary))
                            .accessibilityLabel("Must do")
                    }
                    Text(task.title)
                        .font(.subheadline.weight(.medium))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .homeCardEvidence("tasks.text.\(task.id.uuidString)", role: "text", copy: task.title, typography: .init(role: "subheadline", points: 15, weight: "medium"))
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(palette.color(for: .foregroundSecondary))
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .lifeBoardTransitionSource("route.task.\(task.id.uuidString)")
            .accessibilityIdentifier("home.task.\(task.id.uuidString)")
            .homeCardEvidence("tasks.open.\(task.id.uuidString)", role: "control")
        }
        .frame(maxWidth: .infinity, minHeight: 44)
        .homeCardEvidence("tasks.row.\(task.id.uuidString)", role: "row")
    }

    private var addButton: some View {
        Button {
            onAdd()
        } label: {
            Label("Add a task", systemImage: "plus")
                .font(.subheadline.weight(.semibold))
                .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("home.tasks.add")
        .homeCardEvidence("tasks.add", role: "control", copy: "Add a task", typography: .init(role: "subheadline", points: 15, weight: "semibold"))
    }

    private func expansionButton(isExpanded: Bool) -> some View {
        Button {
            onToggleExpansion()
        } label: {
            Label(isExpanded ? "Show less" : "Show more", systemImage: isExpanded ? "chevron.up" : "chevron.down")
                .font(.subheadline.weight(.semibold))
                .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(isExpanded ? "home.tasks.showLess" : "home.tasks.showMore")
        .homeCardEvidence("tasks.expansion", role: "control", copy: isExpanded ? "Show less" : "Show more", typography: .init(role: "subheadline", points: 15, weight: "semibold"))
        .accessibilityHint(isExpanded ? "Collapses the task card and returns to today" : "Shows every overdue task and task due today")
    }

}
