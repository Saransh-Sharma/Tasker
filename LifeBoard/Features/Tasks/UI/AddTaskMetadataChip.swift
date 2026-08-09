//
//  AddTaskMetadataChip.swift
//  LifeBoard
//
//  Interactive chip component for metadata selection (date, reminder, time of day).
//

import SwiftUI

// MARK: - Add Task Metadata Chip

struct AddTaskMetadataChip: View {
    @Environment(\.lifeboardTokens) private var tokens
    let icon: String
    let text: String
    let isActive: Bool
    let tintHex: String?
    let action: () -> Void

    private var spacing: SemanticSpacingTokens { ThemeStore.shared.currentTheme.tokens.spacing }
    private var hasTint: Bool { HexColor.normalized(tintHex) != nil }
    private var tintColor: Color { HexColor.color(tintHex, fallback: Color.lifeboard.accentPrimary) }

    init(
        icon: String,
        text: String,
        isActive: Bool,
        tintHex: String? = nil,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.text = text
        self.isActive = isActive
        self.tintHex = tintHex
        self.action = action
    }

    var body: some View {
        Button {
            HapticFeedback.selection()
            action()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(ClayTypography.meta)

                Text(text)
                    .lineLimit(1)
            }
            .font(ClayTypography.meta)
            .fixedSize(horizontal: true, vertical: false)
            .foregroundColor(
                isActive
                    ? (hasTint ? tintColor : Color.lifeboard.accentPrimary)
                    : Color.lifeboard.textTertiary
            )
            .frame(minHeight: CreationChipMetrics.visualHeight)
            .padding(.horizontal, CreationChipMetrics.horizontalPadding)
            .background(
                Capsule()
                    .fill(
                        isActive
                            ? (hasTint ? tintColor.opacity(0.18) : Color.lifeboard.accentWash)
                            : (hasTint ? tintColor.opacity(0.08) : Color.lifeboard.surfaceSecondary)
                    )
            )
            .overlay(
                Capsule()
                    .stroke(
                        isActive
                            ? (hasTint ? tintColor.opacity(0.52) : Color.lifeboard.accentRing)
                            : (hasTint ? tintColor.opacity(0.24) : Color.lifeboard.strokeHairline),
                        lineWidth: 1
                    )
            )
            .frame(minHeight: CreationChipMetrics.hitHeight)
        }
        .buttonStyle(.plain)
        .scaleOnPress()
        .animation(LifeBoardAnimation.feedbackFast, value: isActive)
    }
}

// MARK: - Preview

#if DEBUG
struct AddTaskMetadataChip_Previews: PreviewProvider {
    static var previews: some View {
        HStack(spacing: 8) {
            AddTaskMetadataChip(
                icon: "calendar",
                text: "Today",
                isActive: false,
                tintHex: nil,
                action: {}
            )

            AddTaskMetadataChip(
                icon: "calendar",
                text: "Tomorrow",
                isActive: true,
                tintHex: nil,
                action: {}
            )

            AddTaskMetadataChip(
                icon: "bell.fill",
                text: "9:00 AM",
                isActive: true,
                tintHex: "#4A86E8",
                action: {}
            )
        }
        .padding()
        .background(Color.lifeboard.surfacePrimary)
        .previewLayout(.sizeThatFits)
    }
}
#endif
