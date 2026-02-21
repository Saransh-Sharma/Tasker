//
//  AddTaskMetadataRow.swift
//  Tasker
//
//  Reminder toggle chip for the quick capture section.
//  Date presets moved to AddTaskDatePresetRow; this handles reminder only.
//

import SwiftUI

// MARK: - Add Task Reminder Chip

struct AddTaskReminderChip: View {
    @Binding var hasReminder: Bool
    @Binding var reminderTime: Date

    @State private var showTimePicker = false
    @State private var bellTrigger = false

    var body: some View {
        HStack(spacing: 8) {
            // Reminder toggle chip
            AddTaskMetadataChip(
                icon: hasReminder ? "bell.fill" : "bell",
                text: hasReminder ? formatTime(reminderTime) : "Reminder",
                isActive: hasReminder
            ) {
                if hasReminder {
                    withAnimation(TaskerAnimation.quick) {
                        hasReminder = false
                    }
                    TaskerFeedback.light()
                } else {
                    showTimePicker = true
                }
            }
            .bellShake(trigger: $bellTrigger)
        }
        .onChange(of: hasReminder) { _, newValue in
            if newValue {
                bellTrigger = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    bellTrigger = false
                }
            }
        }
        .sheet(isPresented: $showTimePicker) {
            AddTaskTimePickerSheet(
                reminderTime: $reminderTime,
                hasReminder: $hasReminder,
                isPresented: $showTimePicker
            )
        }
    }

    /// Executes formatTime.
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - Time Picker Sheet

struct AddTaskTimePickerSheet: View {
    @Binding var reminderTime: Date
    @Binding var hasReminder: Bool
    @Binding var isPresented: Bool

    @State private var selectedTime = Date()

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }
    private var corner: TaskerCornerTokens { TaskerThemeManager.shared.currentTheme.tokens.corner }

    var body: some View {
        NavigationView {
            VStack(spacing: spacing.s20) {
                // Quick preset row
                HStack(spacing: spacing.s8) {
                    ForEach(ReminderPreset.allCases, id: \.self) { preset in
                        Button {
                            TaskerFeedback.selection()
                            selectedTime = preset.date
                        } label: {
                            Text(preset.label)
                                .font(.tasker(.callout))
                                .foregroundColor(Color.tasker.textSecondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(Color.tasker.surfaceSecondary)
                                )
                        }
                        .buttonStyle(.plain)
                        .scaleOnPress()
                    }
                }
                .padding(.horizontal, spacing.s16)

                DatePicker(
                    "Reminder Time",
                    selection: $selectedTime,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.wheel)
                .padding(.horizontal, spacing.s16)

                Button {
                    reminderTime = selectedTime
                    hasReminder = true
                    TaskerFeedback.success()
                    isPresented = false
                } label: {
                    Text("Set Reminder")
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
            .navigationTitle("Set Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
        .presentationDetents([.height(400)])
        .onAppear {
            selectedTime = reminderTime
        }
    }
}

// MARK: - Reminder Presets

enum ReminderPreset: CaseIterable {
    case morning, noon, afternoon, evening

    var label: String {
        switch self {
        case .morning: return "9 AM"
        case .noon: return "12 PM"
        case .afternoon: return "3 PM"
        case .evening: return "6 PM"
        }
    }

    var date: Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        switch self {
        case .morning: return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: today) ?? today
        case .noon: return calendar.date(bySettingHour: 12, minute: 0, second: 0, of: today) ?? today
        case .afternoon: return calendar.date(bySettingHour: 15, minute: 0, second: 0, of: today) ?? today
        case .evening: return calendar.date(bySettingHour: 18, minute: 0, second: 0, of: today) ?? today
        }
    }
}
