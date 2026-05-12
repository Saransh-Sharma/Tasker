import SwiftUI

struct SettingsProfileHeaderView: View {
    @ObservedObject var themeManager = LifeBoardThemeManager.shared
    let version: String

    var body: some View {
        ZStack {
            // Gradient backdrop
            HeaderGradientView()
                .frame(height: 120)

            HStack {
                VStack(alignment: .leading, spacing: LifeBoardSwiftUITokens.spacing.s4) {
                    Text("LifeBoard")
                        .font(.lifeboard(.title1))
                        .foregroundColor(.white)

                    Text("Version \(version)")
                        .font(.lifeboard(.caption1))
                        .foregroundColor(.white.opacity(0.7))
                }

                Spacer()

                Image("LifeBoardLogo")
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 28, height: 28)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.white.opacity(0.22), lineWidth: 1)
                    )
            }
            .padding(.horizontal, LifeBoardSwiftUITokens.spacing.screenHorizontal)
            .padding(.top, LifeBoardSwiftUITokens.spacing.s8)
        }
        .clipShape(RoundedRectangle(cornerRadius: LifeBoardSwiftUITokens.corner.r3, style: .continuous))
        .lifeboardElevation(.e2, cornerRadius: LifeBoardSwiftUITokens.corner.r3, includesBorder: false)
        .padding(.horizontal, LifeBoardSwiftUITokens.spacing.screenHorizontal)
    }
}
