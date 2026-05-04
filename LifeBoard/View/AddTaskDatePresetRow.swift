//
//  AddTaskDatePresetRow.swift
//  Tasker
//
//  Pill group for quick date selection: Today / Tomorrow / This Week / Someday + custom.
//

import SwiftUI

// MARK: - Add Task Date Preset Row

private enum AddTaskDatePickerAccessibilityID {
    static let customDateChip = "tasker.datePicker.customDateChip"
    static let sheet = "tasker.datePicker.sheet"
    static let calendar = "tasker.datePicker.calendar"
    static let confirmButton = "tasker.datePicker.confirmButton"
}

struct AddTaskDatePresetRow: View {
    @Binding var dueDate: Date?
    let customChipAccessibilityIdentifier: String?
    @State private var showDatePicker = false

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }

    private var activePreset: DatePreset? {
        guard let dueDate else { return .someday }
        let calendar = Calendar.current
        if calendar.isDateInToday(dueDate) { return .today }
        if calendar.isDateInTomorrow(dueDate) { return .tomorrow }
        // Check if within this week (remaining days)
        let today = calendar.startOfDay(for: Date())
        if let endOfWeek = calendar.date(byAdding: .day, value: 7 - calendar.component(.weekday, from: today), to: today),
           dueDate <= endOfWeek, dueDate > today {
            return .thisWeek
        }
        return nil // custom date
    }

    init(
        dueDate: Binding<Date?>,
        customChipAccessibilityIdentifier: String? = nil
    ) {
        self._dueDate = dueDate
        self.customChipAccessibilityIdentifier = customChipAccessibilityIdentifier
    }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.s8) {
            Text("Due")
                .font(.tasker(.caption1))
                .foregroundColor(Color.tasker.textTertiary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: spacing.chipSpacing) {
                    ForEach(DatePreset.allCases, id: \.self) { preset in
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

                    // Custom date chip
                    AddTaskMetadataChip(
                        icon: "calendar.badge.plus",
                        text: customDateText,
                        isActive: activePreset == nil && dueDate != nil
                    ) {
                        showDatePicker = true
                    }
                    .accessibilityIdentifier(customChipAccessibilityIdentifier ?? AddTaskDatePickerAccessibilityID.customDateChip)
                }
            }
        }
        .sheet(isPresented: $showDatePicker) {
            AddTaskCustomDatePickerSheet(
                dueDate: $dueDate,
                isPresented: $showDatePicker
            )
        }
    }

    // MARK: - Helpers

    private var customDateText: String {
        if activePreset == nil, let dueDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE, MMM d"
            return formatter.string(from: dueDate)
        }
        return "Pick date"
    }

    /// Executes applyPreset.
    private func applyPreset(_ preset: DatePreset) {
        dueDate = preset.resolvedDueDate()
    }
}

// MARK: - Date Preset Enum

enum DatePreset: CaseIterable {
    case today, tomorrow, thisWeek, someday

    var label: String {
        switch self {
        case .today: return "Today"
        case .tomorrow: return "Tomorrow"
        case .thisWeek: return "This Week"
        case .someday: return "Someday"
        }
    }

    var icon: String {
        switch self {
        case .today: return "sun.horizon"
        case .tomorrow: return "sunrise"
        case .thisWeek: return "calendar"
        case .someday: return "tray"
        }
    }

    func resolvedDueDate(anchorDate: Date = Date(), calendar: Calendar = .current) -> Date? {
        let today = calendar.startOfDay(for: anchorDate)

        switch self {
        case .today:
            return today
        case .tomorrow:
            return calendar.date(byAdding: .day, value: 1, to: today)
        case .thisWeek:
            let daysUntilEndOfWeek = 7 - calendar.component(.weekday, from: today)
            return calendar.date(byAdding: .day, value: max(daysUntilEndOfWeek, 2), to: today)
        case .someday:
            return nil
        }
    }
}

// MARK: - Custom Date Picker Sheet

struct AddTaskCustomDatePickerSheet: View {
    @Binding var dueDate: Date?
    @Binding var isPresented: Bool

    @State private var selectedDate = Date()

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }

    var body: some View {
        NavigationStack {
            VStack(spacing: spacing.s20) {
                DatePicker(
                    "Due Date",
                    selection: $selectedDate,
                    in: Calendar.current.startOfDay(for: Date())...,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding(.horizontal, spacing.s16)
                .accessibilityIdentifier(AddTaskDatePickerAccessibilityID.calendar)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .accessibilityIdentifier(AddTaskDatePickerAccessibilityID.sheet)
            .navigationTitle("Pick a Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Set Date") {
                        dueDate = selectedDate
                        TaskerFeedback.success()
                        isPresented = false
                    }
                    .font(.tasker(.button))
                    .accessibilityIdentifier(AddTaskDatePickerAccessibilityID.confirmButton)
                }
            }
        }
        .accessibilityIdentifier(AddTaskDatePickerAccessibilityID.sheet)
        .presentationDetents([.medium, .large])
        .onAppear {
            if let dueDate {
                selectedDate = dueDate
            }
        }
    }
}
