import SwiftUI

struct MeetingFlockCard: View {
    struct Meeting: Identifiable, Equatable {
        let id: String
        let title: String
        let timeText: String
        let isNow: Bool
    }

    struct Model: Identifiable, Equatable {
        let id: String
        let timeRange: String
        let meetings: [Meeting]
        let eventCountText: String
    }

    let model: Model
    let onTapMeeting: (Meeting) -> Void

    var body: some View {
        let style = ClayColorTokens.role(.meeting)
        GlassCard(
            cornerRadius: RadiusTokens.card,
            borderColor: style.border,
            fill: style.softSurface.opacity(0.58),
            shadow: nil,
            usesMaterialBackground: false
        ) {
            VStack(alignment: .leading, spacing: ClayLayoutMetrics.sm) {
                HStack {
                    Text(model.timeRange)
                        .font(ClayTypography.bodyStrong)
                        .foregroundStyle(style.deep)
                    Spacer()
                    Text(model.eventCountText)
                        .font(ClayTypography.meta)
                        .foregroundStyle(style.deep)
                        .padding(.horizontal, ClayLayoutMetrics.sm)
                        .padding(.vertical, 5)
                        .background(style.softSurface, in: Capsule())
                }

                ForEach(model.meetings) { meeting in
                    Button {
                        onTapMeeting(meeting)
                    } label: {
                        HStack(spacing: ClayLayoutMetrics.sm) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(meeting.title)
                                    .font(ClayTypography.bodyStrong)
                                    .foregroundStyle(ClayColorTokens.navy)
                                    .lineLimit(1)
                                Text(meeting.isNow ? "• Now" : meeting.timeText)
                                    .font(ClayTypography.meta)
                                    .foregroundStyle(meeting.isNow ? ClayColorTokens.coral : ClayColorTokens.navyMuted)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, ClayLayoutMetrics.sm)
                        .padding(.vertical, ClayLayoutMetrics.xs)
                        .background(ClayColorTokens.glassStrong.opacity(meeting.isNow ? 0.70 : 0.54), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Meeting, \(meeting.title), \(meeting.isNow ? "Now" : meeting.timeText)")
                }
            }
            .padding(ClayLayoutMetrics.md)
        }
    }
}
