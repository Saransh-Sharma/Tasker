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
    let tasks: [DomainTask]
    let canDrag: Bool
    let onTaskTap: (DomainTask) -> Void
    let onToggleComplete: (DomainTask) -> Void
    let onTaskDragStarted: (DomainTask) -> Void
    let onDrop: ([NSItemProvider]) -> Bool

    @State private var isTargeted = false

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }
    private var corner: TaskerCornerTokens { TaskerThemeManager.shared.currentTheme.tokens.corner }
    private var themeColors: TaskerColorTokens { TaskerThemeManager.shared.currentTheme.tokens.color }

    public init(
        tasks: [DomainTask],
        canDrag: Bool,
        onTaskTap: @escaping (DomainTask) -> Void,
        onToggleComplete: @escaping (DomainTask) -> Void,
        onTaskDragStarted: @escaping (DomainTask) -> Void,
        onDrop: @escaping ([NSItemProvider]) -> Bool
    ) {
        self.tasks = tasks
        self.canDrag = canDrag
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
                .fill(Color.tasker.accentPrimary.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: corner.r3)
                .stroke(
                    isTargeted
                        ? Color.tasker.accentPrimary.opacity(0.5)
                        : Color.tasker.accentPrimary.opacity(0.15),
                    lineWidth: isTargeted ? 2 : 1
                )
        )
        .shadow(
            color: Color.tasker.accentPrimary.opacity(0.08),
            radius: 8,
            x: 0,
            y: 2
        )
        .onDrop(of: ["public.text"], isTargeted: $isTargeted, perform: onDrop)
        .animation(.spring(response: 0.3), value: isTargeted)
        .accessibilityIdentifier("home.focusZone")
    }

    // MARK: - Header

    private var focusHeader: some View {
        HStack(spacing: spacing.s8) {
            // Flame icon with animation
            Image(systemName: "flame.fill")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color.tasker.accentSecondary)
                .symbolEffect(.pulse, options: .repeating.speed(0.5), isActive: !tasks.isEmpty)

            // Title
            Text("FOCUS NOW")
                .font(.tasker(.caption1))
                .fontWeight(.semibold)
                .foregroundColor(Color.tasker.accentSecondary)

            // Count badge
            if !tasks.isEmpty {
                Text("\(tasks.count)")
                    .font(.tasker(.caption2))
                    .fontWeight(.medium)
                    .foregroundColor(Color.tasker.accentOnPrimary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(Color.tasker.accentSecondary)
                    )
            }

            Spacer()

            // Empty state hint
            if tasks.isEmpty && canDrag {
                Text("Drag tasks here")
                    .font(.tasker(.caption2))
                    .foregroundColor(Color.tasker.textQuaternary)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: spacing.s4) {
            Image(systemName: "hand.point.up.left")
                .font(.system(size: 24, weight: .light))
                .foregroundColor(Color.tasker.accentPrimary.opacity(0.4))

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
                        .padding(.leading, 32)
                        .padding(.vertical, 2)
                }

                FocusZoneRow(
                    task: task,
                    canDrag: canDrag,
                    onTap: { onTaskTap(task) },
                    onToggleComplete: { onToggleComplete(task) },
                    onDragStarted: { onTaskDragStarted(task) }
                )
                .staggeredAppearance(index: index)
            }
        }
        .accessibilityIdentifier("home.focusZone.taskList")
    }
}

// MARK: - Focus Zone Row

/// Compact row for focus zone tasks.
private struct FocusZoneRow: View {
    let task: DomainTask
    let canDrag: Bool
    let onTap: () -> Void
    let onToggleComplete: () -> Void
    let onDragStarted: () -> Void

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }
    private var displayModel: TaskRowDisplayModel { TaskRowDisplayModel.from(task: task, showTypeBadge: false) }

    var body: some View {
        HStack(spacing: spacing.s8) {
            CompletionCheckbox(isComplete: task.isComplete, compact: true) {
                onToggleComplete()
            }
            .frame(width: 24, height: 24)

            Text(task.name)
                .font(.tasker(.body))
                .foregroundColor(task.isComplete ? Color.tasker.textTertiary : Color.tasker.textPrimary)
                .lineLimit(1)

            Spacer(minLength: 0)

            // Urgency indicator
            if !task.isComplete {
                UrgencyBadge(level: UrgencyLevel.from(task: task), isCompact: true)
            }

            // XP badge
            XPBadge(xpValue: displayModel.xpValue, priority: task.priority, isCompact: true, showLabel: false)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, spacing.s4)
        .frame(height: 36)
        .contentShape(Rectangle())
        .opacity(task.isComplete ? 0.5 : 1.0)
        .onTapGesture { onTap() }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
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
                    DomainTask(name: "Review pull requests", priority: .high, dueDate: Date()),
                    DomainTask(name: "Design landing page", priority: .low, dueDate: Date().addingTimeInterval(7200))
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
