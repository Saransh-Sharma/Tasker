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
    let action: () -> Void

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }

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
            .foregroundColor(isActive ? Color.tasker.accentPrimary : Color.tasker.textTertiary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isActive ? Color.tasker.accentWash : Color.tasker.surfaceSecondary)
            )
            .overlay(
                Capsule()
                    .stroke(
                        isActive ? Color.tasker.accentRing : Color.tasker.strokeHairline,
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
                action: {}
            )

            AddTaskMetadataChip(
                icon: "calendar",
                text: "Tomorrow",
                isActive: true,
                action: {}
            )

            AddTaskMetadataChip(
                icon: "bell.fill",
                text: "9:00 AM",
                isActive: true,
                action: {}
            )
        }
        .padding()
        .background(Color.tasker.surfacePrimary)
        .previewLayout(.sizeThatFits)
    }
}
#endif
