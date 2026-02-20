//
//  AddTaskRepeatEditor.swift
//  Tasker
//
//  Repeat schedule editor: None / Daily / Weekdays / Weekly / Monthly / Custom.
//  Maps to TaskRepeatPattern enum.
//

import SwiftUI

// MARK: - Repeat Editor

struct AddTaskRepeatEditor: View {
    @Binding var repeatPattern: TaskRepeatPattern?

    @State private var showWeekdayPicker = false

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }

    private var activePreset: RepeatPreset {
        guard let pattern = repeatPattern else { return .none }
        switch pattern {
        case .daily: return .daily
        case .weekdays: return .weekdays
        case .weekly: return .weekly
        case .monthly: return .monthly
        default: return .custom
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.s8) {
            Text("Repeat")
                .font(.tasker(.caption1))
                .foregroundColor(Color.tasker.textTertiary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: spacing.chipSpacing) {
                    ForEach(RepeatPreset.allCases, id: \.self) { preset in
                        AddTaskMetadataChip(
                            icon: preset.icon,
                            text: preset.label,
                            isActive: activePreset == preset
                        ) {
                            withAnimation(TaskerAnimation.snappy) {
                                applyPreset(preset)
                            }
                        }
                    }
                }
            }

            // Weekday picker for weekly
            if showWeekdayPicker, case .weekly(let days) = repeatPattern {
                ScrollView(.horizontal, showsIndicators: false) {
                    WeekdayPickerRow(selectedDays: Binding(
                        get: { days },
                        set: { newDays in
                            repeatPattern = .weekly(newDays)
                        }
                    ))
                }
                .transition(
                    .asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity
                    )
                )
            }
        }
        .animation(TaskerAnimation.snappy, value: activePreset)
    }

    // MARK: - Helpers

    private func applyPreset(_ preset: RepeatPreset) {
        switch preset {
        case .none:
            repeatPattern = nil
            showWeekdayPicker = false
        case .daily:
            repeatPattern = .daily
            showWeekdayPicker = false
        case .weekdays:
            repeatPattern = .weekdays
            showWeekdayPicker = false
        case .weekly:
            repeatPattern = .weekly(.weekdays)
            showWeekdayPicker = true
        case .monthly:
            let day = Calendar.current.component(.day, from: Date())
            repeatPattern = .monthly(.onDate(day))
            showWeekdayPicker = false
        case .custom:
            repeatPattern = .custom(TaskRepeatPattern.CustomPattern(intervalDays: 3))
            showWeekdayPicker = false
        }
    }
}

// MARK: - Repeat Presets

enum RepeatPreset: CaseIterable {
    case none, daily, weekdays, weekly, monthly, custom

    var label: String {
        switch self {
        case .none: return "None"
        case .daily: return "Daily"
        case .weekdays: return "Weekdays"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .custom: return "Custom"
        }
    }

    var icon: String {
        switch self {
        case .none: return "xmark.circle"
        case .daily: return "repeat"
        case .weekdays: return "briefcase"
        case .weekly: return "calendar.badge.clock"
        case .monthly: return "calendar"
        case .custom: return "gearshape"
        }
    }
}

// MARK: - Weekday Item

private struct WeekdayItem: Identifiable {
    let id: Int
    let label: String
    let day: TaskRepeatPattern.DaysOfWeek
}

// MARK: - Weekday Picker Row

struct WeekdayPickerRow: View {
    @Binding var selectedDays: TaskRepeatPattern.DaysOfWeek

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }

    private let weekdays: [WeekdayItem] = [
        WeekdayItem(id: 0, label: "S", day: .sunday),
        WeekdayItem(id: 1, label: "M", day: .monday),
        WeekdayItem(id: 2, label: "T", day: .tuesday),
        WeekdayItem(id: 3, label: "W", day: .wednesday),
        WeekdayItem(id: 4, label: "T", day: .thursday),
        WeekdayItem(id: 5, label: "F", day: .friday),
        WeekdayItem(id: 6, label: "S", day: .saturday),
    ]

    var body: some View {
        HStack(spacing: spacing.s4) {
            ForEach(weekdays) { item in
                Button {
                    TaskerFeedback.selection()
                    withAnimation(TaskerAnimation.snappy) {
                        if selectedDays.contains(item.day) {
                            selectedDays.remove(item.day)
                        } else {
                            selectedDays.insert(item.day)
                        }
                    }
                } label: {
                    Text(item.label)
                        .font(.tasker(.callout))
                        .fontWeight(selectedDays.contains(item.day) ? .bold : .regular)
                        .foregroundColor(
                            selectedDays.contains(item.day)
                            ? Color.tasker.accentOnPrimary
                            : Color.tasker.textSecondary
                        )
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(selectedDays.contains(item.day)
                                      ? Color.tasker.accentPrimary
                                      : Color.tasker.surfaceTertiary)
                        )
                }
                .buttonStyle(.plain)
                .scaleOnPress()
            }
        }
    }
}
