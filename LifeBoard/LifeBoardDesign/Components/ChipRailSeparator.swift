import SwiftUI

/// Subtle divider between scope-lens chips and Today facet chips in the unified Home chip rail.
struct ChipRailSeparator: View {
    var body: some View {
        Capsule()
            .fill(ClayColorTokens.hairline.opacity(0.70))
            .frame(width: 1, height: 20)
            .padding(.horizontal, 2)
            .accessibilityHidden(true)
    }
}
