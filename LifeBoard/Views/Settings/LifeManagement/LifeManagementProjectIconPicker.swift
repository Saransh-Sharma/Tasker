import SwiftUI
import UIKit

struct LifeManagementProjectIconPicker: View {
    @Binding var selectedIcon: ProjectIcon

    @Environment(\.lifeboardLayoutClass) private var layoutClass

    var spacing: LifeBoardSpacingTokens { LifeBoardThemeManager.shared.tokens(for: layoutClass).spacing }

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: layoutClass.isPad ? 88 : 74), spacing: spacing.s8)],
            spacing: spacing.s8
        ) {
            ForEach(ProjectIcon.allCases, id: \.rawValue) { icon in
                LifeManagementIconTile(
                    systemImage: icon.systemImageName,
                    title: icon.displayName,
                    isSelected: selectedIcon == icon
                ) {
                    withAnimation(LifeBoardAnimation.snappy) {
                        selectedIcon = icon
                    }
                }
            }
        }
    }
}
