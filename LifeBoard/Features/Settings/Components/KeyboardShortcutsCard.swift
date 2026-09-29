import SwiftUI

struct KeyboardShortcutsCard: View {
    private let shortcuts: [(key: String, action: String)] = [
        ("⌘N", String(localized: "New task")),
        ("⌘F", String(localized: "Search")),
        ("⌘1", String(localized: "Tasks")),
        ("⌘2", String(localized: "Insights")),
        ("⌘,", String(localized: "Settings")),
    ]

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: SwiftUITokens.spacing.s12) {
                ForEach(shortcuts, id: \.key) { shortcut in
                    HStack(spacing: SwiftUITokens.spacing.s12) {
                        Text(shortcut.key)
                            .lifeboardFont(.monoMeta)
                            .fontWeight(.semibold)
                            .foregroundColor(Color.lifeboard.textPrimary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color.lifeboard.surfaceSecondary)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke(Color.lifeboard.strokeHairline, lineWidth: 1)
                            )
                            .fixedSize()

                        Text(shortcut.action)
                            .font(.lifeboard(.body))
                            .foregroundColor(Color.lifeboard.textSecondary)

                        Spacer()
                    }
                }
            }
        }
    }
}
