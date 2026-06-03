//
//  ConversationView.swift
//

import MarkdownUI
import SwiftUI

struct EvaDayStatusChipsView: View {
    let chips: [EvaDayStatusChip]
    let colorProvider: (String) -> Color

    var body: some View {
        if chips.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .trailing, spacing: 4) {
                ForEach(chips, id: \.self) { chip in
                    let color = colorProvider(chip.tone)
                    Text(chip.text)
                        .font(.lifeboard(.caption2))
                        .fontWeight(.semibold)
                        .foregroundStyle(color)
                        .padding(.horizontal, LifeBoardTheme.Spacing.xs)
                        .padding(.vertical, 3)
                        .background(color.opacity(0.14))
                        .clipShape(Capsule())
                }
            }
        }
    }
}
