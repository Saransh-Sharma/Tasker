import SwiftUI

extension TrackRootView {
    func overviewTile(title: String, value: String, symbol: String, palette: DaypartPalette) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: symbol)
                .font(.title2)
            Spacer(minLength: 2)
            Text(value).font(.headline).lineLimit(2)
            Text(title).font(.caption).foregroundStyle(palette.color(for: .foregroundSecondary))
        }
        .frame(maxWidth: .infinity, minHeight: 116, alignment: .leading)
        .padding(16)
        .lifeBoardPaperCard()
        .contentShape(Rectangle())
    }

    func habitsBridge(palette: DaypartPalette) -> some View {
        VStack(spacing: 18) {
            Image(systemName: "repeat.circle.fill").lifeboardFont(.heroDisplay)
            Text("Habits").font(.title2.weight(.semibold))
            Button {
                onOpenHabitBoard()
            } label: {
                Text("Open habits")
                    .foregroundStyle(Color(SemanticColorTokens.foundationSurfaceSolid))
            }
            .buttonStyle(.lifeBoardPrimaryCompact)
            .tint(palette.color(for: .foreground))
        }
        .padding(24)
        .lifeBoardPaperCard()
        .padding(20)
        .frame(maxHeight: .infinity, alignment: .top)
    }
}
