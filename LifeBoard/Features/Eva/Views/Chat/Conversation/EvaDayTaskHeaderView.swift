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
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(card.title)
                    .font(.lifeboard(.headline))
                    .foregroundStyle(Color.lifeboard(.textPrimary))
                    .multilineTextAlignment(.leading)

                EvaDayTaskMetadataView(card: card)
            }

            Spacer(minLength: Theme.Spacing.sm)

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
