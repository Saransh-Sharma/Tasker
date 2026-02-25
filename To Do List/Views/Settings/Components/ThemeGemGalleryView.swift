import SwiftUI

struct ThemeGemGalleryView: View {
    @ObservedObject private var themeManager = TaskerThemeManager.shared

    private let cardWidth: CGFloat = 68
    private let cardHeight: CGFloat = 96

    var body: some View {
        VStack(alignment: .leading, spacing: TaskerSwiftUITokens.spacing.s8) {
            Text("ACCENT THEME")
                .font(.tasker(.caption2))
                .foregroundColor(.tasker(.textTertiary))
                .tracking(0.5)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: TaskerSwiftUITokens.spacing.s8) {
                    ForEach(themeManager.availableThemeSwatches, id: \.index) { swatch in
                        gemCard(swatch: swatch, isSelected: swatch.index == themeManager.selectedThemeIndex)
                            .onTapGesture {
                                TaskerFeedback.selection()
                                withAnimation(TaskerAnimation.snappy) {
                                    themeManager.selectTheme(index: swatch.index)
                                }
                            }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func gemCard(swatch: TaskerThemeSwatch, isSelected: Bool) -> some View {
        let themeName = TaskerTheme.accentThemes[swatch.index].name
        VStack(spacing: TaskerSwiftUITokens.spacing.s4) {
            ZStack {
                // Gradient card
                RoundedRectangle(cornerRadius: TaskerSwiftUITokens.corner.r2, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(uiColor: swatch.primary), Color(uiColor: swatch.secondary)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: cardWidth, height: cardHeight - 20)

                // Checkmark overlay
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.3), radius: 2)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: TaskerSwiftUITokens.corner.r2, style: .continuous)
                    .stroke(
                        isSelected ? Color.tasker.accentRing : Color.tasker.strokeHairline,
                        lineWidth: isSelected ? 2.5 : 0.5
                    )
            )
            .scaleEffect(isSelected ? 1.04 : 1.0)
            .shadow(
                color: isSelected ? Color(uiColor: swatch.primary).opacity(0.3) : .clear,
                radius: isSelected ? 6 : 0
            )

            Text(themeName)
                .font(.tasker(.caption2))
                .foregroundColor(isSelected ? .tasker(.textPrimary) : .tasker(.textTertiary))
                .lineLimit(1)
        }
        .frame(width: cardWidth)
        .animation(TaskerAnimation.snappy, value: isSelected)
    }
}
