import SwiftUI

struct LBMeetingFlockCard: View {
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
        let style = LBColorTokens.role(.meeting)
        LBGlassCard(
            cornerRadius: LBRadiusTokens.card,
            borderColor: style.border,
            fill: style.softSurface.opacity(0.58),
            shadow: nil,
            usesMaterialBackground: false
        ) {
            VStack(alignment: .leading, spacing: LBSpacingTokens.sm) {
                HStack {
                    Text(model.timeRange)
                        .font(LBTypographyTokens.bodyStrong)
                        .foregroundStyle(style.deep)
                    Spacer()
                    Text(model.eventCountText)
                        .font(LBTypographyTokens.meta)
                        .foregroundStyle(style.deep)
                        .padding(.horizontal, LBSpacingTokens.sm)
                        .padding(.vertical, 5)
                        .background(style.softSurface, in: Capsule())
                }

                ForEach(model.meetings) { meeting in
                    Button {
                        onTapMeeting(meeting)
                    } label: {
                        HStack(spacing: LBSpacingTokens.sm) {
                            LBIconBadge(systemName: "calendar", role: .meeting, size: 36)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(meeting.title)
                                    .font(LBTypographyTokens.bodyStrong)
                                    .foregroundStyle(LBColorTokens.navy)
                                    .lineLimit(1)
                                Text(meeting.isNow ? "• Now" : meeting.timeText)
                                    .font(LBTypographyTokens.meta)
                                    .foregroundStyle(meeting.isNow ? LBColorTokens.coral : LBColorTokens.navyMuted)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, LBSpacingTokens.sm)
                        .padding(.vertical, LBSpacingTokens.xs)
                        .background(LBColorTokens.glassStrong.opacity(meeting.isNow ? 0.70 : 0.54), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(LBSpacingTokens.md)
        }
    }
}
