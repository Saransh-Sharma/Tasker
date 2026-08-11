import SwiftUI

struct SectionHeader: View {
    let title: String
    var systemImage: String?
    var trailingText: String?

    var body: some View {
        HStack(spacing: ClayLayoutMetrics.sm) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(ClayColorTokens.violet)
            }
            Text(title)
                .font(ClayTypography.sectionTitle)
                .foregroundStyle(ClayColorTokens.navy)
            Spacer()
            if let trailingText {
                Text(trailingText)
                    .font(ClayTypography.meta)
                    .foregroundStyle(ClayColorTokens.navyMuted)
            }
        }
    }
}
