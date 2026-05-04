//
//  AddTaskProjectPill.swift
//  LifeBoard
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
            LifeBoardFeedback.selection()
            action()
        } label: {
            Text(name)
                .font(.lifeboard(.callout))
                .fontWeight(isSelected ? .semibold : .regular)
                .fixedSize(horizontal: true, vertical: false)
                .foregroundColor(isSelected ? Color.lifeboard.accentOnPrimary : Color.lifeboard.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.lifeboard.accentPrimary : Color.lifeboard.surfaceSecondary)
                )
        }
        .buttonStyle(.plain)
        .scaleOnPress()
        .animation(LifeBoardAnimation.quick, value: isSelected)
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
        .background(Color.lifeboard.surfacePrimary)
        .previewLayout(.sizeThatFits)
    }
}
#endif
