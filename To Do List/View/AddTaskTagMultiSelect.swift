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
    let onCreateTag: (String, @escaping (Bool) -> Void) -> Void

    @State private var showInlineCreate = false
    @State private var newTagName = ""
    @State private var isCreatingTag = false

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }
    private var corner: TaskerCornerTokens { TaskerThemeManager.shared.currentTheme.tokens.corner }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.s8) {
            Text("Tags")
                .font(.tasker(.caption1))
                .foregroundColor(Color.tasker.textTertiary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: spacing.chipSpacing) {
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
                        let trimmed = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard trimmed.isEmpty == false else {
                            return
                        }
                        isCreatingTag = true
                        onCreateTag(trimmed) { success in
                            DispatchQueue.main.async {
                                isCreatingTag = false
                                guard success else { return }
                                newTagName = ""
                                showInlineCreate = false
                            }
                        }
                    }
                    .font(.tasker(.callout).weight(.medium))
                    .foregroundColor(Color.tasker.accentPrimary)
                    .disabled(isCreatingTag || newTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal: .opacity
                ))
            }
        }
        .animation(TaskerAnimation.snappy, value: showInlineCreate)
    }

    /// Executes tagChip.
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
