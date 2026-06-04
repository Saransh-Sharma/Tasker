import SwiftUI

struct TimelineMeetingBlockRow: View {
    let item: TimelinePlanItem
    let row: TimelineRenderableRow
    let isNested: Bool
    let action: () -> Void

    var palette: TimelinePalette { .resolve(from: item.tintHex) }
    var accessibilityKind: String { item.isMeetingLike ? "Meeting" : "Calendar" }
    var iconName: String { item.isMeetingLike ? "person.3.fill" : "calendar" }

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: isNested ? 10 : 11) {
                Circle()
                    .fill(palette.fill.opacity(0.92))
                    .frame(width: isNested ? 34 : 38, height: isNested ? 34 : 38)
                    .overlay {
                        Image(systemName: iconName)
                            .font(.system(size: isNested ? 14 : 15, weight: .semibold))
                            .foregroundStyle(palette.icon)
                            .accessibilityHidden(true)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.lifeboard(.headline).weight(.semibold))
                        .foregroundStyle(Color.lifeboard.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .layoutPriority(2)

                    Text(meetingMetadata)
                        .font(.lifeboard(.support))
                        .foregroundStyle(Color.lifeboard.textSecondary)
                        .lineLimit(1)
                        .layoutPriority(1)
                }
                .layoutPriority(2)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, isNested ? 10 : 11)
            .padding(.vertical, isNested ? 8 : 9)
            .background(Color.lifeboard.surfacePrimary.opacity(0.96), in: RoundedRectangle(cornerRadius: isNested ? 12 : 14, style: .continuous))
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(palette.progress.opacity(0.78))
                    .frame(width: 3)
                    .padding(.vertical, 8)
            }
            .overlay {
                RoundedRectangle(cornerRadius: isNested ? 12 : 14, style: .continuous)
                    .stroke(Color.lifeboard.strokeHairline.opacity(0.68), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.title), \(meetingMetadata)")
        .accessibilityValue(accessibilityKind)
        .accessibilityHint("Opens the calendar item.")
        .accessibilityIdentifier(timelineAccessibilityIdentifier(for: item))
    }

    var meetingMetadata: String {
        if let start = item.startDate, let end = item.endDate {
            return TimelineFormatting.timeRangeText(start: start, end: end)
        }
        return ""
    }
}
