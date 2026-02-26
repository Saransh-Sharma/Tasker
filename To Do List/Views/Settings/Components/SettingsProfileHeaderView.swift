import SwiftUI

struct SettingsProfileHeaderView: View {
    @ObservedObject var themeManager = TaskerThemeManager.shared
    let version: String

    var body: some View {
        ZStack {
            // Gradient backdrop
            HeaderGradientView()
                .frame(height: 120)

            HStack {
                VStack(alignment: .leading, spacing: TaskerSwiftUITokens.spacing.s4) {
                    Text("Tasker")
                        .font(.tasker(.title1))
                        .foregroundColor(.white)

                    Text("Version \(version)")
                        .font(.tasker(.caption1))
                        .foregroundColor(.white.opacity(0.7))
                }

                Spacer()

                // Accent theme swatch
                Circle()
                    .fill(Color.tasker(.accentPrimary))
                    .frame(width: 12, height: 12)
                    .shadow(color: Color.tasker(.accentPrimary).opacity(0.4), radius: 4)
            }
            .padding(.horizontal, TaskerSwiftUITokens.spacing.screenHorizontal)
            .padding(.top, TaskerSwiftUITokens.spacing.s8)
        }
        .clipShape(RoundedRectangle(cornerRadius: TaskerSwiftUITokens.corner.r3, style: .continuous))
        .taskerElevation(.e2, cornerRadius: TaskerSwiftUITokens.corner.r3, includesBorder: false)
        .padding(.horizontal, TaskerSwiftUITokens.spacing.screenHorizontal)
    }
}
