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

struct TaskTimeWheelPicker: View {
    @Binding var startDate: Date?

    let durationMinutes: Int
    let defaultStartDate: Date
    let intervalMinutes: Int
    let showsDurationRange: Bool
    let accessibilityLabel: String?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var centeredSlotID: Int?

    private let rowHeight: CGFloat = 44
    private let visibleRows = 5

    init(
        startDate: Binding<Date?>,
        durationMinutes: Int,
        defaultStartDate: Date,
        intervalMinutes: Int,
        showsDurationRange: Bool = true,
        accessibilityLabel: String? = nil
    ) {
        self._startDate = startDate
        self.durationMinutes = durationMinutes
        self.defaultStartDate = defaultStartDate
        self.intervalMinutes = intervalMinutes
        self.showsDurationRange = showsDurationRange
        self.accessibilityLabel = accessibilityLabel
    }

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
            .accessibilityLabel(accessibilityLabel ?? String(localized: "Start time"))
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
        guard isSelected, showsDurationRange else {
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
        guard showsDurationRange else {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
        return TaskDetailViewModel.scheduleRangeAccessibilityLabel(
            start: date,
            end: date.addingTimeInterval(TimeInterval(durationMinutes * 60))
        )
    }
}

enum TimelineAnchorSelection: String, Equatable, Identifiable {
    case wake
    case windDown

    var id: String { rawValue }

    init?(anchorID: String) {
        switch anchorID {
        case "wake":
            self = .wake
        case "sleep":
            self = .windDown
        default:
            return nil
        }
    }

    var title: String {
        switch self {
        case .wake:
            return "Rise and Shine"
        case .windDown:
            return "Wind Down"
        }
    }

    var subtitle: String {
        switch self {
        case .wake:
            return "Choose when your timeline starts."
        case .windDown:
            return "Choose when your timeline closes."
        }
    }

    var systemImageName: String {
        switch self {
        case .wake:
            return "alarm.fill"
        case .windDown:
            return "moon.fill"
        }
    }

    var accessibilityHint: String {
        switch self {
        case .wake:
            return "Edit wake up time"
        case .windDown:
            return "Edit wind down time"
        }
    }

    func date(from preferences: TaskerWorkspacePreferences, calendar: Calendar = .current) -> Date {
        switch self {
        case .wake:
            return Self.date(
                hour: preferences.timelineRiseAndShineHour,
                minute: preferences.timelineRiseAndShineMinute,
                calendar: calendar
            )
        case .windDown:
            return Self.date(
                hour: preferences.timelineWindDownHour,
                minute: preferences.timelineWindDownMinute,
                calendar: calendar
            )
        }
    }

    func save(time: Date, to store: TaskerWorkspacePreferencesStore, calendar: Calendar = .current) {
        let components = calendar.dateComponents([.hour, .minute], from: time)
        store.update { preferences in
            switch self {
            case .wake:
                preferences.timelineRiseAndShineHour = components.hour ?? preferences.timelineRiseAndShineHour
                preferences.timelineRiseAndShineMinute = components.minute ?? preferences.timelineRiseAndShineMinute
            case .windDown:
                preferences.timelineWindDownHour = components.hour ?? preferences.timelineWindDownHour
                preferences.timelineWindDownMinute = components.minute ?? preferences.timelineWindDownMinute
            }
        }
    }

    private static func date(hour: Int, minute: Int, calendar: Calendar) -> Date {
        calendar.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: Date()
        ) ?? Date()
    }
}

struct TimelineAnchorDetailSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTime: Date?

    let selection: TimelineAnchorSelection
    let preferencesStore: TaskerWorkspacePreferencesStore

    init(
        selection: TimelineAnchorSelection,
        preferencesStore: TaskerWorkspacePreferencesStore = .shared
    ) {
        self.selection = selection
        self.preferencesStore = preferencesStore
        let initialTime = selection.date(from: preferencesStore.load())
        self._selectedTime = State(initialValue: initialTime)
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: TaskerTheme.Spacing.lg) {
                topBar
                header
                timeEditor
            }
            .taskerReadableContent(maxWidth: 560, alignment: .center)
            .padding(.bottom, TaskerTheme.Spacing.xxxl)
        }
        .background(Color.tasker.bgCanvas)
        .presentationDragIndicator(.visible)
        .accessibilityIdentifier("timelineAnchorDetail.view")
        .onChange(of: selectedTime) { _, newValue in
            guard let newValue else { return }
            selection.save(time: newValue, to: preferencesStore)
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.tasker.textSecondary)
                    .frame(width: 30, height: 30)
                    .background(Color.tasker.surfaceSecondary)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("timelineAnchorDetail.closeButton")
            .accessibilityLabel("Close timeline anchor details")

            Spacer()
        }
        .padding(.horizontal, TaskerTheme.Spacing.screenHorizontal)
        .padding(.top, TaskerTheme.Spacing.sm)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: TaskerTheme.Spacing.md) {
            Image(systemName: selection.systemImageName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.tasker.accentPrimary)
                .frame(width: 42, height: 42)
                .background(Color.tasker.accentWash, in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: TaskerTheme.Spacing.xs) {
                Text(selection.title)
                    .font(.tasker(.title1))
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.tasker.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(selection.subtitle)
                    .font(.tasker(.callout))
                    .foregroundStyle(Color.tasker.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(currentTimeLabel)
                    .font(.tasker(.meta).weight(.semibold))
                    .foregroundStyle(Color.tasker.textTertiary)
                    .monospacedDigit()
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, TaskerTheme.Spacing.screenHorizontal)
        .padding(.vertical, TaskerTheme.Spacing.md)
        .taskerDenseSurface(
            cornerRadius: TaskerTheme.CornerRadius.card,
            fillColor: Color.tasker.surfacePrimary,
            strokeColor: Color.tasker.strokeHairline.opacity(0.72)
        )
        .padding(.horizontal, TaskerTheme.Spacing.screenHorizontal)
    }

    private var timeEditor: some View {
        TaskTimeWheelPicker(
            startDate: $selectedTime,
            durationMinutes: 30,
            defaultStartDate: selection.date(from: preferencesStore.load()),
            intervalMinutes: TaskDetailViewModel.scheduleIntervalMinutes,
            showsDurationRange: false,
            accessibilityLabel: String(
                format: String(localized: "%@ start time"),
                selection.title
            )
        )
        .accessibilityIdentifier("timelineAnchorDetail.timePicker")
        .padding(.horizontal, TaskerTheme.Spacing.screenHorizontal)
    }

    private var currentTimeLabel: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: selectedTime ?? selection.date(from: preferencesStore.load()))
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
