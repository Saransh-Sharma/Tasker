//
//  AddTaskMetadataChip.swift
//  Tasker
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

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }
    private var hasTint: Bool { TaskerHexColor.normalized(tintHex) != nil }
    private var tintColor: Color { TaskerHexColor.color(tintHex, fallback: Color.tasker.accentPrimary) }

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
            TaskerFeedback.selection()
            action()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))

                Text(text)
                    .font(.tasker(.callout))
                    .lineLimit(1)
            }
            .fixedSize(horizontal: true, vertical: false)
            .foregroundColor(
                isActive
                    ? (hasTint ? tintColor : Color.tasker.accentPrimary)
                    : Color.tasker.textTertiary
            )
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(
                        isActive
                            ? (hasTint ? tintColor.opacity(0.18) : Color.tasker.accentWash)
                            : (hasTint ? tintColor.opacity(0.08) : Color.tasker.surfaceSecondary)
                    )
            )
            .overlay(
                Capsule()
                    .stroke(
                        isActive
                            ? (hasTint ? tintColor.opacity(0.52) : Color.tasker.accentRing)
                            : (hasTint ? tintColor.opacity(0.24) : Color.tasker.strokeHairline),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .scaleOnPress()
        .animation(TaskerAnimation.quick, value: isActive)
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
        .background(Color.tasker.surfacePrimary)
        .previewLayout(.sizeThatFits)
    }
}
#endif
