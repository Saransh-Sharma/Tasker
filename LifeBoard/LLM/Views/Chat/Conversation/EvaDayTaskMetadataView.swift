//
//  ConversationView.swift
//

import MarkdownUI
import SwiftUI

struct EvaDayTaskMetadataView: View {
    let card: EvaDayTaskCard

    var body: some View {
        HStack(spacing: LifeBoardTheme.Spacing.xs) {
            if let dueLabel = card.dueLabel, dueLabel.isEmpty == false {
                Text(dueLabel)
                    .font(.lifeboard(.caption1))
                    .foregroundStyle(card.isOverdue ? Color.lifeboard(.statusDanger) : Color.lifeboard(.textSecondary))
            }
            Text(card.projectName)
                .font(.lifeboard(.caption1))
                .foregroundStyle(Color.lifeboard(.textTertiary))
            if let durationLabel = card.durationLabel, durationLabel.isEmpty == false {
                Text(durationLabel)
                    .font(.lifeboard(.caption1))
                    .foregroundStyle(Color.lifeboard(.textTertiary))
            }
        }
    }
}
