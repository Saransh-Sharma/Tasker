import SwiftUI

struct TimelineBackdropWeekView: View {
    let snapshot: HomeTimelineSnapshot
    let onSelectDate: (Date) -> Void
    let onStartReplanForDate: (Date) -> Void
    let onPlaceReplanAllDay: (TimelinePlacementCandidate, Date) -> Void

    @Environment(\.dynamicTypeSize) var dynamicTypeSize

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            ForEach(snapshot.week.days) { day in
                TimelineWeekDayCell(
                    day: day,
                    isSelected: Calendar.current.isDate(day.date, inSameDayAs: snapshot.selectedDate),
                    isAccessibilityLayout: dynamicTypeSize.isAccessibilitySize,
                    action: {
                        onSelectDate(day.date)
                    },
                    onStartReplan: {
                        onStartReplanForDate(day.date)
                    },
                    placementCandidate: snapshot.placementCandidate,
                    onDropPlacement: { candidate in
                        onPlaceReplanAllDay(candidate, day.date)
                    }
                )
            }
        }
        .padding(.top, 4)
        .reportHeight(to: TimelineBackdropWeekHeightPreferenceKey.self)
        .accessibilityIdentifier("home.weeklyCalendar")
    }
}
