import SwiftUI
import UIKit

struct AccentIconBadge: View {
    let symbolName: String
    let accentHex: String

    var body: some View {
        let color = Color(uiColor: UIColor(lifeboardHex: accentHex))
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(color.opacity(0.14))
            Image(systemName: symbolName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(color)
        }
        .frame(width: 44, height: 44)
        .accessibilityHidden(true)
    }
}
