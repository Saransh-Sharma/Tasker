//
//  ConversationView.swift
//

import MarkdownUI
import SwiftUI

struct EvaDayHabitHeaderView: View {
    let card: EvaDayHabitCard
    let overlay: EvaDayHabitOverlayState
    let chips: [EvaDayStatusChip]
    let chipColorProvider: (String) -> Color

    var body: some View {
        HStack(alignment: .top, spacing: LifeBoardTheme.Spacing.sm) {
            Image(systemName: card.iconSymbolName ?? "repeat.circle")
                .font(.lifeboard(.title3))
                .foregroundStyle(Color.lifeboard(.accentPrimary))
                .frame(width: 32)

            VStack(alignment: .leading, spacing: LifeBoardTheme.Spacing.xs) {
                Text(card.title)
                    .font(.lifeboard(.headline))
                    .foregroundStyle(Color.lifeboard(.textPrimary))
                    .multilineTextAlignment(.leading)

                EvaDayHabitMetadataView(card: card)
            }

            Spacer(minLength: LifeBoardTheme.Spacing.sm)

            if overlay.isProcessing {
                ProgressView()
                    .controlSize(.small)
            } else {
                EvaDayStatusChipsView(
                    chips: chips,
                    colorProvider: chipColorProvider
                )
            }
        }
    }
}
