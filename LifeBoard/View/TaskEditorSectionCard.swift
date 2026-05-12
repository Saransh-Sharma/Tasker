import SwiftUI

struct TaskEditorSectionCard<Content: View>: View {
    let title: String
    let systemImage: String
    let summary: String
    let isExpanded: Bool
    let action: () -> Void
    let content: Content
    let accessibilityIdentifier: String?

    init(
        section: TaskEditorSection,
        summary: String,
        isExpanded: Bool,
        accessibilityIdentifier: String? = nil,
        action: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.title = section.title
        self.systemImage = section.icon
        self.summary = summary
        self.isExpanded = isExpanded
        self.action = action
        self.accessibilityIdentifier = accessibilityIdentifier
        self.content = content()
    }

    init(
        title: String,
        systemImage: String,
        summary: String,
        isExpanded: Bool,
        accessibilityIdentifier: String? = nil,
        action: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.summary = summary
        self.isExpanded = isExpanded
        self.action = action
        self.accessibilityIdentifier = accessibilityIdentifier
        self.content = content()
    }

    private var spacing: LifeBoardSpacingTokens { LifeBoardThemeManager.shared.currentTheme.tokens.spacing }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.s12) {
            Button(action: action) {
                HStack(alignment: .top, spacing: spacing.s12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(isExpanded ? Color.lifeboard.accentWash : Color.lifeboard.surfacePrimary.opacity(0.92))
                            .frame(width: 32, height: 32)

                        Image(systemName: systemImage)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(isExpanded ? Color.lifeboard.accentPrimary : Color.lifeboard.textSecondary)
                    }

                    VStack(alignment: .leading, spacing: spacing.s4) {
                        Text(title)
                            .font(.lifeboard(.headline))
                            .foregroundStyle(Color.lifeboard.textPrimary)

                        Text(summary)
                            .font(.lifeboard(.meta))
                            .foregroundStyle(Color.lifeboard.textSecondary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)

                    ZStack {
                        Circle()
                            .fill(Color.lifeboard.surfacePrimary.opacity(isExpanded ? 1 : 0.72))
                            .frame(width: 28, height: 28)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(isExpanded ? Color.lifeboard.accentPrimary : Color.lifeboard.textTertiary)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    }
                }
            }
            .buttonStyle(.plain)
            .scaleOnPress()
            .accessibilityLabel("\(title). \(summary)")
            .accessibilityHint(isExpanded ? "Collapse section" : "Expand section")
            .accessibilityIdentifier(accessibilityIdentifier ?? "")

            if isExpanded {
                content
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity
                    ))
            }
        }
        .padding(spacing.s12)
        .lifeboardDenseSurface(
            cornerRadius: LifeBoardTheme.CornerRadius.card,
            fillColor: isExpanded ? Color.lifeboard.surfacePrimary : Color.lifeboard.surfaceSecondary.opacity(0.55),
            strokeColor: isExpanded ? Color.lifeboard.accentSecondary.opacity(0.24) : Color.lifeboard.strokeHairline.opacity(0.72)
        )
        .lifeboardElevation(isExpanded ? .e1 : .e0, cornerRadius: LifeBoardTheme.CornerRadius.card, includesBorder: false)
        .animation(LifeBoardAnimation.snappy, value: isExpanded)
    }
}
