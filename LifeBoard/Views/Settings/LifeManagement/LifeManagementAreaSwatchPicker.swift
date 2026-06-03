import SwiftUI
import UIKit

struct LifeManagementAreaSwatchPicker: View {
    @Binding var selectedHex: String

    @Environment(\.lifeboardLayoutClass) private var layoutClass

    var spacing: LifeBoardSpacingTokens { LifeBoardThemeManager.shared.tokens(for: layoutClass).spacing }

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
                        withAnimation(LifeBoardAnimation.snappy) {
                            selectedHex = option.hex
                        }
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }
}
