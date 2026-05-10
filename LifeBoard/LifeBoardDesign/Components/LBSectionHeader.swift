import SwiftUI

struct LBSectionHeader: View {
    let title: String
    var systemImage: String?
    var trailingText: String?

    var body: some View {
        HStack(spacing: LBSpacingTokens.sm) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(LBColorTokens.violet)
            }
            Text(title)
                .font(LBTypographyTokens.sectionTitle)
                .foregroundStyle(LBColorTokens.navy)
            Spacer()
            if let trailingText {
                Text(trailingText)
                    .font(LBTypographyTokens.meta)
                    .foregroundStyle(LBColorTokens.navyMuted)
            }
        }
    }
}
