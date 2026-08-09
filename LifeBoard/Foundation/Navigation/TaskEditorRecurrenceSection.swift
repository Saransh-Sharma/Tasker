import SwiftUI
import UIKit

/// The repeat-pattern editor: choice picker plus whichever detail control the
/// selected pattern needs.
struct TaskEditorRecurrenceSection: View {
    @Bindable var editor: TaskEditorStore

    var body: some View {
        recurrence(editor: $editor)
    }

    private func recurrence(editor: Bindable<TaskEditorStore>) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            TaskEditorControls.header("Rhythm", symbol: "repeat")
            Picker(
                "Repeat",
                selection: Binding(
                    get: { recurrenceChoice(editor.wrappedValue.draft.repeatPattern) },
                    set: { editor.wrappedValue.draft.repeatPattern = repeatPattern($0) }
                )
            ) {
                Text("Never").tag(0)
                Text("Daily").tag(1)
                Text("Weekdays").tag(2)
                Text("Weekly").tag(3)
                Text("Every two weeks").tag(4)
                Text("Monthly on a date").tag(5)
                Text("Monthly by weekday").tag(6)
                Text("Yearly").tag(7)
                Text("Custom interval").tag(8)
            }
            if editor.wrappedValue.draft.repeatPattern != nil {
                recurrenceDetails(editor: editor)
                Picker("Anchor", selection: editor.draft.recurrenceAnchor) {
                    Text("Scheduled date").tag(TaskRecurrenceRule.Anchor.scheduledDate)
                    Text("When completed").tag(TaskRecurrenceRule.Anchor.completionDate)
                }
                .pickerStyle(.segmented)
                Text(
                    editor.wrappedValue.draft.recurrenceAnchor == .completionDate
                        ? "The next occurrence begins from the day you finish this one."
                        : "Future occurrences stay on their intended calendar rhythm."
                )
                .font(.caption)
                .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
            }
        }
        .taskEditorSurface()
    }

    @ViewBuilder
    private func recurrenceDetails(editor: Bindable<TaskEditorStore>) -> some View {
        switch editor.wrappedValue.draft.repeatPattern {
        case .weekly(let days):
            weekdayButtons(days: days) {
                editor.wrappedValue.draft.repeatPattern = .weekly($0)
            }
        case .biweekly(let days):
            weekdayButtons(days: days) {
                editor.wrappedValue.draft.repeatPattern = .biweekly($0)
            }
        case .monthly(.onDate(let day)):
            Stepper(
                "Day \(day) of each month",
                value: Binding(
                    get: { day },
                    set: {
                        editor.wrappedValue.draft.repeatPattern = .monthly(
                            .onDate(min(max(1, $0), 31))
                        )
                    }
                ),
                in: 1...31
            )
        case .monthly(.onWeekday(let week, let weekday)):
            Picker(
                "Week",
                selection: Binding(
                    get: { week },
                    set: {
                        editor.wrappedValue.draft.repeatPattern = .monthly(
                            .onWeekday(weekOfMonth: $0, dayOfWeek: weekday)
                        )
                    }
                )
            ) {
                Text("First").tag(1)
                Text("Second").tag(2)
                Text("Third").tag(3)
                Text("Fourth").tag(4)
                Text("Fifth").tag(5)
            }
            Picker(
                "Weekday",
                selection: Binding(
                    get: { weekday },
                    set: {
                        editor.wrappedValue.draft.repeatPattern = .monthly(
                            .onWeekday(weekOfMonth: week, dayOfWeek: $0)
                        )
                    }
                )
            ) {
                ForEach(Array(Calendar.current.weekdaySymbols.enumerated()), id: \.offset) {
                    index, name in
                    Text(name).tag(index + 1)
                }
            }
        case .monthly(.lastWeekday(let weekday)):
            Picker(
                "Last weekday",
                selection: Binding(
                    get: { weekday },
                    set: {
                        editor.wrappedValue.draft.repeatPattern = .monthly(
                            .lastWeekday(dayOfWeek: $0)
                        )
                    }
                )
            ) {
                ForEach(Array(Calendar.current.weekdaySymbols.enumerated()), id: \.offset) {
                    index, name in
                    Text(name).tag(index + 1)
                }
            }
        case .yearly(let pattern):
            DatePicker(
                "Repeat date",
                selection: Binding(
                    get: { recurrenceYearlyDate(pattern) },
                    set: {
                        let components = Calendar.current.dateComponents(
                            [.month, .day],
                            from: $0
                        )
                        editor.wrappedValue.draft.repeatPattern = .yearly(
                            .onDate(
                                month: components.month ?? 1,
                                day: components.day ?? 1
                            )
                        )
                    }
                ),
                displayedComponents: .date
            )
        case .custom(let pattern):
            Stepper(
                "Every \(pattern.intervalDays) days",
                value: Binding(
                    get: { pattern.intervalDays },
                    set: {
                        editor.wrappedValue.draft.repeatPattern = .custom(
                            .init(
                                intervalDays: min(max(1, $0), 365),
                                endDate: pattern.endDate,
                                maxOccurrences: pattern.maxOccurrences
                            )
                        )
                    }
                ),
                in: 1...365
            )
            TaskEditorControls.optionalDate(
                "End repeat",
                value: Binding(
                    get: { pattern.endDate },
                    set: {
                        editor.wrappedValue.draft.repeatPattern = .custom(
                            .init(
                                intervalDays: pattern.intervalDays,
                                endDate: $0,
                                maxOccurrences: pattern.maxOccurrences
                            )
                        )
                    }
                )
            )
            Toggle(
                "Limit occurrences",
                isOn: Binding(
                    get: { pattern.maxOccurrences != nil },
                    set: {
                        editor.wrappedValue.draft.repeatPattern = .custom(
                            .init(
                                intervalDays: pattern.intervalDays,
                                endDate: pattern.endDate,
                                maxOccurrences: $0 ? (pattern.maxOccurrences ?? 10) : nil
                            )
                        )
                    }
                )
            )
            if let maximum = pattern.maxOccurrences {
                Stepper(
                    "Stop after \(maximum)",
                    value: Binding(
                        get: { maximum },
                        set: {
                            editor.wrappedValue.draft.repeatPattern = .custom(
                                .init(
                                    intervalDays: pattern.intervalDays,
                                    endDate: pattern.endDate,
                                    maxOccurrences: min(max(1, $0), 999)
                                )
                            )
                        }
                    ),
                    in: 1...999
                )
            }
        case .daily, .weekdays, nil:
            EmptyView()
        }
    }

    private func weekdayButtons(
        days: TaskRepeatPattern.DaysOfWeek,
        onChange: @escaping (TaskRepeatPattern.DaysOfWeek) -> Void
    ) -> some View {
        let values: [(String, TaskRepeatPattern.DaysOfWeek)] = [
            ("S", .sunday),
            ("M", .monday),
            ("T", .tuesday),
            ("W", .wednesday),
            ("T", .thursday),
            ("F", .friday),
            ("S", .saturday)
        ]
        return HStack(spacing: 6) {
            ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                let selected = days.contains(value.1)
                Button {
                    var updated = days
                    if selected {
                        updated.remove(value.1)
                    } else {
                        updated.insert(value.1)
                    }
                    guard updated.isEmpty == false else { return }
                    onChange(updated)
                } label: {
                    Text(value.0)
                        .font(.caption.weight(.bold))
                        .frame(width: 44, height: 44)
                        .background(
                            selected
                                ? Color(LifeBoardColorTokens.foundationSageAccent)
                                : Color(LifeBoardColorTokens.foundationSurfaceSolid),
                            in: Capsule()
                        )
                        .foregroundStyle(
                            selected
                                ? Color(LifeBoardColorTokens.inkPrimary)
                                : Color(LifeBoardColorTokens.inkSecondary)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Calendar.current.weekdaySymbols[index])
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }

    private func recurrenceChoice(_ pattern: TaskRepeatPattern?) -> Int {
        switch pattern {
        case nil: 0
        case .daily: 1
        case .weekdays: 2
        case .weekly: 3
        case .biweekly: 4
        case .monthly(.onDate): 5
        case .monthly: 6
        case .yearly: 7
        case .custom: 8
        }
    }

    private func repeatPattern(_ choice: Int) -> TaskRepeatPattern? {
        let components = Calendar.current.dateComponents([.month, .day], from: Date())
        return switch choice {
        case 1: .daily
        case 2: .weekdays
        case 3: .weekly(.allDays)
        case 4: .biweekly(.allDays)
        case 5: .monthly(.onDate(Calendar.current.component(.day, from: Date())))
        case 6: .monthly(
            .onWeekday(
                weekOfMonth: max(
                    1,
                    Calendar.current.component(.weekOfMonth, from: Date())
                ),
                dayOfWeek: Calendar.current.component(.weekday, from: Date())
            )
        )
        case 7: .yearly(
            .onDate(month: components.month ?? 1, day: components.day ?? 1)
        )
        case 8: .custom(.init(intervalDays: 3))
        default: nil
        }
    }

    private func recurrenceYearlyDate(_ pattern: TaskRepeatPattern.YearlyPattern) -> Date {
        let month: Int
        let day: Int
        switch pattern {
        case let .onDate(valueMonth, valueDay):
            month = valueMonth
            day = valueDay
        case let .onWeekday(valueMonth, weekOfMonth, dayOfWeek):
            var components = DateComponents()
            components.year = Calendar.current.component(.year, from: Date())
            components.month = valueMonth
            components.weekOfMonth = weekOfMonth
            components.weekday = dayOfWeek
            return Calendar.current.date(from: components) ?? Date()
        }
        return Calendar.current.date(
            from: DateComponents(
                year: Calendar.current.component(.year, from: Date()),
                month: month,
                day: day
            )
        ) ?? Date()
    }}
