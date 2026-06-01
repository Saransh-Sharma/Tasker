import SwiftUI

struct StatusChip: View {
    let text: String
    let systemImage: String

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.lifeboard(.caption1).weight(.semibold))
            .foregroundStyle(LBColorTokens.role(.warning).deep)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule(style: .continuous)
                    .fill(ReflectPlanStyle.goldSurface)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(ReflectPlanStyle.goldBorder.opacity(0.82), lineWidth: 1)
            )
    }
}
