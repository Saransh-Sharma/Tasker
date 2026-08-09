import SwiftUI
import UIKit

struct LifeManagementAreaSwatchPicker: View {
    @Binding var selectedHex: String

    @Environment(\.lifeboardTokens) private var tokens

    var spacing: LifeBoardSpacingTokens { tokens.spacing }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: spacing.s8) {
                ForEach(lifeManagementAreaPaletteOptions()) { option in
                    LifeManagementColorSwatchButton(
                        title: option.title,
                        color: lifeManagementResolvedColor(hex: option.hex, fallback: Color.lifeboard.surfaceSecondary),
                        systemImage: nil,
                        isSelected: lifeManagementNormalizedHex(selectedHex) == lifeManagementNormalizedHex(option.hex)
                    ) {
                        withAnimation(LifeBoardAnimation.stateChange) {
                            selectedHex = option.hex
                        }
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }
}
