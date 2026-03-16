import SwiftUI

struct AppearanceCardView: View {
    let appVersion: String
    let buildNumber: String

    var body: some View {
        TaskerCard {
            VStack(alignment: .leading, spacing: TaskerSwiftUITokens.spacing.s16) {
                HStack(alignment: .top, spacing: TaskerSwiftUITokens.spacing.s12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.tasker(.accentSecondaryWash))
                            .frame(width: 52, height: 52)

                        Image(systemName: "sparkles.rectangle.stack.fill")
                            .font(.tasker(.sectionTitle))
                            .foregroundStyle(Color.tasker(.brandSecondary))
                    }

                    VStack(alignment: .leading, spacing: TaskerSwiftUITokens.spacing.s4) {
                        Text("Appearance")
                            .font(.tasker(.sectionTitle))
                            .foregroundStyle(Color.tasker(.textPrimary))

                        Text("Tasker follows your system light or dark appearance and keeps one rooted brand palette across every screen.")
                            .font(.tasker(.support))
                            .foregroundStyle(Color.tasker(.textSecondary))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                ThemeGemGalleryView()

                HStack(spacing: TaskerSwiftUITokens.spacing.s8) {
                    Label("System appearance", systemImage: "circle.lefthalf.filled")
                        .font(.tasker(.meta))
                        .foregroundStyle(Color.tasker(.textSecondary))

                    Spacer()

                    Text("v\(appVersion) (\(buildNumber))")
                        .font(.tasker(.monoMeta))
                        .foregroundStyle(Color.tasker(.textTertiary))
                        .lineLimit(1)
                }
            }
            .accessibilityIdentifier("settings.appearance.card")
        }
    }
}
