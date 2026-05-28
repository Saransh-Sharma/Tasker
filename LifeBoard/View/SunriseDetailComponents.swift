//
//  SunriseDetailComponents.swift
//  LifeBoard
//

import SwiftUI

struct SunriseDetailDisclosureCard<Content: View>: View {
    let title: String
    let systemImage: String
    let summary: String
    let isExpanded: Bool
    var accessibilityIdentifier: String?
    let action: () -> Void
    let content: Content

    @Environment(\.lifeboardLayoutClass) private var layoutClass
    private var spacing: LifeBoardSpacingTokens { LifeBoardThemeManager.shared.tokens(for: layoutClass).spacing }

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
        self.accessibilityIdentifier = accessibilityIdentifier
        self.action = action
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: isExpanded ? spacing.s12 : 0) {
            Button(action: action) {
                HStack(alignment: .top, spacing: spacing.s12) {
                    Image(systemName: systemImage)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(isExpanded ? Color.lifeboard.accentPrimary : Color.lifeboard.textSecondary)
                        .frame(width: 34, height: 34)
                        .background(isExpanded ? Color.lifeboard.accentWash : Color.lifeboard.surfacePrimary.opacity(0.78), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.lifeboard(.headline))
                            .foregroundStyle(Color.lifeboard.textPrimary)
                        Text(summary)
                            .font(.lifeboard(.callout))
                            .foregroundStyle(Color.lifeboard.textSecondary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isExpanded ? Color.lifeboard.accentPrimary : Color.lifeboard.textTertiary)
                        .frame(width: 32, height: 32)
                        .background(Color.lifeboard.surfacePrimary.opacity(0.7), in: Circle())
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(title). \(summary)")
            .accessibilityHint(isExpanded ? "Collapse section" : "Expand section")
            .accessibilityIdentifier(accessibilityIdentifier ?? "")

            if isExpanded {
                content
                    .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .top)), removal: .opacity))
            }
        }
        .padding(spacing.s12)
        .lifeboardChromeSurface(
            cornerRadius: LifeBoardTheme.CornerRadius.card,
            accentColor: isExpanded ? Color.lifeboard.accentPrimary : Color.lifeboard.accentSecondary,
            level: isExpanded ? .e1 : .e0
        )
        .animation(LifeBoardAnimation.snappy, value: isExpanded)
    }
}

struct SunriseDetailCapsuleButtonStyle: ButtonStyle {
    let tone: LifeBoardStatusPillTone

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.lifeboard(.callout).weight(.semibold))
            .foregroundStyle(tone.textColor)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, 10)
            .background(tone.fillColor.opacity(configuration.isPressed ? 0.76 : 1), in: Capsule())
            .overlay {
                Capsule().stroke(tone.strokeColor, lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(LifeBoardAnimation.press, value: configuration.isPressed)
    }
}

struct SunriseTextButtonStyle: ButtonStyle {
    let tone: LifeBoardStatusPillTone

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.lifeboard(.callout).weight(.semibold))
            .foregroundStyle(tone.textColor)
            .frame(minHeight: 44)
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}
