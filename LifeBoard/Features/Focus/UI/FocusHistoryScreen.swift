import SwiftUI

/// A month of focus: the grid, the totals, the tasks that took the most of
/// it, and one day's sessions on tap. History is evidence in clay — there is
/// no hero here, and no chart over a hero — so every section is an open row
/// or a plain card, and every colour carries a text equivalent.
struct FocusHistoryScreen: View {
    let projection: FocusHistoryProjection
    let isLoading: Bool
    var canShowNextMonth = true
    let onPreviousMonth: () -> Void
    let onNextMonth: () -> Void
    let onOpenTask: (UUID) -> Void

    @State private var selectedDay: Date?
    @State private var revealProgress: Double = 0
    @State private var monthDirection: Int = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var monthName: String {
        projection.month.formatted(.dateTime.month(.wide))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            FocusHistoryMonthHeader(
                month: projection.month,
                canShowNext: canShowNextMonth,
                onPrevious: { monthDirection = -1; selectedDay = nil; onPreviousMonth() },
                onNext: { monthDirection = 1; selectedDay = nil; onNextMonth() }
            )
            if projection.sessionCount == 0, isLoading == false {
                // A month with nothing in it says so, instead of "0m · 0 · 0m".
                Text("No focus sessions in \(monthName)")
                    .lifeboardFont(.body)
                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("focus.history.empty")
            } else {
                FocusHistoryTotals(projection: projection)
                    .redacted(reason: isLoading ? .placeholder : [])
            }
            FocusHistoryGrid(projection: projection, selectedDay: $selectedDay)
                .redacted(reason: isLoading ? .placeholder : [])
                .allowsHitTesting(isLoading == false)
                .lifeboardChartRevealSweep(progress: revealProgress)
                .transition(.asymmetric(
                    insertion: .move(edge: monthDirection >= 0 ? .trailing : .leading).combined(with: .opacity),
                    removal: .opacity
                ))
                .id(projection.month)
            if let selectedDay {
                FocusHistoryDayList(
                    day: selectedDay,
                    sessions: projection.sessions.filter { Calendar.current.isDate($0.startedAt, inSameDayAs: selectedDay) },
                    onOpenTask: onOpenTask
                )
            }
            FocusHistoryTopTasks(tasks: projection.topTasks, onOpenTask: onOpenTask)
        }
        .lifeBoardMotion(.cardReflow, value: projection.month)
        .lifeBoardMotion(.contentInsertion, value: selectedDay)
        .accessibilityIdentifier("focus.history")
        .onChange(of: projection.sessionCount, initial: true) { _, count in
            // The sweep plays once, when data first appears; a month with no
            // sessions has nothing to reveal.
            guard count > 0, revealProgress == 0 else { return }
            withAnimation(MotionProfile.contentInsertion.animation(reduceMotion: reduceMotion)) { revealProgress = 1 }
        }
    }
}

private struct FocusHistoryMonthHeader: View {
    let month: Date
    let canShowNext: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack {
            Button(action: onPrevious) {
                Image(systemName: "chevron.left").frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Previous month")
            .accessibilityIdentifier("focus.history.previousMonth")
            Spacer()
            Text(month.formatted(.dateTime.month(.wide).year()))
                .lifeboardFont(.headline)
                .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Button(action: onNext) {
                Image(systemName: "chevron.right").frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Next month")
            .accessibilityIdentifier("focus.history.nextMonth")
            .disabled(canShowNext == false)
            .opacity(canShowNext ? 1 : 0.35)
        }
        .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
    }
}

private struct FocusHistoryTotals: View {
    let projection: FocusHistoryProjection

    var body: some View {
        HStack(spacing: 12) {
            total("Focused", value: FocusHistoryProjection.durationText(minutes: projection.totalMinutes))
            total("Sessions", value: "\(projection.sessionCount)")
            total("Longest", value: FocusHistoryProjection.durationText(minutes: projection.longestMinutes))
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("focus.history.totals")
    }

    private func total(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .lifeboardFont(.title3)
                .monospacedDigit()
                .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
            Text(label)
                .lifeboardFont(.caption1)
                .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .lifeBoardClaySurface(.raised, cornerRadius: Radius.card)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

private struct FocusHistoryGrid: View {
    let projection: FocusHistoryProjection
    @Binding var selectedDay: Date?
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

    private var dayByDate: [Date: FocusHistoryProjection.Day] {
        Dictionary(uniqueKeysWithValues: projection.days.map { ($0.date, $0) })
    }

    var body: some View {
        MonthGrid(month: projection.month) { date in
            let day = dayByDate[date]
            let isSelected = selectedDay.map { Calendar.current.isDate($0, inSameDayAs: date) } ?? false
            Button {
                Haptic.pick.play()
                selectedDay = isSelected ? nil : date
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: Radius.field, style: .continuous)
                        .fill(fill(for: day?.tint ?? 0))
                    if isSelected {
                        RoundedRectangle(cornerRadius: Radius.field, style: .continuous)
                            .strokeBorder(Color(SemanticColorTokens.foundationApricotInk), lineWidth: 2)
                    }
                    if differentiateWithoutColor, let tint = day?.tint, tint > 0 {
                        // Four steps, four marks: the tint is never the only signal.
                        HStack(spacing: 2) {
                            ForEach(0..<tint, id: \.self) { _ in
                                Circle().fill(Color(SemanticColorTokens.inkSecondary)).frame(width: 3, height: 3)
                            }
                        }
                        .offset(y: 12)
                    }
                    Text("\(Calendar.current.component(.day, from: date))")
                        .lifeboardFont(.caption1)
                        .monospacedDigit()
                        .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            // With the month: "Tuesday 3" alone did not say which Tuesday.
            .accessibilityLabel(date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
            .accessibilityValue(day?.summary ?? "No focus")
            .accessibilityIdentifier("focus.history.day.\(Calendar.current.component(.day, from: date))")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("focus.history.grid")
    }

    private func fill(for tint: Int) -> Color {
        switch tint {
        case 0: Color(SemanticColorTokens.foundationSurfaceRecessed).opacity(0.5)
        case 1: Color(SemanticColorTokens.foundationApricotAccent).opacity(0.18)
        case 2: Color(SemanticColorTokens.foundationApricotAccent).opacity(0.34)
        case 3: Color(SemanticColorTokens.foundationApricotAccent).opacity(0.52)
        default: Color(SemanticColorTokens.foundationApricotAccent).opacity(0.72)
        }
    }
}

private struct FocusHistoryDayList: View {
    let day: Date
    let sessions: [FocusHistoryProjection.Session]
    let onOpenTask: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(day.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                .lifeboardFont(.headline)
                .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
            if sessions.isEmpty {
                Text("No focus that day")
                    .lifeboardFont(.body)
                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
            }
            ForEach(sessions) { session in
                Button {
                    if let taskID = session.taskID { onOpenTask(taskID) }
                } label: {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(session.title)
                                .lifeboardFont(.body)
                                .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
                            Text(session.startedAt.formatted(date: .omitted, time: .shortened)
                                 + (session.energyAfter.map { String(localized: " · Energy \($0) of 5") } ?? ""))
                                .lifeboardFont(.caption1)
                                .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                            if let reflection = session.reflection, reflection.isEmpty == false {
                                Text(reflection)
                                    .lifeboardFont(.caption1)
                                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                                    .lineLimit(2)
                            }
                        }
                        Spacer(minLength: 8)
                        Text(FocusHistoryProjection.durationText(minutes: session.minutes))
                            .lifeboardFont(.body)
                            .monospacedDigit()
                            .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                // Not `.disabled`: a session with no task is still a record
                // to read, and VoiceOver announced it as a dimmed control.
                .allowsHitTesting(session.taskID != nil)
                .accessibilityRemoveTraits(session.taskID == nil ? .isButton : [])
                .accessibilityIdentifier("focus.history.session.\(session.id.uuidString)")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("focus.history.day")
    }
}

private struct FocusHistoryTopTasks: View {
    let tasks: [FocusHistoryProjection.TaskTotal]
    let onOpenTask: (UUID) -> Void

    var body: some View {
        if tasks.isEmpty == false {
            VStack(alignment: .leading, spacing: 8) {
                Text("By task")
                    .lifeboardFont(.headline)
                    .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
                ForEach(tasks) { task in
                    Button {
                        if let taskID = task.taskID { onOpenTask(taskID) }
                    } label: {
                        HStack {
                            Text(task.title)
                                .lifeboardFont(.body)
                                .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
                                .lineLimit(1)
                            Spacer(minLength: 8)
                            Text("\(FocusHistoryProjection.durationText(minutes: task.minutes)) · \(task.sessionCount)")
                                .lifeboardFont(.caption1)
                                .monospacedDigit()
                                .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                        }
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(task.taskID == nil)
                    .accessibilityLabel(
                        task.sessionCount == 1
                            ? "\(task.title), \(FocusHistoryProjection.durationText(minutes: task.minutes)) in 1 session"
                            : "\(task.title), \(FocusHistoryProjection.durationText(minutes: task.minutes)) in \(task.sessionCount) sessions"
                    )
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("focus.history.topTasks")
        }
    }
}
