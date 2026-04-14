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
    let maxVisibleRows: Int?
    let canDrag: Bool
    let pinnedTaskIDs: [UUID]
    let shellPhase: HomeShellPhase
    let insightForTaskID: (UUID) -> EvaFocusTaskInsight?
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
    let onOpenHabit: (HomeHabitRow) -> Void
    let onDrop: ([NSItemProvider]) -> Bool

    @State private var isTargeted = false

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }
    private var corner: TaskerCornerTokens { TaskerThemeManager.shared.currentTheme.tokens.corner }
    private var prefersBudgetVisuals: Bool { shellPhase != .interactive }
    private var taskRows: [TaskDefinition] {
        rows.compactMap { row in
            guard case .task(let task) = row else { return nil }
            return task
        }
    }
    private var displayedRows: [HomeTodayRow] {
        guard let maxVisibleRows else { return rows }
        return Array(rows.prefix(maxVisibleRows))
    }
    private var hasTaskRows: Bool { !taskRows.isEmpty }

    public init(
        rows: [HomeTodayRow],
        maxVisibleRows: Int? = nil,
        canDrag: Bool,
        pinnedTaskIDs: [UUID] = [],
        shellPhase: HomeShellPhase = .interactive,
        insightForTaskID: @escaping (UUID) -> EvaFocusTaskInsight? = { _ in nil },
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
        onOpenHabit: @escaping (HomeHabitRow) -> Void = { _ in },
        onDrop: @escaping ([NSItemProvider]) -> Bool
    ) {
        self.rows = rows
        self.maxVisibleRows = maxVisibleRows
        self.canDrag = canDrag
        self.pinnedTaskIDs = pinnedTaskIDs
        self.shellPhase = shellPhase
        self.insightForTaskID = insightForTaskID
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
        self.onOpenHabit = onOpenHabit
        self.onDrop = onDrop
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            focusHeader
                .padding(.horizontal, spacing.s12)
                .padding(.top, spacing.s8)
                .padding(.bottom, spacing.s2)

            if displayedRows.isEmpty {
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
            if hasTaskRows {
                Button(action: onWhy) {
                    focusHeaderLabel
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                .accessibilityLabel("Focus Now")
                .accessibilityIdentifier("home.focus.titleTap")
                .accessibilityHint("Opens Focus Now details")
            } else {
                focusHeaderLabel
            }

            Spacer(minLength: 0)
        }
    }

    private var focusHeaderLabel: some View {
        HStack(spacing: spacing.s4) {
            Image(systemName: "flame.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color.tasker.accentPrimary.opacity(hasTaskRows ? 0.92 : 0.65))

            Text(LocalizedStringKey("Focus Now"))
                .font(.tasker(.callout).weight(.semibold))
                .foregroundColor(Color.tasker.textPrimary)
        }
        .frame(minHeight: 36, alignment: .leading)
    }

    private var emptyState: some View {
        VStack(spacing: spacing.s4) {
            Image(systemName: "scope")
                .font(.system(size: 20, weight: .regular))
                .foregroundColor(Color.tasker.accentPrimary.opacity(0.42))

            Text(LocalizedStringKey("Add tasks for today to see your next 3."))
                .font(.tasker(.caption1))
                .foregroundColor(Color.tasker.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 52)
    }

    private var taskList: some View {
        VStack(spacing: 0) {
            ForEach(Array(displayedRows.enumerated()), id: \.element.id) { index, row in
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
    }

    @ViewBuilder
    private func focusRow(for row: HomeTodayRow) -> some View {
        switch row {
        case .task(let task):
            FocusZoneRow(
                task: task,
                insight: insightForTaskID(task.id),
                canDrag: canDrag,
                showStartFocusAction: onStartFocus != nil && V2FeatureFlags.gamificationFocusSessionsEnabled,
                onTap: { onTaskTap(task) },
                onToggleComplete: { onToggleComplete(task) },
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
                },
                onOpenDetail: {
                    onOpenHabit(habit)
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

struct FocusZoneSecondarySegment: Equatable {
    enum Kind: Equatable {
        case urgency(FocusZoneBadgeTone)
        case metadata
    }

    let text: String
    let kind: Kind
}

struct FocusZoneRowPresentation: Equatable {
    let title: String
    let secondarySegments: [FocusZoneSecondarySegment]

    var secondaryLineText: String? {
        guard secondarySegments.isEmpty == false else { return nil }
        return secondarySegments.map(\.text).joined(separator: " · ")
    }

    static func make(task: TaskDefinition, insight: EvaFocusTaskInsight?, now: Date = Date()) -> FocusZoneRowPresentation {
        _ = insight
        let timePressure = FocusZoneTimePressureResolver.resolve(
            task: task,
            now: now,
            showDueTodayTime: false
        )
        let metadata = FocusZoneSecondaryLineResolver.resolve(
            task: task,
            showInboxProjectName: false
        )
        var secondarySegments: [FocusZoneSecondarySegment] = []

        if let timePressure {
            secondarySegments.append(
                FocusZoneSecondarySegment(
                    text: timePressure.text,
                    kind: .urgency(timePressure.tone)
                )
            )
        }

        if let metadataText = metadata.text, metadataText.isEmpty == false {
            secondarySegments.append(
                FocusZoneSecondarySegment(
                    text: metadataText,
                    kind: .metadata
                )
            )
        }

        return FocusZoneRowPresentation(
            title: task.title,
            secondarySegments: secondarySegments
        )
    }
}

enum FocusZoneTimePressureResolver {
    static func resolve(
        task: TaskDefinition,
        now: Date = Date(),
        showDueTodayTime: Bool = true
    ) -> FocusZoneBadgePresentation? {
        guard !task.isComplete else { return nil }

        if let dueDate = task.dueDate, let lateLabel = OverdueAgeFormatter.lateLabel(dueDate: dueDate, now: now) {
            let normalizedLateLabel = lateLabel.replacingOccurrences(of: " late", with: "")
            return FocusZoneBadgePresentation(text: "Late by \(normalizedLateLabel)", tone: .danger)
        }

        if isDueSoon(task: task, now: now) {
            return FocusZoneBadgePresentation(text: "Due soon", tone: .warning)
        }

        guard showDueTodayTime else { return nil }

        guard let dueDate = task.dueDate, Calendar.current.isDate(dueDate, inSameDayAs: now) else {
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
}

enum FocusZoneSecondaryLineResolver {
    static func resolve(
        task: TaskDefinition,
        showInboxProjectName: Bool = true
    ) -> FocusZoneSecondaryLine {
        if task.projectID == ProjectConstants.inboxProjectID {
            guard showInboxProjectName else {
                return FocusZoneSecondaryLine(text: nil)
            }
            return FocusZoneSecondaryLine(text: "Inbox")
        }

        let projectName = task.projectName?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let projectName, !projectName.isEmpty {
            return FocusZoneSecondaryLine(text: projectName)
        }

        return FocusZoneSecondaryLine(text: nil)
    }
}

private struct FocusZoneRow: View {
    let task: TaskDefinition
    let insight: EvaFocusTaskInsight?
    let canDrag: Bool
    let showStartFocusAction: Bool
    let onTap: () -> Void
    let onToggleComplete: () -> Void
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

            HStack(alignment: .top, spacing: spacing.s8) {
                VStack(alignment: .leading, spacing: spacing.s2) {
                    Text(presentation.title)
                        .font(.tasker(.callout).weight(.semibold))
                        .foregroundColor(task.isComplete ? Color.tasker.textSecondary : Color.tasker.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    secondaryLineView
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, spacing.s4)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
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
        }
        .contextMenu {
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
        .accessibilityIdentifier("home.focus.task.\(task.id.uuidString)")
        .accessibilityLabel(task.title)
        .accessibilityHint("Opens task details")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            onTap()
        }
    }

    @ViewBuilder
    private var secondaryLineView: some View {
        if presentation.secondarySegments.isEmpty == false {
            (
                presentation.secondarySegments.enumerated().reduce(Text("")) { partialResult, entry in
                    let segmentText = styledSecondaryText(for: entry.element)
                    if entry.offset == 0 {
                        return partialResult + segmentText
                    }
                    return partialResult
                        + Text(" · ")
                            .font(.tasker(.caption1))
                            .foregroundColor(Color.tasker.textTertiary)
                        + segmentText
                }
            )
            .font(.tasker(.caption1))
            .lineLimit(1)
        }
    }

    @MainActor
    private func styledSecondaryText(for segment: FocusZoneSecondarySegment) -> Text {
        switch segment.kind {
        case .urgency(let tone):
            return Text(segment.text)
                .font(.tasker(.caption1))
                .foregroundColor(tone.foregroundColor)
        case .metadata:
            return Text(segment.text)
                .font(.tasker(.caption1))
                .foregroundColor(Color.tasker.textSecondary)
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
                maxVisibleRows: 3,
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
                maxVisibleRows: 3,
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
