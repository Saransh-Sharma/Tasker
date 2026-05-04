//
//  AddTaskProjectPill.swift
//  Tasker
//
//  Individual project pill for the project selection bar.
//

import SwiftUI

// MARK: - Add Task Project Pill

struct AddTaskProjectPill: View {
    let name: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            TaskerFeedback.selection()
            action()
        } label: {
            Text(name)
                .font(.tasker(.callout))
                .fontWeight(isSelected ? .semibold : .regular)
                .fixedSize(horizontal: true, vertical: false)
                .foregroundColor(isSelected ? Color.tasker.accentOnPrimary : Color.tasker.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.tasker.accentPrimary : Color.tasker.surfaceSecondary)
                )
        }
        .buttonStyle(.plain)
        .scaleOnPress()
        .animation(TaskerAnimation.quick, value: isSelected)
    }
}

// MARK: - Preview

#if DEBUG
struct AddTaskProjectPill_Previews: PreviewProvider {
    static var previews: some View {
        HStack(spacing: 8) {
            AddTaskProjectPill(name: "Inbox", isSelected: true, action: {})

            AddTaskProjectPill(name: "Work", isSelected: false, action: {})

            AddTaskProjectPill(name: "Personal", isSelected: false, action: {})
        }
        .padding()
        .background(Color.tasker.surfacePrimary)
        .previewLayout(.sizeThatFits)
    }
}
#endif
