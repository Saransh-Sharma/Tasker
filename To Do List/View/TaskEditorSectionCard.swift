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
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(isExpanded ? Color.tasker.accentWash : Color.tasker.surfacePrimary)
                            .frame(width: 34, height: 34)

                        Image(systemName: section.icon)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(isExpanded ? Color.tasker.accentPrimary : Color.tasker.textSecondary)
                    }

                    VStack(alignment: .leading, spacing: spacing.s4) {
                        HStack(spacing: spacing.s8) {
                            Text(section.title)
                                .font(.tasker(.callout).weight(.semibold))
                                .foregroundStyle(Color.tasker.textPrimary)

                            TaskerStatusPill(
                                text: isExpanded ? "Open" : "Collapsed",
                                systemImage: isExpanded ? "eye.fill" : "ellipsis",
                                tone: isExpanded ? .accent : .quiet
                            )
                        }

                        Text(summary)
                            .font(.tasker(.caption1))
                            .foregroundStyle(Color.tasker.textSecondary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)

                    ZStack {
                        Circle()
                            .fill(Color.tasker.surfacePrimary.opacity(isExpanded ? 1 : 0.7))
                            .frame(width: 28, height: 28)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(isExpanded ? Color.tasker.accentPrimary : Color.tasker.textTertiary)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    }
                }
            }
            .buttonStyle(.plain)
            .scaleOnPress()
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
        .taskerDenseSurface(
            cornerRadius: TaskerTheme.CornerRadius.card,
            fillColor: isExpanded ? Color.tasker.surfacePrimary : Color.tasker.surfaceSecondary.opacity(0.72),
            strokeColor: isExpanded ? Color.tasker.accentSecondary.opacity(0.34) : Color.tasker.strokeHairline.opacity(0.82)
        )
        .taskerElevation(isExpanded ? .e1 : .e0, cornerRadius: TaskerTheme.CornerRadius.card, includesBorder: false)
        .animation(TaskerAnimation.snappy, value: isExpanded)
    }
}
