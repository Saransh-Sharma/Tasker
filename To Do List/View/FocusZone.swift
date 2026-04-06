//
//  FocusZone.swift
//  Tasker
//
//  Compact, low-noise Focus Now surface for the Home screen.
//

import SwiftUI

// MARK: - Focus Zone

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
            focusHeader
                .padding(.horizontal, spacing.s12)
                .padding(.top, spacing.s8)
                .padding(.bottom, spacing.s2)

            if rows.isEmpty {
                emptyState
                    .padding(.horizontal, spacing.s12)
                    .padding(.bottom, spacing.s8)
            } else {
                taskList
                    .padding(.horizontal, spacing.s8)
                    .padding(.bottom, spacing.s8)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: corner.r2, style: .continuous)
                .fill(Color.tasker.surfacePrimary.opacity(0.96))
        )
        .overlay(
            RoundedRectangle(cornerRadius: corner.r2, style: .continuous)
                .stroke(
                    isTargeted
                        ? Color.tasker.accentPrimary.opacity(0.30)
                        : Color.tasker.strokeHairline.opacity(0.92),
                    lineWidth: 1
                )
        )
        .overlay(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 999, style: .continuous)
                .fill(Color.tasker.accentPrimary.opacity(rows.isEmpty ? 0.18 : 0.34))
                .frame(width: 44, height: 3)
                .padding(.horizontal, spacing.s12)
                .padding(.top, 1)
        }
        .scaleEffect(prefersBudgetVisuals ? 1.0 : (isTargeted ? 1.005 : 1.0))
        .brightness(prefersBudgetVisuals ? 0 : (isTargeted ? 0.01 : 0))
        .onDrop(of: ["public.text"], isTargeted: $isTargeted, perform: onDrop)
        .animation(prefersBudgetVisuals ? .linear(duration: 0.01) : .spring(response: 0.26, dampingFraction: 0.88), value: isTargeted)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.focus.strip")
    }

    private var focusHeader: some View {
        HStack(spacing: spacing.s8) {
            Button(action: onWhy) {
                HStack(spacing: spacing.s4) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color.tasker.accentPrimary.opacity(rows.isEmpty ? 0.65 : 0.92))

                    Text(LocalizedStringKey("Focus Now"))
                        .font(.tasker(.callout).weight(.semibold))
                        .foregroundColor(Color.tasker.textPrimary)

                    if !rows.isEmpty {
                        Text("\(rows.count)")
                            .font(.tasker(.caption2).weight(.semibold))
                            .foregroundColor(Color.tasker.textSecondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Color.tasker.surfaceSecondary)
                            )
                            .contentTransition(.numericText())
                    }
                }
                .frame(minHeight: 36, alignment: .leading)
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
                .font(.tasker(.caption1).weight(.medium))
                .foregroundColor(Color.tasker.accentPrimary)
                .padding(.horizontal, 4)
                .frame(minHeight: 36)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .accessibilityIdentifier(accessibilityID)
    }

    private var emptyState: some View {
        VStack(spacing: spacing.s4) {
            Image(systemName: "scope")
                .font(.system(size: 20, weight: .regular))
                .foregroundColor(Color.tasker.accentPrimary.opacity(0.42))

            Text(LocalizedStringKey("Add a few tasks for today and Focus Now will pick the best next moves"))
                .font(.tasker(.caption1))
                .foregroundColor(Color.tasker.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 52)
    }

    private var taskList: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                if index > 0 {
                    Divider()
                        .padding(.leading, 32)
                        .padding(.vertical, 1)
                        .opacity(0.72)
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
                isPinned: pinnedTaskIDs.contains(task.id),
                showStartFocusAction: onStartFocus != nil && V2FeatureFlags.gamificationFocusSessionsEnabled,
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

enum FocusZoneBadgeTone: Equatable {
    case danger
    case warning
    case success

    @MainActor
    var foregroundColor: Color {
        switch self {
        case .danger:
            return Color.tasker.statusDanger
        case .warning:
            return Color.tasker.statusWarning
        case .success:
            return Color.tasker.statusSuccess
        }
    }
}

struct FocusZoneBadgePresentation: Equatable {
    let text: String
    let tone: FocusZoneBadgeTone
}

struct FocusZoneRowPresentation: Equatable {
    let title: String
    let secondaryLineText: String?
    let visibleBadge: FocusZoneBadgePresentation?
    let priorityCode: String?

    static func make(task: TaskDefinition, insight: EvaFocusTaskInsight?, now: Date = Date()) -> FocusZoneRowPresentation {
        _ = insight
        let timePressure = FocusZoneTimePressureResolver.resolve(task: task, now: now)
        let metadata = FocusZoneSecondaryLineResolver.resolve(task: task)

        return FocusZoneRowPresentation(
            title: task.title,
            secondaryLineText: metadata.text,
            visibleBadge: timePressure,
            priorityCode: metadata.priorityCode
        )
    }
}

enum FocusZoneTimePressureResolver {
    static func resolve(task: TaskDefinition, now: Date = Date()) -> FocusZoneBadgePresentation? {
        guard !task.isComplete else { return nil }

        if let dueDate = task.dueDate, let lateLabel = OverdueAgeFormatter.lateLabel(dueDate: dueDate, now: now) {
            return FocusZoneBadgePresentation(text: lateLabel, tone: .danger)
        }

        if isDueSoon(task: task, now: now) {
            return FocusZoneBadgePresentation(text: "Due soon", tone: .warning)
        }

        guard let dueDate = task.dueDate, Calendar.current.isDateInToday(dueDate) else {
            return nil
        }

        return FocusZoneBadgePresentation(
            text: "Due \(dueDate.formatted(date: .omitted, time: .shortened))",
            tone: .warning
        )
    }

    private static func isDueSoon(task: TaskDefinition, now: Date) -> Bool {
        guard let dueDate = task.dueDate, dueDate > now else { return false }
        let remaining = dueDate.timeIntervalSince(now)
        return remaining > 0 && remaining <= (2 * 60 * 60)
    }
}

struct FocusZoneSecondaryLine: Equatable {
    let text: String?
    let priorityCode: String?
}

enum FocusZoneSecondaryLineResolver {
    static func resolve(task: TaskDefinition) -> FocusZoneSecondaryLine {
        let priorityCode = task.priority == .none ? nil : task.priority.code

        if task.projectID == ProjectConstants.inboxProjectID {
            return FocusZoneSecondaryLine(text: "Inbox", priorityCode: priorityCode)
        }

        let projectName = task.projectName?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let projectName, !projectName.isEmpty {
            return FocusZoneSecondaryLine(text: projectName, priorityCode: priorityCode)
        }

        return FocusZoneSecondaryLine(text: nil, priorityCode: priorityCode)
    }
}

private struct FocusZoneRow: View {
    let task: TaskDefinition
    let insight: EvaFocusTaskInsight?
    let canDrag: Bool
    let isPinned: Bool
    let showStartFocusAction: Bool
    let onTap: () -> Void
    let onToggleComplete: () -> Void
    let onPinToggle: () -> Void
    let onStartFocus: () -> Void
    let onDragStarted: () -> Void

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }
    private var presentation: FocusZoneRowPresentation {
        FocusZoneRowPresentation.make(task: task, insight: insight)
    }

    var body: some View {
        HStack(alignment: .top, spacing: spacing.s8) {
            CompletionCheckbox(isComplete: task.isComplete, compact: true) {
                onToggleComplete()
            }
            .frame(width: 24, height: 24)
            .padding(.top, 2)

            Button(action: onTap) {
                VStack(alignment: .leading, spacing: spacing.s2) {
                    Text(presentation.title)
                        .font(.tasker(.callout).weight(.semibold))
                        .foregroundColor(task.isComplete ? Color.tasker.textSecondary : Color.tasker.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: spacing.s4) {
                        if let priorityCode = presentation.priorityCode {
                            Text(priorityCode)
                                .font(.tasker(.caption1).weight(.semibold))
                                .foregroundColor(priorityColor)
                        }

                        if let secondaryLineText = presentation.secondaryLineText {
                            if presentation.priorityCode != nil {
                                Text("·")
                                    .font(.tasker(.caption1))
                                    .foregroundColor(Color.tasker.textSecondary.opacity(0.8))
                            }

                            Text(secondaryLineText)
                                .font(.tasker(.caption1))
                                .foregroundColor(Color.tasker.textSecondary)
                                .lineLimit(1)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .accessibilityIdentifier("home.focus.task.\(task.id.uuidString)")
            .accessibilityLabel(task.title)

            if let visibleBadge = presentation.visibleBadge {
                statusChipBadge(visibleBadge)
                    .frame(minWidth: 68, alignment: .trailing)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, spacing.s4)
        .contentShape(Rectangle())
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button {
                onToggleComplete()
            } label: {
                Label(task.isComplete ? "Reopen" : "Complete", systemImage: task.isComplete ? "arrow.uturn.backward" : "checkmark")
            }
            .tint(task.isComplete ? Color.tasker.accentSecondary : Color.tasker.statusSuccess)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if showStartFocusAction && !task.isComplete {
                Button {
                    onStartFocus()
                } label: {
                    Label("Start focus session", systemImage: "timer")
                }
                .tint(Color.tasker.accentPrimary)
            }

            Button {
                onPinToggle()
            } label: {
                Label(isPinned ? "Remove from Focus Now" : "Keep in Focus Now", systemImage: isPinned ? "pin.slash" : "pin")
            }
            .tint(isPinned ? Color.tasker.textSecondary : Color.tasker.accentPrimary)
        }
        .contextMenu {
            Button {
                onPinToggle()
            } label: {
                Label(isPinned ? "Remove from Focus Now" : "Keep in Focus Now", systemImage: isPinned ? "pin.slash" : "pin")
            }

            if showStartFocusAction && !task.isComplete {
                Button {
                    onStartFocus()
                } label: {
                    Label("Start focus session", systemImage: "timer")
                }
            }
        }
        .ifLet(canDrag ? task : nil) { view, _ in
            view.onDrag {
                onDragStarted()
                return NSItemProvider(object: task.id.uuidString as NSString)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func statusChipBadge(_ badge: FocusZoneBadgePresentation) -> some View {
        Text(badge.text)
            .font(.tasker(.caption2).weight(.semibold))
            .foregroundColor(badge.tone.foregroundColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(badge.tone.foregroundColor.opacity(0.12))
            )
            .fixedSize()
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }

    private var priorityColor: Color {
        switch task.priority {
        case .max:
            return Color.tasker.statusDanger
        case .high:
            return Color.tasker.statusWarning
        case .low:
            return Color.tasker.accentPrimary
        case .none:
            return Color.tasker.textSecondary
        }
    }
}

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

#if DEBUG
struct FocusZone_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            FocusZone(
                rows: [],
                canDrag: true,
                onTaskTap: { _ in },
                onToggleComplete: { _ in },
                onTaskDragStarted: { _ in },
                onDrop: { _ in false }
            )

            FocusZone(
                rows: [
                    .task(TaskDefinition(title: "Review pull requests", priority: .high, dueDate: Date(), estimatedDuration: 900)),
                    .task(TaskDefinition(projectName: "Website", title: "Design landing page", priority: .low, dueDate: Date().addingTimeInterval(7_200)))
                ],
                canDrag: true,
                pinnedTaskIDs: [],
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
