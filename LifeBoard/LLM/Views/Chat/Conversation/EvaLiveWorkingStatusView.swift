//
//  ConversationView.swift
//

import MarkdownUI
import SwiftUI

struct EvaLiveWorkingStatusView: View {
    let statuses: [String]

    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @State private var statusIndex = 0
    @State private var mascotScale: CGFloat = 1

    var currentStatus: String {
        let source = statuses.isEmpty ? EvaWorkingStatusLibrary.general : statuses
        return source[min(statusIndex, source.count - 1)]
    }

    var body: some View {
        HStack(spacing: LifeBoardTheme.Spacing.sm) {
            EvaMascotView(placement: .chatThinking, size: .chip)
                .scaleEffect(mascotScale)
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
        .animation(LifeBoardAnimation.animationsDisabled(reduceMotion: reduceMotion) ? nil : LifeBoardAnimation.quick, value: statusIndex)
        .animation(LifeBoardAnimation.animationsDisabled(reduceMotion: reduceMotion) ? nil : LifeBoardAnimation.ctaConfirmation, value: mascotScale)
        .task(id: currentStatus) {
            guard LifeBoardAnimation.animationsDisabled(reduceMotion: reduceMotion) == false else { return }
            mascotScale = 1.035
            try? await Task.sleep(nanoseconds: 150_000_000)
            guard !Task.isCancelled else { return }
            mascotScale = 1
        }
        .task(id: statuses) {
            let source = statuses.isEmpty ? EvaWorkingStatusLibrary.general : statuses
            guard source.count > 1, LifeBoardAnimation.animationsDisabled(reduceMotion: reduceMotion) == false else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 3_100_000_000)
                guard !Task.isCancelled else { return }
                statusIndex = (statusIndex + 1) % source.count
            }
        }
    }
}
