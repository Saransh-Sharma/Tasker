//
//  AddTaskMetadataRow.swift
//  LifeBoard
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 8) {
            // Reminder toggle chip
            AddTaskMetadataChip(
                icon: hasReminder ? "bell.fill" : "bell",
                text: hasReminder ? formatTime(reminderTime) : "Reminder",
                isActive: hasReminder
            ) {
                if hasReminder {
                    withAnimation(MotionProfile.press.animation(reduceMotion: reduceMotion)) {
                        hasReminder = false
                    }
                    Haptic.pick.play()
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

    /// The person's own clock: "3:00 PM" or "15:00".
    private func formatTime(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }
}

// MARK: - Time Picker Sheet

struct AddTaskTimePickerSheet: View {
    @Binding var reminderTime: Date
    @Binding var hasReminder: Bool
    @Binding var isPresented: Bool
    @Environment(\.lifeboardLayoutClass) private var layoutClass
    @Environment(\.lifeboardTokens) private var tokens

    @State private var selectedTime = Date()

    private var spacing: SemanticSpacingTokens { ThemeStore.shared.currentTheme.tokens.spacing }
    private var corner: CornerTokens { ThemeStore.shared.currentTheme.tokens.corner }

    var body: some View {
        NavigationStack {
            VStack(spacing: spacing.s20) {
                // Quick preset row
                HStack(spacing: spacing.s8) {
                    ForEach(ReminderPreset.allCases, id: \.self) { preset in
                        Button {
                            Haptic.pick.play()
                            selectedTime = preset.date
                        } label: {
                            Text(preset.label)
                                .font(.lifeboard(.callout))
                                .foregroundColor(Color.lifeboard.textSecondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(Color.lifeboard.surfaceSecondary)
                                )
                        }
                        .buttonStyle(.plain)
                        .scaleOnPress()
                    }
                }
                .padding(.horizontal, spacing.s16)

                DatePicker(
                    "Reminder time",
                    selection: $selectedTime,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.wheel)
                .padding(.horizontal, spacing.s16)

                Button {
                    reminderTime = selectedTime
                    hasReminder = true
                    Haptic.pick.play()
                    isPresented = false
                } label: {
                    Text("Set reminder")
                        .font(.lifeboard(.button))
                        .foregroundColor(Color.lifeboard.accentOnPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: spacing.buttonHeight)
                        .background(
                            RoundedRectangle(cornerRadius: corner.r2)
                                .fill(Color.lifeboard.accentPrimary)
                        )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, spacing.s16)
            }
            .lifeboardReadableContent(maxWidth: 460, alignment: .center)
            .navigationTitle("Set reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .keyboardShortcut(.cancelAction)
                }
            }
        }
        // Not a fixed height: at large text the wheel and presets clipped.
        .presentationDetents([.medium, .large])
        .onAppear {
            selectedTime = reminderTime
        }
    }
}

// MARK: - Reminder Presets

enum ReminderPreset: CaseIterable {
    case morning, noon, afternoon, evening

    /// "9 AM" or "09", in the person's 12- or 24-hour setting.
    var label: String {
        date.formatted(.dateTime.hour())
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
