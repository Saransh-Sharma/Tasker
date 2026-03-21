import SwiftUI

struct TaskEditorSectionCard<Content: View>: View {
    let section: TaskEditorSection
    let summary: String
    let isExpanded: Bool
    let action: () -> Void
    let content: Content

    init(
        section: TaskEditorSection,
        summary: String,
        isExpanded: Bool,
        action: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.section = section
        self.summary = summary
        self.isExpanded = isExpanded
        self.action = action
        self.content = content()
    }

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.s12) {
            Button(action: action) {
                HStack(alignment: .top, spacing: spacing.s12) {
                    Image(systemName: section.icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(isExpanded ? Color.tasker.accentPrimary : Color.tasker.textSecondary)
                        .frame(width: 22, height: 22)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(section.title)
                            .font(.tasker(.callout).weight(.semibold))
                            .foregroundColor(Color.tasker.textPrimary)

                        Text(summary)
                            .font(.tasker(.caption1))
                            .foregroundColor(Color.tasker.textSecondary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color.tasker.textTertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(section.title). \(summary)")
            .accessibilityHint(isExpanded ? "Collapse section" : "Expand section")

            if isExpanded {
                content
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity
                    ))
            }
        }
        .padding(spacing.s12)
        .background(Color.tasker.surfaceSecondary.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.md))
        .animation(TaskerAnimation.snappy, value: isExpanded)
    }
}
