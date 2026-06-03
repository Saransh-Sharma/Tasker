//
//  ConversationView.swift
//

import MarkdownUI
import SwiftUI

struct TypingIndicator: View {
    @State var animating = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(EvaChatSunriseGlass.primary)
                    .frame(width: 6, height: 6)
                    .scaleEffect(animating ? 1.0 : 0.5)
                    .opacity(animating ? 1.0 : 0.3)
                    .animation(
                        Animation.easeInOut(duration: 0.6)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.2),
                        value: animating
                    )
            }
        }
        .padding(.top, LifeBoardTheme.Spacing.xs)
        .onAppear { animating = true }
    }
}
