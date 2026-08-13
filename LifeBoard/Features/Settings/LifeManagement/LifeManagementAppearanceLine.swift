import SwiftUI
import UIKit

struct LifeManagementAppearanceLine: View {
    let title: String
    let accentHex: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color(uiColor: UIColor(lifeboardHex: accentHex)))
                .frame(width: 12, height: 12)
                .accessibilityHidden(true)
            Text(title)
                .font(.lifeboard(.caption1))
                .foregroundStyle(Color.lifeboard(.textSecondary))
            Spacer()
            Text(value)
                .font(.lifeboard(.bodyEmphasis))
                .foregroundStyle(Color.lifeboard(.textPrimary))
        }
    }
}
