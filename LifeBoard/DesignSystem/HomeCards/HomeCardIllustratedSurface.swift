import SwiftUI

/// Native content determines height; ambient artwork shares its background.
struct HomeCardIllustratedSurface: ViewModifier {
    let style: HomeCardPresentationStyle
    let palette: DaypartPalette
    var showsScene = true

    func body(content: Content) -> some View {
        content
            .foregroundStyle(palette.color(for: .foreground))
            .tint(palette.color(for: .foreground))
            .frame(maxWidth: .infinity, minHeight: style.minimumHeight, alignment: .topLeading)
            .background {
                Color.clear.lifeBoardRaisedClayCard(palette: palette, cornerRadius: 24)
                    .overlay {
                        if showsScene { HomeCardScene(style: style) }
                    }
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            .clipShape(.rect(cornerRadius: 24))
    }
}
