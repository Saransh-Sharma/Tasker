import SwiftUI

struct AppearanceCardView: View {
    @Binding var isDarkMode: Bool
    var onToggleDarkMode: (Bool) -> Void

    var body: some View {
        TaskerCard {
            VStack(spacing: 0) {
                // Dark mode toggle row
                HStack(spacing: TaskerSwiftUITokens.spacing.s12) {
                    Image(systemName: isDarkMode ? "moon.fill" : "sun.max.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.tasker(.accentPrimary))
                        .frame(width: 24)
                        .animation(TaskerAnimation.quick, value: isDarkMode)

                    Text(isDarkMode ? "Dark Mode" : "Light Mode")
                        .font(.tasker(.bodyEmphasis))
                        .foregroundColor(.tasker(.textPrimary))

                    Spacer()

                    Toggle("", isOn: Binding(
                        get: { isDarkMode },
                        set: { onToggleDarkMode($0) }
                    ))
                    .labelsHidden()
                    .tint(Color.tasker(.accentPrimary))
                }
                .padding(.vertical, TaskerSwiftUITokens.spacing.s4)

                Divider()
                    .background(Color.tasker.strokeHairline)
                    .padding(.vertical, TaskerSwiftUITokens.spacing.s12)

                // Theme gallery
                ThemeGemGalleryView()
            }
        }
    }
}
