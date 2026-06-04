//
//  ConversationView.swift
//

import MarkdownUI
import SwiftUI

struct EvaDayTaskHeaderView: View {
    let card: EvaDayTaskCard
    let overlay: EvaDayTaskOverlayState
    let chipColorProvider: (String) -> Color

    var body: some View {
        HStack(alignment: .top, spacing: LifeBoardTheme.Spacing.sm) {
            VStack(alignment: .leading, spacing: LifeBoardTheme.Spacing.xs) {
                Text(card.title)
                    .font(.lifeboard(.headline))
                    .foregroundStyle(Color.lifeboard(.textPrimary))
                    .multilineTextAlignment(.leading)

                EvaDayTaskMetadataView(card: card)
            }

            Spacer(minLength: LifeBoardTheme.Spacing.sm)

            if overlay.isProcessing {
                ProgressView()
                    .controlSize(.small)
            } else {
                EvaDayStatusChipsView(
                    chips: card.statusChips,
                    colorProvider: chipColorProvider
                )
            }
        }
    }
}
