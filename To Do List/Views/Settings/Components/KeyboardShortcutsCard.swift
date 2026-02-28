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
        TaskerCard {
            VStack(alignment: .leading, spacing: TaskerSwiftUITokens.spacing.s12) {
                ForEach(shortcuts, id: \.key) { shortcut in
                    HStack(spacing: TaskerSwiftUITokens.spacing.s12) {
                        Text(shortcut.key)
                            .font(.system(.caption, design: .monospaced))
                            .fontWeight(.semibold)
                            .foregroundColor(Color.tasker.textPrimary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color.tasker.surfaceSecondary)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke(Color.tasker.strokeHairline, lineWidth: 1)
                            )
                            .fixedSize()

                        Text(shortcut.action)
                            .font(.tasker(.body))
                            .foregroundColor(Color.tasker.textSecondary)

                        Spacer()
                    }
                }
            }
        }
    }
}
