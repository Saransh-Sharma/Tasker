//
//  ConversationView.swift
//

import MarkdownUI
import SwiftUI

struct EvaLiveWorkingStatusView: View {
    let statuses: [String]

    @Environment(\.accessibilityReduceMotion) var reduceMotion
    var currentStatus: String {
        let source = statuses.isEmpty ? EvaWorkingStatusLibrary.general : statuses
        return source.first ?? "Preparing a response..."
    }

    var body: some View {
        HStack(spacing: LifeBoardTheme.Spacing.sm) {
            ProgressView()
                .controlSize(.small)
                .tint(EvaChatSunriseGlass.primary)
            Text(currentStatus)
                .lifeboardFont(.caption1)
                .foregroundStyle(Color.lifeboard(.textTertiary))
                .lineLimit(2)
                .contentTransition(.opacity)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, LifeBoardTheme.Spacing.md)
        .padding(.vertical, LifeBoardTheme.Spacing.xs)
        .lifeboardChromeSurface(
            cornerRadius: 16,
            accentColor: EvaChatSunriseGlass.primary,
            level: .e1
        )
        .animation(
            LifeBoardAnimation.animationsDisabled(reduceMotion: reduceMotion) ? nil : LifeBoardAnimation.roleLocalState,
            value: currentStatus
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(currentStatus)
        .accessibilityIdentifier("eva.working.status")
    }
}
