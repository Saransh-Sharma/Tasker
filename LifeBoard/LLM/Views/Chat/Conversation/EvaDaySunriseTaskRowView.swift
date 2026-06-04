//
//  ConversationView.swift
//

import MarkdownUI
import SwiftUI

struct EvaDaySunriseTaskRowView: View {
    let card: EvaDayTaskCard
    let overlay: EvaDayTaskOverlayState
    let chipColorProvider: (String) -> Color
    let actionTitle: (EvaDayTaskAction) -> String
    let actionHandler: (EvaDayTaskAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: LifeBoardTheme.Spacing.sm) {
            EvaDayTaskHeaderView(
                card: card,
                overlay: overlay,
                chipColorProvider: chipColorProvider
            )

            EvaDayTaskActionsView(
                actions: card.actions,
                isProcessing: overlay.isProcessing,
                actionTitle: actionTitle,
                actionHandler: actionHandler
            )

            if let statusMessage = overlay.statusMessage, statusMessage.isEmpty == false {
                Text(statusMessage)
                    .font(.lifeboard(.caption1))
                    .foregroundStyle(Color.lifeboard(.textSecondary))
            }
        }
        .padding(LifeBoardTheme.Spacing.md)
        .background(Color.lifeboard(.surfaceSecondary))
        .clipShape(RoundedRectangle(cornerRadius: LifeBoardTheme.CornerRadius.lg, style: .continuous))
    }
}
