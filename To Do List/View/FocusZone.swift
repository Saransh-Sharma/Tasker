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
    let tasks: [TaskDefinition]
    let canDrag: Bool
    let insightForTaskID: (UUID) -> EvaFocusTaskInsight?
    let onShuffle: () -> Void
    let onWhy: () -> Void
    let onTaskTap: (TaskDefinition) -> Void
    let onToggleComplete: (TaskDefinition) -> Void
    let onTaskDragStarted: (TaskDefinition) -> Void
    let onDrop: ([NSItemProvider]) -> Bool

    @State private var isTargeted = false

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }
    private var corner: TaskerCornerTokens { TaskerThemeManager.shared.currentTheme.tokens.corner }

    /// Initializes a new instance.
    public init(
        tasks: [TaskDefinition],
        canDrag: Bool,
        insightForTaskID: @escaping (UUID) -> EvaFocusTaskInsight? = { _ in nil },
        onShuffle: @escaping () -> Void = {},
        onWhy: @escaping () -> Void = {},
        onTaskTap: @escaping (TaskDefinition) -> Void,
        onToggleComplete: @escaping (TaskDefinition) -> Void,
        onTaskDragStarted: @escaping (TaskDefinition) -> Void,
        onDrop: @escaping ([NSItemProvider]) -> Bool
    ) {
        self.tasks = tasks
        self.canDrag = canDrag
        self.insightForTaskID = insightForTaskID
        self.onShuffle = onShuffle
        self.onWhy = onWhy
        self.onTaskTap = onTaskTap
        self.onToggleComplete = onToggleComplete
        self.onTaskDragStarted = onTaskDragStarted
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
            if tasks.isEmpty {
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
        .shadow(
            color: Color.tasker.accentPrimary.opacity(0.06),
            radius: 3,
            x: 0,
            y: 1
        )
        .shadow(
            color: Color.tasker.accentPrimary.opacity(0.12),
            radius: isTargeted ? 16 : 12,
            x: 0,
            y: 2
        )
        .scaleEffect(isTargeted ? 1.01 : 1.0)
        .brightness(isTargeted ? 0.02 : 0)
        .onDrop(of: ["public.text"], isTargeted: $isTargeted, perform: onDrop)
        .animation(.spring(response: 0.3), value: isTargeted)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.focus.dropzone")
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
                        .symbolEffect(.pulse, options: .repeating.speed(0.5), isActive: !tasks.isEmpty)
                        .breathingPulse(min: 0.8, max: 1.0, duration: 2.5)

                    // Title
                    Text("FOCUS NOW")
                        .font(.tasker(.buttonSmall))
                        .fontWeight(.semibold)
                        .tracking(0.8)
                        .foregroundColor(Color.tasker.accentPrimary)

                    // Count badge
                    if !tasks.isEmpty {
                        Text("\(tasks.count)")
                            .font(.tasker(.caption2))
                            .fontWeight(.medium)
                            .foregroundColor(Color.tasker.accentPrimary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Color.tasker.accentMuted)
                            )
                            .transition(.scale.combined(with: .opacity))
                            .contentTransition(.numericText())
                    }
                }
                .frame(minHeight: 44, alignment: .leading)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .accessibilityIdentifier("home.focus.titleTap")
            .accessibilityHint("Opens why Eva picked these tasks")

            Spacer(minLength: 0)

            if !tasks.isEmpty {
                actionButton(title: "Shuffle", action: onShuffle, accessibilityID: "home.focus.shuffle")
            } else if canDrag {
                Text("Drag tasks here")
                    .font(.tasker(.caption2))
                    .foregroundColor(Color.tasker.textTertiary)
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
            Image(systemName: "hand.point.up.left")
                .font(.system(size: 24, weight: .light))
                .foregroundColor(Color.tasker.accentPrimary.opacity(0.4))
                .breathingPulse(min: 0.3, max: 0.5, duration: 2.0)

            Text("Long-press a task to pin here")
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
            ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                if index > 0 {
                    Divider()
                        .padding(.leading, spacing.s32)
                        .padding(.vertical, 2)
                        .opacity(Double(tasks.count - index) / Double(tasks.count))
                }

                FocusZoneRow(
                    task: task,
                    insight: insightForTaskID(task.id),
                    canDrag: canDrag,
                    onTap: { onTaskTap(task) },
                    onToggleComplete: { onToggleComplete(task) },
                    onDragStarted: { onTaskDragStarted(task) }
                )
                .taskCompletionTransition(isComplete: task.isComplete)
                .staggeredAppearance(index: index)
            }
        }
        .accessibilityIdentifier("home.focusZone.taskList")
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
    let onTap: () -> Void
    let onToggleComplete: () -> Void
    let onDragStarted: () -> Void

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }
    private var statusChip: FocusZoneStatusChip? {
        FocusZoneStatusChipResolver.resolve(task: task, insight: insight)
    }

    var body: some View {
        HStack(spacing: spacing.s8) {
            CompletionCheckbox(isComplete: task.isComplete, compact: true) {
                onToggleComplete()
            }
            .frame(width: 24, height: 24)

            Text(task.title)
                .font(.tasker(.bodyEmphasis))
                .foregroundColor(task.isComplete ? Color.tasker.textTertiary : Color.tasker.textPrimary)
                .lineLimit(1)

            Spacer(minLength: 0)

            if let statusChip {
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
                    .animation(TaskerAnimation.bouncy, value: statusChip)
            }

        }
        .padding(.vertical, 6)
        .padding(.horizontal, spacing.s4)
        .frame(height: 36)
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
                tasks: [],
                canDrag: true,
                onTaskTap: { _ in },
                onToggleComplete: { _ in },
                onTaskDragStarted: { _ in },
                onDrop: { _ in false }
            )

            // With tasks
            FocusZone(
                tasks: [
                    TaskDefinition(title: "Review pull requests", priority: .high, dueDate: Date()),
                    TaskDefinition(title: "Design landing page", priority: .low, dueDate: Date().addingTimeInterval(7200))
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
