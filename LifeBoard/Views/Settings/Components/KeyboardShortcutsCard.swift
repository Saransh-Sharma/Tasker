import SwiftUI

struct KeyboardShortcutsCard: View {
    private let shortcuts: [(key: String, action: String)] = [
        ("⌘N", "New Task"),
        ("⌘F", "Search"),
        ("⌘1", "Tasks"),
        ("⌘2", "Analytics"),
        ("⌘,", "Settings"),
    ]

    var body: some View {
        LifeBoardCard {
            VStack(alignment: .leading, spacing: LifeBoardSwiftUITokens.spacing.s12) {
                ForEach(shortcuts, id: \.key) { shortcut in
                    HStack(spacing: LifeBoardSwiftUITokens.spacing.s12) {
                        Text(shortcut.key)
                            .font(.system(.caption, design: .monospaced))
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
