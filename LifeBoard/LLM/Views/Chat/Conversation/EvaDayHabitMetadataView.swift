//
//  ConversationView.swift
//

import MarkdownUI
import SwiftUI

struct EvaDayHabitMetadataView: View {
    let card: EvaDayHabitCard

    var body: some View {
        HStack(spacing: LifeBoardTheme.Spacing.xs) {
            Text(card.cadenceLabel)
                .font(.lifeboard(.caption1))
                .foregroundStyle(Color.lifeboard(.textSecondary))
            if let dueLabel = card.dueLabel, dueLabel.isEmpty == false {
                Text(dueLabel)
                    .font(.lifeboard(.caption1))
                    .foregroundStyle(Color.lifeboard(.textTertiary))
            }
            if card.currentStreak > 0 {
                Text("\(card.currentStreak) day streak")
                    .font(.lifeboard(.caption1))
                    .foregroundStyle(Color.lifeboard(.textTertiary))
            }
        }
    }
}
