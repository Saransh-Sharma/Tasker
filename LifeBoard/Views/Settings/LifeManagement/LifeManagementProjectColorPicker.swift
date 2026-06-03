import SwiftUI
import UIKit

struct LifeManagementProjectColorPicker: View {
    @Binding var selectedColor: ProjectColor

    @Environment(\.lifeboardLayoutClass) private var layoutClass

    var spacing: LifeBoardSpacingTokens { LifeBoardThemeManager.shared.tokens(for: layoutClass).spacing }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: spacing.s8) {
                ForEach(ProjectColor.allCases, id: \.rawValue) { color in
                    LifeManagementColorSwatchButton(
                        title: color.displayName,
                        color: lifeManagementResolvedColor(hex: color.hexString, fallback: Color.lifeboard.accentPrimary),
                        systemImage: nil,
                        isSelected: selectedColor == color
                    ) {
                        withAnimation(LifeBoardAnimation.snappy) {
                            selectedColor = color
                        }
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }
}
