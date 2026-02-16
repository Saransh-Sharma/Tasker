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
        Button(action: onRemove) {
            HStack(spacing: 4) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 10, weight: .medium))
                }

                Text(title)
                    .font(.tasker(.caption2))
                    .fontWeight(.medium)
                    .lineLimit(1)
            }
            .foregroundColor(foregroundColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(backgroundColor)
            )
        }
        .buttonStyle(.plain)
    }

    private var foregroundColor: Color {
        if isDestructive {
            return Color.tasker.statusDanger
        }
        return Color.tasker.accentOnPrimary
    }

    private var backgroundColor: Color {
        if isDestructive {
            return Color.tasker.statusDanger.opacity(0.15)
        }
        return Color.tasker.accentPrimary
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
