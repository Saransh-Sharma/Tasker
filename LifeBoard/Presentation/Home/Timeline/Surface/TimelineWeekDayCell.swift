import SwiftUI

struct TimelineWeekDayCell: View {
    let day: TimelineWeekDaySummary
    let isSelected: Bool
    let isAccessibilityLayout: Bool
    let action: () -> Void
    let onStartReplan: () -> Void
    let placementCandidate: TimelinePlacementCandidate?
    let onDropPlacement: (TimelinePlacementCandidate) -> Void

    @State var isDropTargeted = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var paletteColor: Color {
        switch day.loadLevel {
        case .light:
            return Color.lifeboard.statusSuccess
        case .balanced:
            return Color.lifeboard.accentPrimary
        case .busy:
            return Color.lifeboard.statusWarning
        }
    }

    var body: some View {
        VStack(spacing: isAccessibilityLayout ? 8 : 6) {
            Button(action: action) {
                dayContent
            }
            .buttonStyle(.plain)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityValue(isSelected ? "Selected" : "Not selected")
            .accessibilityHint("Switches the daily timeline to this date.")
            .accessibilityAddTraits(.isButton)
            .accessibilityAddTraits(isSelected ? .isSelected : AccessibilityTraits())

            if canStartReplan {
                Button(action: onStartReplan) {
                    Label(replanActionTitle, systemImage: "arrow.triangle.2.circlepath")
                        .font(.lifeboard(.support).weight(.semibold))
                        .foregroundStyle(Color.lifeboard.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .padding(.horizontal, 10)
                        .frame(minHeight: 44)
                        .background(Color.lifeboard.accentWash.opacity(0.72), in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(replanAccessibilityLabel)
                .accessibilityHint("Starts Plan the Day for this past date.")
            }
        }
        .frame(maxWidth: .infinity, minHeight: isAccessibilityLayout ? 176 : 152, alignment: .top)
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(isDropTargeted ? Color.lifeboard.accentWash.opacity(0.86) : (isSelected ? Color.lifeboard.surfacePrimary : Color.lifeboard.surfacePrimary.opacity(0.85)))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(isDropTargeted ? Color.lifeboard.accentPrimary.opacity(0.48) : (isSelected ? Color.lifeboard.accentPrimary.opacity(0.25) : Color.lifeboard.strokeHairline.opacity(0.45)), lineWidth: isDropTargeted ? 1.5 : 1)
        )
        .overlay(alignment: .bottom) {
            if placementCandidate != nil {
                Label(isDropTargeted ? "Release" : "Drop", systemImage: isDropTargeted ? "calendar.badge.checkmark" : "calendar.badge.plus")
                    .font(.lifeboard(.caption2).weight(.semibold))
                    .foregroundStyle(Color.lifeboard.accentPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.lifeboard.surfacePrimary.opacity(0.88), in: Capsule())
                    .opacity(isDropTargeted ? 1 : 0.72)
                    .padding(.bottom, 6)
                    .accessibilityIdentifier("home.needsReplan.hotZone.day.\(day.id)")
            }
        }
        .scaleEffect(isDropTargeted && reduceMotion == false ? 1.018 : 1)
        .contextMenu {
            if canStartReplan {
                Button(replanAccessibilityLabel, systemImage: "arrow.triangle.2.circlepath") {
                    onStartReplan()
                }
            }
        }
        .accessibilityAction(named: Text(replanAccessibilityLabel)) {
            if canStartReplan {
                onStartReplan()
            }
        }
        .dropDestination(for: String.self, action: { items, _ in
            guard let placementCandidate,
                  items.contains(placementCandidate.taskID.uuidString) else {
                return false
            }
            LifeBoardFeedback.success()
            onDropPlacement(placementCandidate)
            return true
        }, isTargeted: { newValue in
            isDropTargeted = newValue
        })
        .onChange(of: isDropTargeted) { _, newValue in
            guard newValue else { return }
            LifeBoardFeedback.selection()
        }
    }

    var dayContent: some View {
        VStack(spacing: isAccessibilityLayout ? 8 : 6) {
                Text(day.date.formatted(.dateTime.weekday(.narrow)))
                    .font(.lifeboard(.meta))
                    .foregroundStyle(Color.lifeboard.textSecondary)

                ZStack {
                    Circle()
                        .fill(isSelected ? Color.lifeboard.accentPrimary : Color.lifeboard.surfaceSecondary)
                        .frame(width: 44, height: 44)
                    Text(day.date.formatted(.dateTime.day()))
                        .font(.lifeboard(.headline))
                        .foregroundStyle(isSelected ? Color.lifeboard.accentOnPrimary : Color.lifeboard.textPrimary)
                }

                Text(day.summaryText)
                    .font(.lifeboard(isAccessibilityLayout ? .caption1 : .meta).weight(.semibold))
                    .foregroundStyle(isSelected ? Color.lifeboard.textPrimary : paletteColor)
                    .lineLimit(isAccessibilityLayout ? 2 : 1)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                HStack(spacing: 4) {
                    ForEach(Array(day.tintHexes.prefix(3).enumerated()), id: \.offset) { entry in
                        Circle()
                            .fill(Color(uiColor: UIColor(lifeboardHex: entry.element)).opacity(0.88))
                            .frame(width: 7, height: 7)
                            .accessibilityHidden(true)
                    }
                    if day.allDayCount > 0 {
                        Text("\(day.allDayCount)")
                            .font(.lifeboard(.caption2).weight(.semibold))
                            .foregroundStyle(Color.lifeboard.textSecondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.lifeboard.surfaceSecondary, in: Capsule())
                    }
                }
                .frame(minHeight: 12)
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    var accessibilityLabel: String {
        let allDayText = day.allDayCount > 0 ? ", \(day.allDayCount) all-day items" : ""
        let replanText = day.replanEligibleCount > 0 ? ", \(day.replanEligibleCount) needs replan" : ""
        return "\(day.date.formatted(.dateTime.weekday(.wide).day().month())), \(day.summaryText)\(allDayText)\(replanText)"
    }

    var canStartReplan: Bool {
        let calendar = Calendar.current
        return day.replanEligibleCount > 0
            && calendar.startOfDay(for: day.date) < calendar.startOfDay(for: Date())
    }

    var replanActionTitle: String {
        day.replanEligibleCount == 1 ? "Replan 1 task" : "Replan \(day.replanEligibleCount) tasks"
    }

    var replanAccessibilityLabel: String {
        day.replanEligibleCount == 1 ? "Replan 1 task" : "Replan \(day.replanEligibleCount) tasks"
    }
}
