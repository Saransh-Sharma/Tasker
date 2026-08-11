//
//  ConversationView.swift
//

import MarkdownUI
import SwiftUI

struct TypingIndicator: View {
    @State var animating = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(EvaChatSunriseGlass.primary)
                    .frame(width: 6, height: 6)
                    .scaleEffect(animating ? 1.0 : 0.5)
                    .opacity(animating ? 1.0 : 0.3)
                    // `roleAmbient` carries the product's ambient envelope and
                    // resolves to nil under Reduce Motion, where a dot that
                    // pulses forever is exactly what the setting is asking to
                    // stop. The stagger stays: three dots moving in lockstep
                    // read as one blinking block.
                    .animation(
                        MotionProfile.ambient.animation(reduceMotion: reduceMotion)?
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.2),
                        value: animating
                    )
            }
        }
        .padding(.top, Theme.Spacing.xs)
        .onAppear { animating = true }
    }
}
