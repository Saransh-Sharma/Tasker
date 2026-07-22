//
//  TaskScheduleEditor.swift
//  LifeBoard
//
//  Compact task start-time and duration editing controls.
//

import SwiftUI

struct TaskScheduleEditor: View {
    @Binding var startDate: Date?
    @Binding var durationMinutes: Int

    let defaultStartDate: Date

    var body: some View {
        VStack(alignment: .leading, spacing: LifeBoardTheme.Spacing.sm) {
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
    let slotBaseDate: Date?
    let additionalDayCount: Int

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
        accessibilityLabel: String? = nil,
        slotBaseDate: Date? = nil,
        additionalDayCount: Int = 0
    ) {
        self._startDate = startDate
        self.durationMinutes = durationMinutes
        self.defaultStartDate = defaultStartDate
        self.intervalMinutes = intervalMinutes
        self.showsDurationRange = showsDurationRange
        self.accessibilityLabel = accessibilityLabel
        self.slotBaseDate = slotBaseDate
        self.additionalDayCount = additionalDayCount
    }

    var body: some View {
        VStack(alignment: .leading, spacing: LifeBoardTheme.Spacing.xs) {
            Text("Time")
                .font(.lifeboard(.headline).leading(.tight))
                .foregroundStyle(Color.lifeboard.textPrimary)

            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(slots) { slot in
                            timeSlotButton(slot, proxy: proxy)
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
            .padding(.horizontal, LifeBoardTheme.Spacing.sm)
            .padding(.vertical, LifeBoardTheme.Spacing.xs)
            .lifeboardDenseSurface(
                cornerRadius: LifeBoardTheme.CornerRadius.card,
                fillColor: Color.lifeboard.surfacePrimary,
                strokeColor: Color.lifeboard.strokeHairline.opacity(0.72)
            )
            .accessibilityElement(children: .contain)
            .accessibilityLabel(accessibilityLabel ?? String(localized: "Start time"))
            .accessibilityValue(accessibilityLabel(for: selectedSlot))
            .accessibilityAdjustableAction { direction in
                adjustSelection(direction)
            }
        }
    }

    private func timeSlotButton(_ slot: TaskTimeSlot, proxy: ScrollViewProxy) -> some View {
        let isSelected = slot.id == selectedSlotID
        return Button {
            select(slot)
            scroll(to: slot.id, proxy: proxy)
        } label: {
            TimeWheelSlotRow(
                label: label(for: slot, isSelected: isSelected),
                isSelected: isSelected,
                distanceFromSelection: abs(slot.id - selectedSlotID)
            )
        }
        .buttonStyle(.plain)
        .frame(height: rowHeight)
        .id(slot.id)
        .accessibilityLabel(accessibilityLabel(for: slot))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
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

    private var selectedSlot: TaskTimeSlot {
        TaskTimeSlot(
            id: selectedSlotID,
            date: selectedDate,
            timeLabel: nextDaySuffix(for: selectedDate, text: selectedDate.formatted(date: .omitted, time: .shortened))
        )
    }

    private var baseDay: Date {
        Calendar.current.startOfDay(for: slotBaseDate ?? selectedDate)
    }

    private var slotCount: Int {
        let slotsPerDay = (24 * 60) / max(1, intervalMinutes)
        return slotsPerDay * (1 + max(0, additionalDayCount))
    }

    private var slots: [TaskTimeSlot] {
        let baseDay = baseDay
        let calendar = Calendar.current
        return (0..<slotCount).compactMap { index in
            guard let date = calendar.date(byAdding: .minute, value: index * intervalMinutes, to: baseDay) else {
                return nil
            }
            return TaskTimeSlot(
                id: index,
                date: date,
                timeLabel: nextDaySuffix(for: date, text: date.formatted(date: .omitted, time: .shortened))
            )
        }
    }

    private func select(_ slot: TaskTimeSlot) {
        guard TaskDetailViewModel.roundedToNearestScheduleSlot(slot.date, intervalMinutes: intervalMinutes) != startDate else {
            return
        }
        LifeBoardFeedback.selection()
        withAnimation(reduceMotion ? nil : LifeBoardAnimation.snappy) {
            startDate = slot.date
        }
    }

    private func adjustSelection(_ direction: AccessibilityAdjustmentDirection) {
        let currentID = selectedSlotID
        let nextID: Int
        switch direction {
        case .increment:
            nextID = min(slotCount - 1, currentID + 1)
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
        withAnimation(reduceMotion ? nil : LifeBoardAnimation.snappy) {
            proxy.scrollTo(id, anchor: .center)
        }
    }

    private func slotID(for date: Date) -> Int {
        let rounded = TaskDetailViewModel.roundedToNearestScheduleSlot(date, intervalMinutes: intervalMinutes)
        let minutes = Calendar.current.dateComponents([.minute], from: baseDay, to: rounded).minute ?? 0
        return min(max(0, minutes / max(1, intervalMinutes)), slotCount - 1)
    }

    private func label(for slot: TaskTimeSlot, isSelected: Bool) -> String {
        guard isSelected, showsDurationRange else {
            return slot.timeLabel
        }
        return TaskDetailViewModel.scheduleRangeLabel(
            start: slot.date,
            end: slot.date.addingTimeInterval(TimeInterval(durationMinutes * 60))
        )
    }

    private func accessibilityLabel(for slot: TaskTimeSlot) -> String {
        guard showsDurationRange else {
            return slot.timeLabel
        }
        return TaskDetailViewModel.scheduleRangeAccessibilityLabel(
            start: slot.date,
            end: slot.date.addingTimeInterval(TimeInterval(durationMinutes * 60))
        )
    }

    private func nextDaySuffix(for date: Date, text: String) -> String {
        guard additionalDayCount > 0, !Calendar.current.isDate(date, inSameDayAs: baseDay) else {
            return text
        }
        return "\(text) next day"
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

    func date(from preferences: LifeBoardWorkspacePreferences, calendar: Calendar = .current) -> Date {
        switch self {
        case .wake:
            return Self.date(
                hour: preferences.timelineRiseAndShineHour,
                minute: preferences.timelineRiseAndShineMinute,
                calendar: calendar
            )
        case .windDown:
            let wake = Self.date(
                hour: preferences.timelineRiseAndShineHour,
                minute: preferences.timelineRiseAndShineMinute,
                calendar: calendar
            )
            var windDown = Self.date(
                hour: preferences.timelineWindDownHour,
                minute: preferences.timelineWindDownMinute,
                calendar: calendar
            )
            if windDown <= wake {
                windDown = calendar.date(byAdding: .day, value: 1, to: windDown) ?? windDown
            }
            return windDown
        }
    }

    func slotBaseDate(from preferences: LifeBoardWorkspacePreferences, calendar: Calendar = .current) -> Date {
        switch self {
        case .wake:
            return calendar.startOfDay(for: date(from: preferences, calendar: calendar))
        case .windDown:
            let wake = Self.date(
                hour: preferences.timelineRiseAndShineHour,
                minute: preferences.timelineRiseAndShineMinute,
                calendar: calendar
            )
            return calendar.startOfDay(for: wake)
        }
    }

    func save(time: Date, to store: LifeBoardWorkspacePreferencesStore, calendar: Calendar = .current) {
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

struct TimelineAnchorDraft {
    private struct PersistedTime: Equatable {
        let hour: Int
        let minute: Int

        var minutesSinceMidnight: Int {
            hour * 60 + minute
        }
    }

    private let initialRiseAndShine: PersistedTime
    private let initialWindDown: PersistedTime
    private let calendar: Calendar

    var riseAndShine: Date
    var windDown: Date

    init(preferences: LifeBoardWorkspacePreferences, calendar: Calendar = .current) {
        self.calendar = calendar
        self.initialRiseAndShine = PersistedTime(
            hour: max(0, min(23, preferences.timelineRiseAndShineHour)),
            minute: max(0, min(59, preferences.timelineRiseAndShineMinute))
        )
        self.initialWindDown = PersistedTime(
            hour: max(0, min(23, preferences.timelineWindDownHour)),
            minute: max(0, min(59, preferences.timelineWindDownMinute))
        )
        self.riseAndShine = TimelineAnchorSelection.wake.date(from: preferences, calendar: calendar)
        self.windDown = TimelineAnchorSelection.windDown.date(from: preferences, calendar: calendar)
    }

    var hasChanges: Bool {
        hasChanges(for: .wake) || hasChanges(for: .windDown)
    }

    var windDownOccursNextDay: Bool {
        persistedTime(for: windDown).minutesSinceMidnight <= persistedTime(for: riseAndShine).minutesSinceMidnight
    }

    func time(for selection: TimelineAnchorSelection) -> Date {
        switch selection {
        case .wake:
            return riseAndShine
        case .windDown:
            return windDown
        }
    }

    mutating func setTime(_ time: Date, for selection: TimelineAnchorSelection) {
        switch selection {
        case .wake:
            riseAndShine = time
        case .windDown:
            windDown = time
        }
    }

    func hasChanges(for selection: TimelineAnchorSelection) -> Bool {
        persistedTime(for: time(for: selection)) != initialTime(for: selection)
    }

    func commitIfNeeded(for selection: TimelineAnchorSelection, to store: LifeBoardWorkspacePreferencesStore) {
        guard hasChanges(for: selection) else { return }
        selection.save(time: time(for: selection), to: store, calendar: calendar)
    }

    func apply(to preferences: inout LifeBoardWorkspacePreferences) {
        let persistedRiseAndShine = persistedTime(for: riseAndShine)
        preferences.timelineRiseAndShineHour = persistedRiseAndShine.hour
        preferences.timelineRiseAndShineMinute = persistedRiseAndShine.minute

        let persistedWindDown = persistedTime(for: windDown)
        preferences.timelineWindDownHour = persistedWindDown.hour
        preferences.timelineWindDownMinute = persistedWindDown.minute
    }

    private func initialTime(for selection: TimelineAnchorSelection) -> PersistedTime {
        switch selection {
        case .wake:
            return initialRiseAndShine
        case .windDown:
            return initialWindDown
        }
    }

    private func persistedTime(for date: Date) -> PersistedTime {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return PersistedTime(
            hour: max(0, min(23, components.hour ?? 0)),
            minute: max(0, min(59, components.minute ?? 0))
        )
    }
}

struct TimelineAnchorDetailSheetView: View {
    let selection: TimelineAnchorSelection
    let preferencesStore: LifeBoardWorkspacePreferencesStore

    init(
        selection: TimelineAnchorSelection,
        preferencesStore: LifeBoardWorkspacePreferencesStore = .shared
    ) {
        self.selection = selection
        self.preferencesStore = preferencesStore
    }

    var body: some View {
        TimelineAnchorRitualSheetView(
            selection: selection,
            preferencesStore: preferencesStore
        )
    }
}

private struct TaskTimeSlot: Identifiable {
    let id: Int
    let date: Date
    let timeLabel: String
}

private struct TimeWheelSlotRow: View {
    let label: String
    let isSelected: Bool
    let distanceFromSelection: Int

    var body: some View {
        Text(label)
            .font(.lifeboard(isSelected ? .headline : .bodyEmphasis))
            .fontWeight(isSelected ? .semibold : .regular)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .foregroundStyle(isSelected ? Color.lifeboard(.accentOnPrimary) : Color.lifeboard.textSecondary.opacity(opacity))
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, LifeBoardTheme.Spacing.md)
            .background(
                Capsule()
                    .fill(isSelected ? Color.lifeboard.accentPrimary : Color.clear)
            )
            .padding(.horizontal, LifeBoardTheme.Spacing.xl)
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
        VStack(alignment: .leading, spacing: LifeBoardTheme.Spacing.xs) {
            Text("Duration")
                .font(.lifeboard(.headline).leading(.tight))
                .foregroundStyle(Color.lifeboard.textPrimary)

            HStack(spacing: 4) {
                ForEach(options, id: \.minutes) { option in
                    Button {
                        select(option.minutes)
                    } label: {
                        Text(option.label)
                            .font(.lifeboard(.callout).weight(option.minutes == durationMinutes ? .semibold : .regular))
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                            .foregroundStyle(option.minutes == durationMinutes ? Color.lifeboard(.accentOnPrimary) : Color.lifeboard.textSecondary)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(
                                Capsule()
                                    .fill(option.minutes == durationMinutes ? Color.lifeboard.accentPrimary : Color.clear)
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
            .lifeboardDenseSurface(
                cornerRadius: LifeBoardTheme.CornerRadius.card,
                fillColor: Color.lifeboard.surfacePrimary,
                strokeColor: Color.lifeboard.strokeHairline.opacity(0.72)
            )
            .animation(reduceMotion ? nil : LifeBoardAnimation.snappy, value: durationMinutes)
        }
    }

    private func select(_ minutes: Int) {
        guard durationMinutes != minutes else { return }
        LifeBoardFeedback.selection()
        withAnimation(reduceMotion ? nil : LifeBoardAnimation.snappy) {
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
