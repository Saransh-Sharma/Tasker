import SwiftUI

struct PlanningSummaryRow: View {
    let title: String
    let value: String
    let systemImage: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: LBSpacingTokens.sm) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(LBColorTokens.navyMuted)
                .frame(width: 18, height: 22)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.lifeboard(.caption1).weight(.semibold))
                    .foregroundStyle(LBColorTokens.navyMuted)
                Text(value)
                    .font(.lifeboard(.callout))
                    .foregroundStyle(LBColorTokens.navy)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: LBSpacingTokens.sm)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.lifeboard(.caption1).weight(.semibold))
                    .buttonStyle(.plain)
                    .foregroundStyle(LBColorTokens.role(.focus).deep)
                    .frame(minHeight: 44)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(value)")
    }
}
