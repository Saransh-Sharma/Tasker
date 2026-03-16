import SwiftUI

struct ThemeGemGalleryView: View {
    private var swatches: [(String, Color)] {
        [
            ("Emerald", Color(uiColor: TaskerThemeManager.shared.currentTheme.palette.brandEmerald)),
            ("Magenta", Color(uiColor: TaskerThemeManager.shared.currentTheme.palette.brandMagenta)),
            ("Marigold", Color(uiColor: TaskerThemeManager.shared.currentTheme.palette.brandMarigold)),
            ("Red", Color(uiColor: TaskerThemeManager.shared.currentTheme.palette.brandRed)),
            ("Sandstone", Color(uiColor: TaskerThemeManager.shared.currentTheme.palette.brandSandstone))
        ]
    }

    var body: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: TaskerSwiftUITokens.spacing.s8), count: 5)

        VStack(alignment: .leading, spacing: TaskerSwiftUITokens.spacing.s12) {
            Text("Brand palette")
                .font(.tasker(.eyebrow))
                .foregroundStyle(Color.tasker(.textTertiary))
                .tracking(0.6)

            LazyVGrid(columns: columns, spacing: TaskerSwiftUITokens.spacing.s8) {
                ForEach(swatches, id: \.0) { swatch in
                    VStack(spacing: TaskerSwiftUITokens.spacing.s4) {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [swatch.1.opacity(0.92), swatch.1],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(height: 54)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color.tasker(.strokeHairline), lineWidth: 1)
                            )

                        Text(swatch.0)
                            .font(.tasker(.caption2))
                            .foregroundStyle(Color.tasker(.textSecondary))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
            }
        }
        .accessibilityIdentifier("settings.appearance.palette")
    }
}
