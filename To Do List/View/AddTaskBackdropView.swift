//
//  AddTaskBackdropView.swift
//  Tasker
//
//  Backdrop layer for Add Task sheet with gradient accent wash and mini calendar.
//

import SwiftUI

// MARK: - Add Task Backdrop View

struct AddTaskBackdropView: View {
    @Binding var selectedDate: Date

    @State private var calendarExpanded = false

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }

    var body: some View {
        VStack(spacing: 0) {
            // Gradient accent wash
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.tasker.accentPrimary.opacity(0.20),
                            Color.tasker.bgCanvas.opacity(0.8)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 180)
                .overlay(alignment: .topLeading) {
                    // Mini calendar strip
                    miniCalendarStrip
                        .padding(.horizontal, spacing.s16)
                        .padding(.top, spacing.s12)
                }

            Spacer(minLength: 0)
        }
        .background(Color.tasker.bgCanvas)
    }

    // MARK: - Mini Calendar Strip

    private var miniCalendarStrip: some View {
        HStack(spacing: spacing.s8) {
            // Week days
            ForEach(weekDays, id: \.self) { date in
                MiniCalendarDay(
                    date: date,
                    isSelected: Calendar.current.isDate(date, inSameDayAs: selectedDate),
                    isToday: Calendar.current.isDateInToday(date)
                ) {
                    TaskerFeedback.selection()
                    selectedDate = date
                }
            }
        }
    }

    private var weekDays: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: today)
        }
    }
}

// MARK: - Mini Calendar Day

struct MiniCalendarDay: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let action: () -> Void

    private var corner: TaskerCornerTokens { TaskerThemeManager.shared.currentTheme.tokens.corner }

    private var dayLetter: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        let dayName = formatter.string(from: date)
        return String(dayName.prefix(1))
    }

    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(dayLetter)
                    .font(.tasker(.caption2))
                    .fontWeight(.medium)

                Text(dayNumber)
                    .font(.tasker(.callout))
                    .fontWeight(isSelected ? .bold : .medium)
            }
            .foregroundColor(isSelected ? Color.tasker.accentOnPrimary : Color.tasker.textSecondary)
            .frame(width: 40, height: 52)
            .background(
                RoundedRectangle(cornerRadius: corner.r2)
                    .fill(isSelected ? Color.tasker.accentPrimary : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: corner.r2)
                    .stroke(isToday && !isSelected ? Color.tasker.accentPrimary : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .scaleOnPress()
    }
}

// MARK: - Preview

#if DEBUG
struct AddTaskBackdropView_Previews: PreviewProvider {
    @State static var selectedDate = Date()

    static var previews: some View {
        AddTaskBackdropView(selectedDate: $selectedDate)
            .previewLayout(.fixed(width: 375, height: 300))
    }
}
#endif
