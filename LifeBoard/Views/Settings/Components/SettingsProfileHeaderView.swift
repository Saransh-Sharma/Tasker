import SwiftUI

struct SettingsProfileHeaderView: View {
    @ObservedObject var themeManager = LifeBoardThemeManager.shared
    let version: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            // Gradient backdrop
            HeaderGradientView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack {
                VStack(alignment: .leading, spacing: LifeBoardSwiftUITokens.spacing.s4) {
                    Text("LifeBoard")
                        .lifeboardFont(.title1)
                        .foregroundColor(headerInk)

                    Text("Version \(version)")
                        .lifeboardFont(.caption1)
                        .foregroundColor(headerInk)
                }

                Spacer()

                Image("LifeBoardLogo")
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 28, height: 28)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(headerInk.opacity(0.24), lineWidth: 1)
                    )
            }
            .padding(.horizontal, LifeBoardSwiftUITokens.spacing.screenHorizontal)
            .padding(.top, LifeBoardSwiftUITokens.spacing.s8)
        }
        .frame(minHeight: 120)
        .clipShape(RoundedRectangle(cornerRadius: LifeBoardSwiftUITokens.corner.r3, style: .continuous))
        .lifeboardElevation(.e2, cornerRadius: LifeBoardSwiftUITokens.corner.r3, includesBorder: false)
        .padding(.horizontal, LifeBoardSwiftUITokens.spacing.screenHorizontal)
    }

    private var headerInk: Color {
        colorScheme == .dark
            ? Color.lifeboard(.accentOnPrimary)
            : Color(LifeBoardColorTokens.foundationOnSettingsHero)
    }
}
