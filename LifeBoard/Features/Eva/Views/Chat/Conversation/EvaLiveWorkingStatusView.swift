//
//  ConversationView.swift
//

import MarkdownUI
import SwiftUI

struct EvaLiveWorkingStatusView: View {
    let statuses: [String]

    @State private var startedAt = Date()

    var body: some View {
        TimelineView(.periodic(from: startedAt, by: EvaWorkingStatusLibrary.rotationInterval)) { context in
            let elapsed = max(0, context.date.timeIntervalSince(startedAt))
            let status = EvaWorkingStatusLibrary.status(in: statuses, elapsed: elapsed)
            let isSlow = elapsed >= EvaWorkingStatusLibrary.slowTurnThreshold
            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
                ProgressView()
                    .controlSize(.small)
                    .tint(EvaChatSunriseGlass.primary)
                VStack(alignment: .leading, spacing: 4) {
                    Text(status)
                        .lifeboardFont(.caption1)
                        .foregroundStyle(Color.lifeboard(.textSecondary))
                        .lineLimit(2)
                        .contentTransition(.opacity)
                        .id(status)
                        .transition(.opacity)
                    if isSlow {
                        Text(EvaWorkingStatusLibrary.slowTurnNotice)
                            .lifeboardFont(.caption2)
                            .foregroundStyle(Color.lifeboard(.textTertiary))
                            .fixedSize(horizontal: false, vertical: true)
                            .transition(.opacity)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.xs)
            .lifeBoardClaySurface(.resting, cornerRadius: Radius.row)
            // Only opacity changes here, which reads as a calm crossfade even
            // with Reduce Motion on, so the role runs regardless of it.
            // Process-level animation switches (UI tests) still turn it off.
            .animation(MotionProfile.localState.animation(reduceMotion: false), value: status)
            .animation(MotionProfile.localState.animation(reduceMotion: false), value: isSlow)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(isSlow ? "\(status) \(EvaWorkingStatusLibrary.slowTurnNotice)" : status)
            .accessibilityIdentifier("eva.working.status")
        }
    }
}
