import SwiftUI

struct SunriseHeaderView<Content: View>: View {
    let context: LBHeaderTimeContext
    let isScrollActive: Bool
    let height: CGFloat
    @ViewBuilder let content: Content

    var body: some View {
        ZStack(alignment: .top) {
            LBSunriseHeroArtwork(
                model: LBSunriseHeroArtwork.Model(
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
