import SwiftUI
import UIKit

struct LifeManagementAreaIconPicker: View {
    let iconOptions: [LifeAreaIconOption]
    @Binding var selectedSymbolName: String

    @Environment(\.lifeboardLayoutClass) private var layoutClass

    var spacing: LifeBoardSpacingTokens { LifeBoardThemeManager.shared.tokens(for: layoutClass).spacing }

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: layoutClass.isPad ? 88 : 74), spacing: spacing.s8)],
            spacing: spacing.s8
        ) {
            ForEach(iconOptions) { option in
                LifeManagementIconTile(
                    systemImage: option.symbolName,
                    title: option.keywords.first?.capitalized ?? option.symbolName,
                    isSelected: selectedSymbolName == option.symbolName
                ) {
                    withAnimation(LifeBoardAnimation.snappy) {
                        selectedSymbolName = option.symbolName
                    }
                }
            }
        }
    }
}
