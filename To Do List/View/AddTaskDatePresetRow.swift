//
//  AddTaskDatePresetRow.swift
//  Tasker
//
//  Pill group for quick date selection: Today / Tomorrow / This Week / Someday + custom.
//

import SwiftUI

// MARK: - Add Task Date Preset Row

struct AddTaskDatePresetRow: View {
    @Binding var dueDate: Date?
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

    private func applyPreset(_ preset: DatePreset) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        switch preset {
        case .today:
            dueDate = today
        case .tomorrow:
            dueDate = calendar.date(byAdding: .day, value: 1, to: today)
        case .thisWeek:
            // End of current week (Sunday)
            let daysUntilEndOfWeek = 7 - calendar.component(.weekday, from: today)
            dueDate = calendar.date(byAdding: .day, value: max(daysUntilEndOfWeek, 2), to: today)
        case .someday:
            dueDate = nil
        }
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
}

// MARK: - Custom Date Picker Sheet

struct AddTaskCustomDatePickerSheet: View {
    @Binding var dueDate: Date?
    @Binding var isPresented: Bool

    @State private var selectedDate = Date()

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }
    private var corner: TaskerCornerTokens { TaskerThemeManager.shared.currentTheme.tokens.corner }

    var body: some View {
        NavigationView {
            VStack(spacing: spacing.s20) {
                DatePicker(
                    "Due Date",
                    selection: $selectedDate,
                    in: Calendar.current.startOfDay(for: Date())...,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding(.horizontal, spacing.s16)

                Button {
                    dueDate = selectedDate
                    TaskerFeedback.success()
                    isPresented = false
                } label: {
                    Text("Set Date")
                        .font(.tasker(.button))
                        .foregroundColor(Color.tasker.accentOnPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: spacing.buttonHeight)
                        .background(
                            RoundedRectangle(cornerRadius: corner.r2)
                                .fill(Color.tasker.accentPrimary)
                        )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, spacing.s16)
            }
            .navigationTitle("Pick a Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .onAppear {
            if let dueDate {
                selectedDate = dueDate
            }
        }
    }
}
