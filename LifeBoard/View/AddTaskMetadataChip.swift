//
//  AddTaskMetadataChip.swift
//  LifeBoard
//
//  Interactive chip component for metadata selection (date, reminder, time of day).
//

import SwiftUI

// MARK: - Add Task Metadata Chip

struct AddTaskMetadataChip: View {
    let icon: String
    let text: String
    let isActive: Bool
    let tintHex: String?
    let action: () -> Void

    private var spacing: LifeBoardSpacingTokens { LifeBoardThemeManager.shared.currentTheme.tokens.spacing }
    private var hasTint: Bool { LifeBoardHexColor.normalized(tintHex) != nil }
    private var tintColor: Color { LifeBoardHexColor.color(tintHex, fallback: Color.lifeboard.accentPrimary) }

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
            LifeBoardFeedback.selection()
            action()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(LBTypographyTokens.meta)

                Text(text)
                    .lineLimit(1)
            }
            .font(LBTypographyTokens.meta)
            .fixedSize(horizontal: true, vertical: false)
            .foregroundColor(
                isActive
                    ? (hasTint ? tintColor : Color.lifeboard.accentPrimary)
                    : Color.lifeboard.textTertiary
            )
            .frame(minHeight: LifeBoardCreationChipMetrics.visualHeight)
            .padding(.horizontal, LifeBoardCreationChipMetrics.horizontalPadding)
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
            .frame(minHeight: LifeBoardCreationChipMetrics.hitHeight)
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
