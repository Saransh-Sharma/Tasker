import SwiftUI

/// Subtle divider between scope-lens chips and Today facet chips in the unified Home chip rail.
struct LBChipRailSeparator: View {
    var body: some View {
        Capsule()
            .fill(LBColorTokens.hairline.opacity(0.70))
            .frame(width: 1, height: 20)
            .padding(.horizontal, 2)
            .accessibilityHidden(true)
    }
}
