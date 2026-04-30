//
//  TaskScheduleEditor.swift
//  Tasker
//
//  Compact task start-time and duration editing controls.
//

import SwiftUI

struct TaskScheduleEditor: View {
    @Binding var startDate: Date?
    @Binding var durationMinutes: Int

    let defaultStartDate: Date

    var body: some View {
        VStack(alignment: .leading, spacing: TaskerTheme.Spacing.sm) {
            TaskTimeWheelPicker(
                startDate: $startDate,
                durationMinutes: durationMinutes,
                defaultStartDate: defaultStartDate,
                intervalMinutes: TaskDetailViewModel.scheduleIntervalMinutes
            )

            TaskDurationSegmentedPicker(durationMinutes: $durationMinutes)
        }
    }
}

private struct TaskTimeWheelPicker: View {
    @Binding var startDate: Date?

    let durationMinutes: Int
    let defaultStartDate: Date
    let intervalMinutes: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var centeredSlotID: Int?

    private let rowHeight: CGFloat = 44
    private let visibleRows = 5

    var body: some View {
        VStack(alignment: .leading, spacing: TaskerTheme.Spacing.xs) {
            Text("Time")
                .font(.tasker(.headline).leading(.tight))
                .foregroundStyle(Color.tasker.textPrimary)

            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(slots) { slot in
                            Button {
                                select(slot)
                                scroll(to: slot.id, proxy: proxy)
                            } label: {
                                TimeWheelSlotRow(
                                    label: label(for: slot.date, isSelected: slot.id == selectedSlotID),
                                    isSelected: slot.id == selectedSlotID,
                                    distanceFromSelection: abs(slot.id - selectedSlotID)
                                )
                            }
                            .buttonStyle(.plain)
                            .frame(height: rowHeight)
                            .id(slot.id)
                            .accessibilityLabel(accessibilityLabel(for: slot.date))
                            .accessibilityAddTraits(slot.id == selectedSlotID ? [.isSelected] : [])
                        }
                    }
                    .scrollTargetLayout()
                }
                .frame(height: rowHeight * CGFloat(visibleRows))
                .contentMargins(.vertical, rowHeight * CGFloat((visibleRows - 1) / 2), for: .scrollContent)
                .scrollTargetBehavior(.viewAligned)
                .scrollPosition(id: $centeredSlotID, anchor: .center)
                .onAppear {
                    let initialID = selectedSlotID
                    centeredSlotID = initialID
                    DispatchQueue.main.async {
                        proxy.scrollTo(initialID, anchor: .center)
                    }
                }
                // selectedSlotID drives centeredSlotID and scroll(to:proxy:); centeredSlotID resolves select(slot). The guards prevent that bidirectional sync from feeding back into itself.
                .onChange(of: selectedSlotID) { _, newValue in
                    guard centeredSlotID != newValue else { return }
                    centeredSlotID = newValue
                    scroll(to: newValue, proxy: proxy)
                }
                .onChange(of: centeredSlotID) { _, newValue in
                    guard let newValue, newValue != selectedSlotID else { return }
                    guard let slot = slots.first(where: { $0.id == newValue }) else { return }
                    select(slot)
                }
            }
            .padding(.horizontal, TaskerTheme.Spacing.sm)
            .padding(.vertical, TaskerTheme.Spacing.xs)
            .taskerDenseSurface(
                cornerRadius: TaskerTheme.CornerRadius.card,
                fillColor: Color.tasker.surfacePrimary,
                strokeColor: Color.tasker.strokeHairline.opacity(0.72)
            )
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Start time")
            .accessibilityValue(accessibilityLabel(for: selectedDate))
            .accessibilityAdjustableAction { direction in
                adjustSelection(direction)
            }
        }
    }

    private var selectedDate: Date {
        TaskDetailViewModel.roundedToNearestScheduleSlot(
            startDate ?? defaultStartDate,
            intervalMinutes: intervalMinutes
        )
    }

    private var selectedSlotID: Int {
        slotID(for: selectedDate)
    }

    private var baseDay: Date {
        Calendar.current.startOfDay(for: selectedDate)
    }

    private var slots: [TaskTimeSlot] {
        let slotsPerDay = (24 * 60) / max(1, intervalMinutes)
        return (0..<slotsPerDay).compactMap { index in
            guard let date = Calendar.current.date(byAdding: .minute, value: index * intervalMinutes, to: baseDay) else {
                return nil
            }
            return TaskTimeSlot(id: index, date: date)
        }
    }

    private func select(_ slot: TaskTimeSlot) {
        guard TaskDetailViewModel.roundedToNearestScheduleSlot(slot.date, intervalMinutes: intervalMinutes) != startDate else {
            return
        }
        TaskerFeedback.selection()
        withAnimation(reduceMotion ? nil : TaskerAnimation.snappy) {
            startDate = slot.date
        }
    }

    private func adjustSelection(_ direction: AccessibilityAdjustmentDirection) {
        let currentID = selectedSlotID
        let nextID: Int
        switch direction {
        case .increment:
            nextID = min(slots.count - 1, currentID + 1)
        case .decrement:
            nextID = max(0, currentID - 1)
        @unknown default:
            return
        }
        guard let slot = slots.first(where: { $0.id == nextID }) else { return }
        select(slot)
        centeredSlotID = nextID
    }

    private func scroll(to id: Int, proxy: ScrollViewProxy) {
        withAnimation(reduceMotion ? nil : TaskerAnimation.snappy) {
            proxy.scrollTo(id, anchor: .center)
        }
    }

    private func slotID(for date: Date) -> Int {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        let minutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        let slotCount = slots.count
        return min(max(0, minutes / max(1, intervalMinutes)), slotCount - 1)
    }

    private func label(for date: Date, isSelected: Bool) -> String {
        guard isSelected else {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
        return TaskDetailViewModel.scheduleRangeLabel(
            start: date,
            end: date.addingTimeInterval(TimeInterval(durationMinutes * 60))
        )
    }

    private func accessibilityLabel(for date: Date) -> String {
        TaskDetailViewModel.scheduleRangeAccessibilityLabel(
            start: date,
            end: date.addingTimeInterval(TimeInterval(durationMinutes * 60))
        )
    }
}

private struct TaskTimeSlot: Identifiable {
    let id: Int
    let date: Date
}

private struct TimeWheelSlotRow: View {
    let label: String
    let isSelected: Bool
    let distanceFromSelection: Int

    var body: some View {
        Text(label)
            .font(.tasker(isSelected ? .headline : .bodyEmphasis))
            .fontWeight(isSelected ? .semibold : .regular)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .foregroundStyle(isSelected ? Color.white : Color.tasker.textSecondary.opacity(opacity))
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, TaskerTheme.Spacing.md)
            .background(
                Capsule()
                    .fill(isSelected ? Color.tasker.accentPrimary : Color.clear)
            )
            .padding(.horizontal, TaskerTheme.Spacing.xl)
    }

    private var opacity: Double {
        switch distanceFromSelection {
        case 0:
            return 1
        case 1:
            return 0.78
        case 2:
            return 0.42
        default:
            return 0.22
        }
    }
}

private struct TaskDurationSegmentedPicker: View {
    @Binding var durationMinutes: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let options: [(label: String, minutes: Int)] = [
        ("15m", 15),
        ("30m", 30),
        ("45m", 45),
        ("1h", 60),
        ("1.5h", 90),
        ("2h", 120),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: TaskerTheme.Spacing.xs) {
            Text("Duration")
                .font(.tasker(.headline).leading(.tight))
                .foregroundStyle(Color.tasker.textPrimary)

            HStack(spacing: 4) {
                ForEach(options, id: \.minutes) { option in
                    Button {
                        select(option.minutes)
                    } label: {
                        Text(option.label)
                            .font(.tasker(.callout).weight(option.minutes == durationMinutes ? .semibold : .regular))
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                            .foregroundStyle(option.minutes == durationMinutes ? Color.white : Color.tasker.textSecondary)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(
                                Capsule()
                                    .fill(option.minutes == durationMinutes ? Color.tasker.accentPrimary : Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Duration")
                    .accessibilityValue(accessibilityValue(for: option.minutes))
                    .accessibilityAddTraits(option.minutes == durationMinutes ? [.isSelected] : [])
                    .accessibilityIdentifier("taskDetail.duration.\(option.minutes)")
                }
            }
            .padding(4)
            .taskerDenseSurface(
                cornerRadius: TaskerTheme.CornerRadius.card,
                fillColor: Color.tasker.surfacePrimary,
                strokeColor: Color.tasker.strokeHairline.opacity(0.72)
            )
            .animation(reduceMotion ? nil : TaskerAnimation.snappy, value: durationMinutes)
        }
    }

    private func select(_ minutes: Int) {
        guard durationMinutes != minutes else { return }
        TaskerFeedback.selection()
        withAnimation(reduceMotion ? nil : TaskerAnimation.snappy) {
            durationMinutes = minutes
        }
    }

    private func accessibilityValue(for minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes) minutes"
        }
        if minutes == 90 {
            return "1 hour 30 minutes"
        }
        return "\(minutes / 60) hours"
    }
}
