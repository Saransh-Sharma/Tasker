//
//  FocusZone.swift
//  Tasker
//
//  Redesigned focus zone with clear visual boundary.
//  Accent-tinted background, rounded container, elevation.
//

import SwiftUI

// MARK: - Focus Zone

/// Enhanced focus zone container with visual boundary.
public struct FocusZone: View {
    let rows: [HomeTodayRow]
    let canDrag: Bool
    let pinnedTaskIDs: [UUID]
    let shellPhase: HomeShellPhase
    let insightForTaskID: (UUID) -> EvaFocusTaskInsight?
    let onShuffle: () -> Void
    let onWhy: () -> Void
    let onPinTask: (TaskDefinition) -> Void
    let onUnpinTask: (TaskDefinition) -> Void
    let onTaskTap: (TaskDefinition) -> Void
    let onToggleComplete: (TaskDefinition) -> Void
    let onStartFocus: ((TaskDefinition) -> Void)?
    let onTaskDragStarted: (TaskDefinition) -> Void
    let onCompleteHabit: (HomeHabitRow) -> Void
    let onSkipHabit: (HomeHabitRow) -> Void
    let onLapseHabit: (HomeHabitRow) -> Void
    let onDrop: ([NSItemProvider]) -> Bool

    @State private var isTargeted = false

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }
    private var corner: TaskerCornerTokens { TaskerThemeManager.shared.currentTheme.tokens.corner }
    private var prefersBudgetVisuals: Bool { shellPhase != .interactive }

    /// Initializes a new instance.
    public init(
        rows: [HomeTodayRow],
        canDrag: Bool,
        pinnedTaskIDs: [UUID] = [],
        shellPhase: HomeShellPhase = .interactive,
        insightForTaskID: @escaping (UUID) -> EvaFocusTaskInsight? = { _ in nil },
        onShuffle: @escaping () -> Void = {},
        onWhy: @escaping () -> Void = {},
        onPinTask: @escaping (TaskDefinition) -> Void = { _ in },
        onUnpinTask: @escaping (TaskDefinition) -> Void = { _ in },
        onTaskTap: @escaping (TaskDefinition) -> Void,
        onToggleComplete: @escaping (TaskDefinition) -> Void,
        onStartFocus: ((TaskDefinition) -> Void)? = nil,
        onTaskDragStarted: @escaping (TaskDefinition) -> Void,
        onCompleteHabit: @escaping (HomeHabitRow) -> Void = { _ in },
        onSkipHabit: @escaping (HomeHabitRow) -> Void = { _ in },
        onLapseHabit: @escaping (HomeHabitRow) -> Void = { _ in },
        onDrop: @escaping ([NSItemProvider]) -> Bool
    ) {
        self.rows = rows
        self.canDrag = canDrag
        self.pinnedTaskIDs = pinnedTaskIDs
        self.shellPhase = shellPhase
        self.insightForTaskID = insightForTaskID
        self.onShuffle = onShuffle
        self.onWhy = onWhy
        self.onPinTask = onPinTask
        self.onUnpinTask = onUnpinTask
        self.onTaskTap = onTaskTap
        self.onToggleComplete = onToggleComplete
        self.onStartFocus = onStartFocus
        self.onTaskDragStarted = onTaskDragStarted
        self.onCompleteHabit = onCompleteHabit
        self.onSkipHabit = onSkipHabit
        self.onLapseHabit = onLapseHabit
        self.onDrop = onDrop
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            focusHeader
                .padding(.horizontal, spacing.s12)
                .padding(.top, spacing.s8)
                .padding(.bottom, spacing.s4)

            // Content
            if rows.isEmpty {
                emptyState
                    .padding(.horizontal, spacing.s12)
                    .padding(.bottom, spacing.s12)
            } else {
                taskList
                    .padding(.horizontal, spacing.s8)
                    .padding(.bottom, spacing.s8)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: corner.r3)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.tasker.accentPrimary.opacity(0.08),
                            Color.tasker.accentPrimary.opacity(0.03)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: corner.r3)
                .stroke(
                    isTargeted
                        ? Color.tasker.accentPrimary.opacity(0.5)
                        : Color.tasker.accentPrimary.opacity(0.15),
                    lineWidth: 1
                )
        )
        .scaleEffect(prefersBudgetVisuals ? 1.0 : (isTargeted ? 1.01 : 1.0))
        .brightness(prefersBudgetVisuals ? 0 : (isTargeted ? 0.02 : 0))
        .onDrop(of: ["public.text"], isTargeted: $isTargeted, perform: onDrop)
        .animation(prefersBudgetVisuals ? .linear(duration: 0.01) : .spring(response: 0.3), value: isTargeted)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.focus.strip")
    }

    // MARK: - Header

    private var focusHeader: some View {
        HStack(spacing: spacing.s8) {
            Button(action: onWhy) {
                HStack(spacing: spacing.s8) {
                    // Flame icon with animation
                    Image(systemName: "flame.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.tasker.accentPrimary)
                        .symbolEffect(.pulse, options: .repeating.speed(0.5), isActive: !rows.isEmpty && !prefersBudgetVisuals)
                        .modifier(FocusBreathingModifier(isEnabled: !prefersBudgetVisuals, min: 0.8, max: 1.0, duration: 2.5))

                    // Title
                    Text("Focus Now")
                        .font(.tasker(.buttonSmall))
                        .fontWeight(.semibold)
                        .foregroundColor(Color.tasker.accentPrimary)

                    // Count badge
                    if !rows.isEmpty {
                        Text("· \(rows.count)")
                            .font(.tasker(.caption2))
                            .fontWeight(.medium)
                            .foregroundColor(Color.tasker.textSecondary)
                            .transition(.scale.combined(with: .opacity))
                            .contentTransition(.numericText())
                    }
                }
                .frame(minHeight: 44, alignment: .leading)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .accessibilityIdentifier("home.focus.titleTap")
            .accessibilityHint("Opens why Eva picked these items")

            Spacer(minLength: 0)

            if !rows.isEmpty {
                actionButton(title: "Shuffle", action: onShuffle, accessibilityID: "home.focus.shuffle")
            }
        }
    }

    private func actionButton(title: String, action: @escaping () -> Void, accessibilityID: String) -> some View {
        Button(action: action) {
            Text(title)
                .font(.tasker(.caption1))
                .foregroundColor(Color.tasker.accentPrimary)
                .padding(.horizontal, 8)
                .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .accessibilityIdentifier(accessibilityID)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: spacing.s4) {
            Image(systemName: "scope")
                .font(.system(size: 24, weight: .light))
                .foregroundColor(Color.tasker.accentPrimary.opacity(0.4))
                .modifier(FocusBreathingModifier(isEnabled: !prefersBudgetVisuals, min: 0.3, max: 0.5, duration: 2.0))

            Text("Add a few tasks for today and Focus Now will pick the best next moves")
                .font(.tasker(.caption1))
                .foregroundColor(Color.tasker.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 56)
    }

    // MARK: - Task List

    private var taskList: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                if index > 0 {
                    Divider()
                        .padding(.leading, spacing.s32)
                        .padding(.vertical, 2)
                        .opacity(Double(rows.count - index) / Double(rows.count))
                }

                focusRow(for: row)
                    .modifier(FocusStaggerModifier(isEnabled: !prefersBudgetVisuals, index: index))
            }
        }
        .accessibilityIdentifier("home.focusZone.taskList")
    }

    @ViewBuilder
    private func focusRow(for row: HomeTodayRow) -> some View {
        switch row {
        case .task(let task):
            FocusZoneRow(
                task: task,
                insight: insightForTaskID(task.id),
                canDrag: canDrag,
                showFocusButton: onStartFocus != nil && V2FeatureFlags.gamificationFocusSessionsEnabled,
                isPinned: pinnedTaskIDs.contains(task.id),
                onTap: { onTaskTap(task) },
                onToggleComplete: { onToggleComplete(task) },
                onPinToggle: {
                    if pinnedTaskIDs.contains(task.id) {
                        onUnpinTask(task)
                    } else {
                        onPinTask(task)
                    }
                },
                onStartFocus: { onStartFocus?(task) },
                onDragStarted: { onTaskDragStarted(task) }
            )
            .taskCompletionTransition(isComplete: task.isComplete)

        case .habit(let habit):
            HomeHabitRowView(
                row: habit,
                onPrimaryAction: {
                    switch (habit.kind, habit.trackingMode, habit.state) {
                    case (_, .lapseOnly, .tracking):
                        onLapseHabit(habit)
                    case (.positive, _, _):
                        onCompleteHabit(habit)
                    case (.negative, .dailyCheckIn, _):
                        onCompleteHabit(habit)
                    case (.negative, .lapseOnly, _):
                        onLapseHabit(habit)
                    }
                },
                onSecondaryAction: {
                    switch (habit.kind, habit.trackingMode) {
                    case (.positive, _):
                        onSkipHabit(habit)
                    case (.negative, .dailyCheckIn):
                        onLapseHabit(habit)
                    case (.negative, .lapseOnly):
                        break
                    }
                }
            )
        }
    }
}

private struct FocusBreathingModifier: ViewModifier {
    let isEnabled: Bool
    let min: Double
    let max: Double
    let duration: Double

    func body(content: Content) -> some View {
        if isEnabled {
            content.breathingPulse(min: min, max: max, duration: duration)
        } else {
            content
        }
    }
}

private struct FocusStaggerModifier: ViewModifier {
    let isEnabled: Bool
    let index: Int

    func body(content: Content) -> some View {
        if isEnabled {
            content.staggeredAppearance(index: index)
        } else {
            content
        }
    }
}

// MARK: - Focus Zone Row

enum FocusZoneStatusChip: Equatable {
    case late(String)
    case dueSoon
    case quickWin
    case unblocked

    var text: String {
        switch self {
        case .late(let value): return value
        case .dueSoon: return "Due soon"
        case .quickWin: return "Quick win"
        case .unblocked: return "Unblocked"
        }
    }
}

enum FocusZoneStatusChipResolver {
    /// Executes resolve.
    static func resolve(task: TaskDefinition, insight: EvaFocusTaskInsight?, now: Date = Date()) -> FocusZoneStatusChip? {
        guard !task.isComplete else { return nil }

        if let dueDate = task.dueDate, let lateLabel = OverdueAgeFormatter.lateLabel(dueDate: dueDate, now: now) {
            return .late(lateLabel)
        }

        if isDueSoon(task: task, now: now) {
            return .dueSoon
        }

        if isQuickWin(task: task, insight: insight) {
            return .quickWin
        }

        return task.dependencies.isEmpty ? .unblocked : nil
    }

    /// Executes isDueSoon.
    private static func isDueSoon(task: TaskDefinition, now: Date) -> Bool {
        guard let dueDate = task.dueDate, !task.isOverdue else { return false }
        let remaining = dueDate.timeIntervalSince(now)
        return remaining > 0 && remaining <= (2 * 60 * 60)
    }

    /// Executes isQuickWin.
    private static func isQuickWin(task: TaskDefinition, insight: EvaFocusTaskInsight?) -> Bool {
        let insightBadge = insight?.badge?.lowercased() ?? ""
        let insightRationale = insight?.rationale.map { $0.label.lowercased() } ?? []
        let insightMentionsQuickWin = insightBadge.contains("quick win")
            || insightRationale.contains(where: { $0.contains("quick win") })

        let taskIsQuickWin = (task.estimatedDuration ?? 0) > 0 && (task.estimatedDuration ?? 0) <= 1_800
        return insightMentionsQuickWin || taskIsQuickWin
    }
}

/// Compact row for focus zone tasks.
private struct FocusZoneRow: View {
    let task: TaskDefinition
    let insight: EvaFocusTaskInsight?
    let canDrag: Bool
    let showFocusButton: Bool
    let isPinned: Bool
    let onTap: () -> Void
    let onToggleComplete: () -> Void
    let onPinToggle: () -> Void
    let onStartFocus: () -> Void
    let onDragStarted: () -> Void

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }
    private var statusChip: FocusZoneStatusChip? {
        FocusZoneStatusChipResolver.resolve(task: task, insight: insight)
    }

    var body: some View {
        HStack(alignment: .top, spacing: spacing.s8) {
            CompletionCheckbox(isComplete: task.isComplete, compact: true) {
                onToggleComplete()
            }
            .frame(width: 24, height: 24)
            .padding(.top, 2)

            VStack(alignment: .leading, spacing: spacing.s4) {
                Text(task.title)
                    .font(.tasker(.bodyEmphasis))
                    .foregroundColor(task.isComplete ? Color.tasker.textTertiary : Color.tasker.textPrimary)
                    .lineLimit(2)

                if let secondaryLineText {
                    Text(secondaryLineText)
                        .font(.tasker(.caption2))
                        .foregroundColor(Color.tasker.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            trailingControls
        }
        .padding(.vertical, 8)
        .padding(.horizontal, spacing.s4)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button {
                onToggleComplete()
            } label: {
                Label(task.isComplete ? "Reopen" : "Complete", systemImage: task.isComplete ? "arrow.uturn.backward" : "checkmark")
            }
            .tint(task.isComplete ? Color.tasker.accentSecondary : Color.tasker.statusSuccess)
        }
        .ifLet(canDrag ? task : nil) { view, _ in
            view.onDrag {
                onDragStarted()
                return NSItemProvider(object: task.id.uuidString as NSString)
            }
        }
        .accessibilityIdentifier("home.focus.task.\(task.id.uuidString)")
        .accessibilityLabel(task.title)
    }

    private var trailingControls: some View {
        VStack(alignment: .trailing, spacing: spacing.s8) {
            if let statusChip {
                statusChipBadge(statusChip)
            }

            HStack(spacing: spacing.s8) {
                pinButton

                if showFocusButton && !task.isComplete {
                    startFocusButton
                }
            }
        }
    }

    private func statusChipBadge(_ statusChip: FocusZoneStatusChip) -> some View {
        Text(statusChip.text)
            .font(.tasker(.caption2))
            .fontWeight(.medium)
            .foregroundColor(focusStatusColor(for: statusChip))
            .padding(.horizontal, 5)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(focusStatusColor(for: statusChip).opacity(0.15))
            )
            .fixedSize()
            .transition(.scale.combined(with: .opacity))
            .animation(TaskerAnimation.gentle, value: statusChip)
    }

    private var pinButton: some View {
        Button(action: onPinToggle) {
            Image(systemName: isPinned ? "pin.fill" : "pin")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(isPinned ? Color.tasker.accentPrimary : Color.tasker.textSecondary)
                .frame(width: 28, height: 28)
                .background(Color.tasker.surfaceSecondary.opacity(0.8))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("home.focus.pin.\(task.id.uuidString)")
        .accessibilityLabel(isPinned ? "Unpin from Focus Now" : "Pin to Focus Now")
    }

    private var startFocusButton: some View {
        Button(action: onStartFocus) {
            Image(systemName: "timer")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color.tasker.accentPrimary)
                .frame(width: 28, height: 28)
                .background(Color.tasker.accentPrimary.opacity(0.1))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Start focus session")
    }

    private var secondaryLineText: String? {
        if let dueDate = task.dueDate, let lateLabel = OverdueAgeFormatter.lateLabel(dueDate: dueDate, now: Date()) {
            return "Overdue · \(lateLabel)"
        }
        if let dueDate = task.dueDate, Calendar.current.isDateInToday(dueDate) {
            let time = dueDate.formatted(date: .omitted, time: .shortened)
            if let projectName = task.projectName?.trimmingCharacters(in: .whitespacesAndNewlines), !projectName.isEmpty {
                return "Due today · \(time) · \(projectName)"
            }
            return "Due today · \(time)"
        }
        if task.projectID == ProjectConstants.inboxProjectID {
            return "Inbox · promoted for today"
        }
        if let projectName = task.projectName?.trimmingCharacters(in: .whitespacesAndNewlines), !projectName.isEmpty {
            return "Project · \(projectName)"
        }
        return nil
    }

    /// Executes focusStatusColor.
    private func focusStatusColor(for statusChip: FocusZoneStatusChip) -> Color {
        switch statusChip {
        case .late:
            return Color.tasker.statusDanger
        case .dueSoon:
            return Color.tasker.statusWarning
        case .quickWin:
            return Color.tasker.statusSuccess
        case .unblocked:
            return Color.tasker.statusSuccess
        }
    }
}

// MARK: - View Extension

extension View {
    @ViewBuilder
    func ifLet<T, Content: View>(_ value: T?, @ViewBuilder transform: (Self, T) -> Content) -> some View {
        if let value {
            transform(self, value)
        } else {
            self
        }
    }
}

// MARK: - Preview

#if DEBUG
struct FocusZone_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Empty state
            FocusZone(
                rows: [],
                canDrag: true,
                onTaskTap: { _ in },
                onToggleComplete: { _ in },
                onTaskDragStarted: { _ in },
                onDrop: { _ in false }
            )

            // With tasks
            FocusZone(
                rows: [
                    .task(TaskDefinition(title: "Review pull requests", priority: .high, dueDate: Date())),
                    .task(TaskDefinition(title: "Design landing page", priority: .low, dueDate: Date().addingTimeInterval(7200)))
                ],
                canDrag: true,
                onTaskTap: { _ in },
                onToggleComplete: { _ in },
                onTaskDragStarted: { _ in },
                onDrop: { _ in false }
            )
        }
        .padding()
        .background(Color.tasker.bgCanvas)
        .previewLayout(.sizeThatFits)
    }
}
#endif
