//
//  AddTaskTagMultiSelect.swift
//  Tasker
//
//  Tags multi-select with chip flow and inline create.
//

import SwiftUI

// MARK: - Tag Multi-Select

struct AddTaskTagMultiSelect: View {
    let tags: [TagDefinition]
    @Binding var selectedTagIDs: Set<UUID>

    @State private var showInlineCreate = false
    @State private var newTagName = ""

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }
    private var corner: TaskerCornerTokens { TaskerThemeManager.shared.currentTheme.tokens.corner }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.s8) {
            Text("Tags")
                .font(.tasker(.caption1))
                .foregroundColor(Color.tasker.textTertiary)

            // Tag chips flow
            FlowLayout(spacing: spacing.chipSpacing) {
                // Add tag button
                Button {
                    TaskerFeedback.selection()
                    withAnimation(TaskerAnimation.snappy) {
                        showInlineCreate.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .medium))
                        Text("Add")
                            .font(.tasker(.caption1))
                    }
                    .foregroundColor(Color.tasker.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.tasker.surfaceSecondary)
                            .overlay(
                                Capsule()
                                    .stroke(Color.tasker.strokeHairline, lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
                .scaleOnPress()

                // Existing tags
                ForEach(tags, id: \.id) { tag in
                    tagChip(tag)
                }
            }

            // Inline tag create
            if showInlineCreate {
                HStack(spacing: spacing.s8) {
                    TextField("Tag name", text: $newTagName)
                        .font(.tasker(.callout))
                        .foregroundColor(Color.tasker.textPrimary)
                        .padding(.horizontal, spacing.s12)
                        .padding(.vertical, spacing.s8)
                        .background(
                            RoundedRectangle(cornerRadius: corner.r2)
                                .fill(Color.tasker.surfaceTertiary)
                        )

                    Button("Done") {
                        newTagName = ""
                        showInlineCreate = false
                    }
                    .font(.tasker(.callout).weight(.medium))
                    .foregroundColor(Color.tasker.accentPrimary)
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal: .opacity
                ))
            }
        }
        .animation(TaskerAnimation.snappy, value: showInlineCreate)
    }

    private func tagChip(_ tag: TagDefinition) -> some View {
        let isSelected = selectedTagIDs.contains(tag.id)

        return Button {
            TaskerFeedback.selection()
            withAnimation(TaskerAnimation.bouncy) {
                if isSelected {
                    selectedTagIDs.remove(tag.id)
                } else {
                    selectedTagIDs.insert(tag.id)
                }
            }
        } label: {
            HStack(spacing: 4) {
                if let icon = tag.icon {
                    Image(systemName: icon)
                        .font(.system(size: 10))
                }
                Text(tag.name)
                    .font(.tasker(.caption1))
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .bold))
                }
            }
            .foregroundColor(isSelected ? Color.tasker.accentPrimary : Color.tasker.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isSelected ? Color.tasker.accentWash : Color.tasker.surfaceSecondary)
            )
            .overlay(
                Capsule()
                    .stroke(
                        isSelected ? Color.tasker.accentRing : Color.tasker.strokeHairline,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .scaleOnPress()
        .animation(TaskerAnimation.bouncy, value: isSelected)
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(
                x: bounds.minX + result.positions[index].x,
                y: bounds.minY + result.positions[index].y
            ), proposal: .unspecified)
        }
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> LayoutResult {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            totalHeight = currentY + lineHeight
        }

        return LayoutResult(
            size: CGSize(width: maxWidth, height: totalHeight),
            positions: positions
        )
    }

    struct LayoutResult {
        let size: CGSize
        let positions: [CGPoint]
    }
}
