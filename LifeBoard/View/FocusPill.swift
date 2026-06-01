import SwiftUI

struct FocusPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(title)
                .font(.lifeboard(.caption2).weight(.semibold))
                .foregroundStyle(LBColorTokens.role(.focus).deep)
            Text(value)
                .font(.lifeboard(.caption1).weight(.semibold))
                .foregroundStyle(LBColorTokens.navy)
                .lineLimit(2)
                .minimumScaleFactor(0.84)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(ReflectPlanStyle.blueSurfaceStrong, in: Capsule(style: .continuous))
        .overlay(
            Capsule(style: .continuous)
                .stroke(ReflectPlanStyle.blueBorder, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(value)")
    }
}
