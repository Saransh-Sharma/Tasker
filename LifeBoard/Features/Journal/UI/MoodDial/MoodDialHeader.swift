import SwiftUI
import LifeBoardUI

public struct MoodDialHeader: View {
    let canSave: Bool
    let cancel: () -> Void
    let done: () -> Void
    @Environment(\.moodDialTheme) private var theme

    public init(canSave: Bool, cancel: @escaping () -> Void, done: @escaping () -> Void) {
        self.canSave = canSave
        self.cancel = cancel
        self.done = done
    }

    public var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button("Cancel", action: cancel)
                    .font(theme.labelFont)
                    .foregroundStyle(theme.accent)
                    .frame(width: 96, height: 52)
                    .background(theme.accentContrast, in: Capsule())
                    .lifeboardCompatibilityShadow(color: Color.black.opacity(0.045), radius: 8, y: 3)
                    .accessibilityIdentifier("moodDial.cancel")

                Spacer()

                Button("Done", action: done)
                    .font(theme.labelFont)
                    .foregroundStyle(theme.accentContrast)
                    .frame(width: 100, height: 52)
                    .background(theme.accent.opacity(canSave ? 1 : 0.62), in: Capsule())
                    .lifeboardCompatibilityShadow(color: Color.black.opacity(0.045), radius: 8, y: 3)
                    .accessibilityHint(canSave ? "Saves the selected mood." : "Closes without changing the mood.")
                    .accessibilityIdentifier("moodDial.done")
            }

            Text(theme.promptTitle)
                .font(theme.titleFont)
                .foregroundStyle(theme.heading)
                .multilineTextAlignment(.center)
                .lineSpacing(0)
                .lineLimit(2)
                .minimumScaleFactor(0.84)
                .frame(width: 180)
                .frame(minHeight: 68)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
        }
        .frame(height: 140)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}

public struct MoodDialSelectedMoodView: View {
    let mood: Mood
    let layoutScale: CGFloat
    let isInteractionActive: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.moodDialTheme) private var theme
    @State private var chevronPulse = false

    public init(mood: Mood, layoutScale: CGFloat, isInteractionActive: Bool) {
        self.mood = mood
        self.layoutScale = layoutScale
        self.isInteractionActive = isInteractionActive
    }

    public var body: some View {
        VStack(spacing: 12 * layoutScale) {
            Text(mood.moodSentence)
                .font(theme.labelFont)
                .foregroundStyle(theme.textSecondary)
                .contentTransition(.opacity)
                .accessibilityIdentifier("moodDial.sentence")

            ZStack {
                mood.glowImage
                    .resizable()
                    .interpolation(.medium)
                    .scaledToFit()
                    .frame(width: 292 * layoutScale, height: 292 * layoutScale)
                    .opacity(0.24)
                    .accessibilityHidden(true)

                mood.largeImage
                    .resizable()
                    .interpolation(.medium)
                    .scaledToFit()
                    .frame(width: 160 * layoutScale, height: 160 * layoutScale)
                    .scaleEffect(reduceMotion ? 1 : 1.035)
                    .accessibilityLabel(mood.displayName)
                    .accessibilityIdentifier("moodDial.largeIcon")
            }
            .frame(width: 220 * layoutScale, height: 176 * layoutScale)

            Text(mood.supportiveCopy)
                .font(theme.captionFont)
                .foregroundStyle(theme.textTertiary)
                .multilineTextAlignment(.center)
                .contentTransition(.opacity)

            Image(systemName: "chevron.compact.down")
                .lifeboardCompatibilitySystemFont(size: 40 * layoutScale, weight: .heavy)
                .foregroundStyle(theme.textTertiary.opacity(0.70))
                .offset(y: reduceMotion ? 0 : (chevronPulse ? 5 : 0))
                .animation(
                    reduceMotion ? nil : .easeInOut(duration: 1.05).repeatForever(autoreverses: true),
                    value: chevronPulse
                )
                .accessibilityHidden(true)
        }
        .animation(selectedMoodAnimation, value: mood)
        .onAppear {
            guard !reduceMotion else { return }
            chevronPulse = true
        }
    }

    private var selectedMoodAnimation: Animation? {
        if reduceMotion {
            return nil
        }

        if isInteractionActive {
            return nil
        }

        return .spring(response: 0.28, dampingFraction: 0.72)
    }
}
