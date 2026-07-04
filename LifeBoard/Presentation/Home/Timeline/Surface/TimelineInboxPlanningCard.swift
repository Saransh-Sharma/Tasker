import SwiftUI

struct TimelineInboxPlanningCard: View {
    let inboxItems: [TimelinePlanItem]
    let onTaskTap: (TimelinePlanItem) -> Void

    var body: some View {
        let style = LBColorTokens.role(.assistant)
        LBGlassCard(
            cornerRadius: LBRadiusTokens.card,
            borderColor: style.border.opacity(0.78),
            fill: style.softSurface.opacity(0.56),
            shadow: nil,
            usesMaterialBackground: false
        ) {
            VStack(alignment: .leading, spacing: LBSpacingTokens.sm) {
                HStack(alignment: .top, spacing: LBSpacingTokens.sm) {
                    Image(systemName: "tray.full")
                        .font(LBTypographyTokens.bodyStrong)
                        .foregroundStyle(style.deep)
                        .frame(width: 34, height: 34)
                        .background(style.softSurface.opacity(0.82), in: Circle())
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(inboxItems.count == 1 ? "1 inbox task ready" : "\(inboxItems.count) inbox tasks ready")
                            .font(LBTypographyTokens.meta)
                            .foregroundStyle(LBColorTokens.navyMuted)
                        Text("Inbox waiting for placement")
                            .font(LBTypographyTokens.cardTitle)
                            .foregroundStyle(LBColorTokens.navy)
                        Text("Day Compass will offer a placement pass when enough unscheduled work needs a home.")
                            .font(LBTypographyTokens.body)
                            .foregroundStyle(LBColorTokens.navyMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(inboxItems.prefix(4)) { item in
                            Button {
                                onTaskTap(item)
                            } label: {
                                Text(item.title)
                                    .font(LBTypographyTokens.meta)
                                    .foregroundStyle(LBColorTokens.navy)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 9)
                                    .background(LBColorTokens.glassStrong.opacity(0.72), in: Capsule())
                                    .overlay {
                                        Capsule()
                                            .stroke(LBColorTokens.hairline.opacity(0.7), lineWidth: 1)
                                    }
                            }
                            .buttonStyle(.plain)
                        }

                        if inboxItems.count > 4 {
                            Text("+\(inboxItems.count - 4) more")
                                .font(LBTypographyTokens.meta)
                                .foregroundStyle(LBColorTokens.navyMuted)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .background(LBColorTokens.glassStrong.opacity(0.72), in: Capsule())
                                .accessibilityLabel("\(inboxItems.count - 4) more inbox tasks")
                        }
                    }
                    .padding(.trailing, 4)
                }
                .accessibilityLabel("Inbox task previews")
                .accessibilityHint(inboxItems.count > 4 ? "Scroll horizontally to inspect more inbox tasks." : "Swipe through inbox tasks to inspect them.")
            }
            .padding(LBSpacingTokens.md)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.timeline.inboxShelf")
    }
}
