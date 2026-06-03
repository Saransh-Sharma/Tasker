//
//  ConversationView.swift
//

import MarkdownUI
import SwiftUI

struct EvaLiveWorkingStatusView: View {
    let statuses: [String]

    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @State private var statusIndex = 0

    var currentStatus: String {
        let source = statuses.isEmpty ? EvaWorkingStatusLibrary.general : statuses
        return source[min(statusIndex, source.count - 1)]
    }

    var body: some View {
        HStack(spacing: LifeBoardTheme.Spacing.sm) {
            EvaMascotView(placement: .chatThinking, size: .chip)
            Text(currentStatus)
                .lifeboardFont(.caption1)
                .foregroundStyle(Color.lifeboard(.textTertiary))
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, LifeBoardTheme.Spacing.md)
        .padding(.vertical, LifeBoardTheme.Spacing.xs)
        .lifeboardChromeSurface(
            cornerRadius: 16,
            accentColor: EvaChatSunriseGlass.primary,
            level: .e1
        )
        .animation(reduceMotion ? nil : LifeBoardAnimation.quick, value: statusIndex)
        .task(id: statuses) {
            let source = statuses.isEmpty ? EvaWorkingStatusLibrary.general : statuses
            guard source.count > 1, reduceMotion == false else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 3_100_000_000)
                guard !Task.isCancelled else { return }
                statusIndex = (statusIndex + 1) % source.count
            }
        }
    }
}
