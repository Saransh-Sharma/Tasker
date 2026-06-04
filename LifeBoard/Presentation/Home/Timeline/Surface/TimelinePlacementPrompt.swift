import SwiftUI

struct TimelinePlacementPrompt: View {
    let candidate: TimelinePlacementCandidate
    let selectedDate: Date
    let suggestedTime: Date
    let onPlaceAtSuggestedTime: () -> Void
    let onPlaceAllDay: () -> Void
    let onBack: () -> Void
    let onSkip: () -> Void
    let onClearError: () -> Void

    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var spacing: LifeBoardSpacingTokens { LifeBoardThemeManager.shared.currentTheme.tokens.spacing }
    var corner: LifeBoardCornerTokens { LifeBoardThemeManager.shared.currentTheme.tokens.corner }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "hand.draw.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.lifeboard.accentPrimary)
                    .frame(width: 34, height: 34)
                    .background(Color.lifeboard.accentWash, in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Place this in your day")
                        .font(.lifeboard(.headline).weight(.semibold))
                        .foregroundStyle(Color.lifeboard.textPrimary)
                    Text("Drop on a time or move it to All Day.")
                        .font(.lifeboard(.support))
                        .foregroundStyle(Color.lifeboard.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Button("Back", action: onBack)
                    .font(.lifeboard(.support).weight(.semibold))
                    .disabled(candidate.isApplying)
            }

            if candidate.isApplying {
                ProgressView("Scheduling...")
                    .font(.lifeboard(.support).weight(.semibold))
                    .foregroundStyle(Color.lifeboard.textSecondary)
            }

            if let errorMessage = candidate.errorMessage {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(errorMessage)
                        .font(.lifeboard(.support))
                        .foregroundStyle(Color.lifeboard.textPrimary)
                    Spacer(minLength: 0)
                    Button("Dismiss", action: onClearError)
                        .font(.lifeboard(.support).weight(.semibold))
                }
                .padding(10)
                .background(Color.lifeboard.surfacePrimary.opacity(0.72), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            placementActions
        }
        .padding(14)
        .background(Color.lifeboard.accentWash.opacity(0.82), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.lifeboard.accentPrimary.opacity(0.16), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Place \(candidate.title) in \(selectedDate.formatted(.dateTime.weekday(.wide).month().day()))")
        .accessibilityAction(named: Text("Back to Replan")) {
            onBack()
        }
        .accessibilityAction(named: Text("Skip")) {
            onSkip()
        }
        .accessibilityAction(named: Text("Place at suggested time")) {
            onPlaceAtSuggestedTime()
        }
        .accessibilityAction(named: Text("Move to All Day")) {
            onPlaceAllDay()
        }
    }

    @ViewBuilder
    var placementActions: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: 10) {
                placementButton("Place at \(suggestedTime.formatted(date: .omitted, time: .shortened))", systemImage: "clock.badge.checkmark", emphasized: true, action: onPlaceAtSuggestedTime)
                placementButton("Move to All Day", systemImage: "calendar.badge.plus", emphasized: false, action: onPlaceAllDay)
                placementButton("Skip", systemImage: "forward.end.fill", emphasized: false, action: onSkip)
            }
        } else {
            HStack(spacing: 10) {
                placementButton("Place at \(suggestedTime.formatted(date: .omitted, time: .shortened))", systemImage: "clock.badge.checkmark", emphasized: true, action: onPlaceAtSuggestedTime)
                placementButton("Move to All Day", systemImage: "calendar.badge.plus", emphasized: false, action: onPlaceAllDay)
                placementButton("Skip", systemImage: "forward.end.fill", emphasized: false, action: onSkip)
            }
        }
    }

    func placementButton(_ title: String, systemImage: String, emphasized: Bool, action: @escaping () -> Void) -> some View {
        Button(action: {
            LifeBoardFeedback.selection()
            action()
        }) {
            Label(title, systemImage: systemImage)
                .font(.lifeboard(.support).weight(.semibold))
                .foregroundStyle(emphasized ? Color.lifeboard.accentOnPrimary : Color.lifeboard.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : nil)
                .frame(minHeight: 42)
                .padding(.horizontal, spacing.s12)
                .background(emphasized ? Color.lifeboard.actionPrimary : Color.lifeboard.surfacePrimary.opacity(0.82), in: RoundedRectangle(cornerRadius: corner.r2, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: corner.r2, style: .continuous)
                        .stroke(emphasized ? Color.lifeboard.actionPrimary.opacity(0.2) : Color.lifeboard.strokeHairline.opacity(0.72), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .scaleOnPress()
        .disabled(candidate.isApplying)
    }
}
