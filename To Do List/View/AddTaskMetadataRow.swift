//
//  AddTaskMetadataRow.swift
//  Tasker
//
//  Horizontal row of metadata chips for date, reminder, and time of day selection.
//

import SwiftUI

// MARK: - Add Task Metadata Row

struct AddTaskMetadataRow: View {
    @Binding var dueDate: Date
    @Binding var reminderTime: Date?
    @Binding var isEvening: Bool

    @State private var showTimePicker = false

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: spacing.chipSpacing) {
                // Date chip
                AddTaskMetadataChip(
                    icon: "calendar",
                    text: smartDateText(for: dueDate),
                    isActive: !Calendar.current.isDateInToday(dueDate)
                ) {
                    cycleDate()
                }

                // Reminder chip
                AddTaskMetadataChip(
                    icon: reminderTime != nil ? "bell.fill" : "bell",
                    text: reminderTime != nil ? formatTime(reminderTime!) : "Reminder",
                    isActive: reminderTime != nil
                ) {
                    if reminderTime != nil {
                        reminderTime = nil
                    } else {
                        showTimePicker = true
                    }
                }

                // Time of day chip
                AddTaskMetadataChip(
                    icon: isEvening ? "moon.stars" : "sun.max",
                    text: isEvening ? "Evening" : "Morning",
                    isActive: isEvening
                ) {
                    withAnimation(TaskerAnimation.quick) {
                        isEvening.toggle()
                    }
                }
            }
        }
        .sheet(isPresented: $showTimePicker) {
            AddTaskTimePickerSheet(time: $reminderTime, isPresented: $showTimePicker)
        }
    }

    // MARK: - Date Helpers

    private func smartDateText(for date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "Today" }
        if Calendar.current.isDateInTomorrow(date) { return "Tomorrow" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: date)
    }

    private func cycleDate() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        withAnimation(TaskerAnimation.snappy) {
            if calendar.isDateInToday(dueDate) {
                dueDate = calendar.date(byAdding: .day, value: 1, to: today) ?? today
            } else if calendar.isDateInTomorrow(dueDate) {
                dueDate = calendar.date(byAdding: .day, value: 2, to: today) ?? today
            } else {
                dueDate = today
            }
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - Time Picker Sheet

struct AddTaskTimePickerSheet: View {
    @Binding var time: Date?
    @Binding var isPresented: Bool

    @State private var selectedTime = Date()

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }
    private var corner: TaskerCornerTokens { TaskerThemeManager.shared.currentTheme.tokens.corner }

    var body: some View {
        NavigationView {
            VStack(spacing: spacing.s20) {
                DatePicker(
                    "Reminder Time",
                    selection: $selectedTime,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.wheel)
                .padding(.horizontal, spacing.s16)

                Button {
                    time = selectedTime
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
        .presentationDetents([.height(350)])
    }
}

// MARK: - Preview

#if DEBUG
struct AddTaskMetadataRow_Previews: PreviewProvider {
    @State static var dueDate = Date()
    @State static var reminderTime: Date? = nil
    @State static var isEvening = false

    static var previews: some View {
        VStack(spacing: 16) {
            AddTaskMetadataRow(
                dueDate: $dueDate,
                reminderTime: $reminderTime,
                isEvening: $isEvening
            )

            Text("Due: \(dueDate.formatted(date: .abbreviated, time: .omitted))")
                .font(.tasker(.caption1))
                .foregroundColor(Color.tasker.textTertiary)

            Text("Evening: \(isEvening ? "Yes" : "No")")
                .font(.tasker(.caption1))
                .foregroundColor(Color.tasker.textTertiary)
        }
        .padding()
        .background(Color.tasker.surfacePrimary)
        .previewLayout(.sizeThatFits)
    }
}
#endif
