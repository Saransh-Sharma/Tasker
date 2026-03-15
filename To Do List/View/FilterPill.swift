//
//  FilterPill.swift
//  Tasker
//
//  Compact filter pill for quick filter display in navigation.
//

import SwiftUI

// MARK: - Filter Pill

/// Compact pill-shaped button for displaying and removing active filters.
public struct FilterPill: View {
    let title: String
    var systemImage: String? = nil
    var isDestructive: Bool = false
    let onRemove: () -> Void

    /// Initializes a new instance.
    public init(
        title: String,
        systemImage: String? = nil,
        isDestructive: Bool = false,
        onRemove: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.isDestructive = isDestructive
        self.onRemove = onRemove
    }
    public var body: some View {
        TaskerFilterChip(
            title: title,
            systemImage: systemImage,
            isSelected: true,
            isDestructive: isDestructive,
            action: onRemove
        )
        .transition(.scale(scale: 0.8).combined(with: .opacity))
    }
}

// MARK: - Preview

#if DEBUG
struct FilterPill_Previews: PreviewProvider {
    static var previews: some View {
        HStack(spacing: 8) {
            FilterPill(title: "Work", systemImage: "folder") {}
            FilterPill(title: "High Priority", systemImage: "flag") {}
            FilterPill(title: "Clear all", systemImage: "xmark.circle.fill", isDestructive: true) {}
        }
        .padding()
        .background(Color.tasker.bgCanvas)
        .previewLayout(.sizeThatFits)
    }
}
#endif
