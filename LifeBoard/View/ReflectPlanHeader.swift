import SwiftUI

struct ReflectPlanHeader: View {
    let isCatchUp: Bool
    let onClose: () -> Void

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        HStack(alignment: .top, spacing: LBSpacingTokens.md) {
            VStack(alignment: .leading, spacing: LBSpacingTokens.xs) {
                Text("Reflect & Plan")
                    .font(.lifeboard(.title1).weight(.bold))
                    .foregroundStyle(LBColorTokens.navy)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Reflect on yesterday. Plan for today.")
                    .font(.lifeboard(.callout))
                    .foregroundStyle(LBColorTokens.navyMuted)
                    .fixedSize(horizontal: false, vertical: true)

                if isCatchUp {
                    StatusChip(text: "Catch-up", systemImage: "sparkles")
                        .padding(.top, 4)
                }
            }

            Spacer(minLength: LBSpacingTokens.sm)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(LBColorTokens.navy)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(reduceTransparency ? ReflectPlanStyle.cream : LBColorTokens.glassStrong)
                            .shadow(color: ReflectPlanStyle.shadow, radius: 12, x: 0, y: 6)
                    )
                    .overlay(
                        Circle()
                            .stroke(LBColorTokens.whiteStroke, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
            .accessibilityIdentifier("reflection.plan.close")
        }
        .padding(.horizontal, LBSpacingTokens.lg)
        .padding(.top, LBSpacingTokens.lg)
        .padding(.bottom, LBSpacingTokens.md)
        .background(ReflectPlanStyle.canvas)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Reflect and Plan. Reflect on yesterday. Plan for today.")
    }
}
