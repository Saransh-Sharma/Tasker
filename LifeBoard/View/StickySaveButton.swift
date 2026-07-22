import SwiftUI

struct StickySaveButton: View {
    let title: String
    let isEnabled: Bool
    let isSaving: Bool
    let statusMessage: String?
    let action: () -> Void

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        VStack(spacing: LBSpacingTokens.sm) {
            Button(action: action) {
                HStack(spacing: LBSpacingTokens.sm) {
                    if isSaving {
                        ProgressView()
                            .tint(Color.lifeboard(.accentOnPrimary))
                            .controlSize(.small)
                    }
                    Text(title)
                        .font(.lifeboard(.bodyEmphasis))
                        .foregroundStyle(Color.lifeboard(.accentOnPrimary))
                        .lineLimit(1)
                        .minimumScaleFactor(0.86)
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: 56)
                .background(
                    Capsule(style: .continuous)
                        .fill(isEnabled ? ReflectPlanStyle.greenCTA : ReflectPlanStyle.disabledCTA)
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Color.lifeboard(.accentOnPrimary).opacity(0.20), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(isEnabled == false)
            .accessibilityLabel("Save reflection and plan.")
            .accessibilityHint("Saves the reflection and today's plan.")
            .accessibilityIdentifier("reflection.plan.save")

            if let statusMessage {
                Text(statusMessage)
                    .font(.lifeboard(.caption1))
                    .foregroundStyle(LBColorTokens.navyMuted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, LBSpacingTokens.lg)
        .padding(.top, LBSpacingTokens.sm)
        .padding(.bottom, LBSpacingTokens.sm)
        .background(
            Group {
                if reduceTransparency {
                    ReflectPlanStyle.canvas
                } else {
                    ReflectPlanStyle.canvas.opacity(0.82)
                        .background(.ultraThinMaterial)
                }
            }
            .ignoresSafeArea(edges: .bottom)
        )
    }
}
