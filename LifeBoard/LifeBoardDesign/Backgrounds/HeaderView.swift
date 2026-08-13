import SwiftUI

struct HeaderView<Content: View>: View {
    let context: HeaderTimeContext
    let isScrollActive: Bool
    let height: CGFloat
    @ViewBuilder let content: Content

    var body: some View {
        ZStack(alignment: .top) {
            HeroArtwork(
                model: HeroArtwork.Model(
                    selectedDate: context.selectedDate,
                    asset: context.asset,
                    isScrollActive: isScrollActive
                ),
                height: height
            )

            content
        }
        .frame(height: height, alignment: .top)
        .ignoresSafeArea(edges: .top)
    }
}
