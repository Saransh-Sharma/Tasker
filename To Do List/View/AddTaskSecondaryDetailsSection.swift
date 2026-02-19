//
//  AddTaskSecondaryDetailsSection.swift
//  Tasker
//
//  Collapsible "More details" section: Description, Life Area, Section, Tags.
//

import SwiftUI

// MARK: - Secondary Details Section

struct AddTaskSecondaryDetailsSection: View {
    @ObservedObject var viewModel: AddTaskViewModel
    @FocusState.Binding var descriptionFocused: Bool
    let onExpand: () -> Void

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }
    private var corner: TaskerCornerTokens { TaskerThemeManager.shared.currentTheme.tokens.corner }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Disclosure header
            Button {
                TaskerFeedback.light()
                withAnimation(TaskerAnimation.gentle) {
                    viewModel.showMoreDetails.toggle()
                }
                if viewModel.showMoreDetails {
                    onExpand()
                }
            } label: {
                HStack {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 14, weight: .medium))
                    Text("More details")
                        .font(.tasker(.callout))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .rotationEffect(.degrees(viewModel.showMoreDetails ? 90 : 0))
                        .animation(TaskerAnimation.snappy, value: viewModel.showMoreDetails)
                }
                .foregroundColor(Color.tasker.textSecondary)
                .padding(.vertical, spacing.s12)
            }
            .buttonStyle(.plain)

            // Content
            if viewModel.showMoreDetails {
                VStack(spacing: spacing.s12) {
                    // Description
                    AddTaskDescriptionField(
                        text: $viewModel.taskDetails,
                        isFocused: $descriptionFocused
                    )
                    .staggeredAppearance(index: 0)

                    // Life Area selector
                    if !viewModel.lifeAreas.isEmpty {
                        AddTaskEntityPicker(
                            label: "Life Area",
                            items: viewModel.lifeAreas.map { (id: $0.id, name: $0.name, icon: $0.icon) },
                            selectedID: $viewModel.selectedLifeAreaID
                        )
                        .staggeredAppearance(index: 1)
                    }

                    // Section selector (scoped by project)
                    if !viewModel.sections.isEmpty {
                        AddTaskEntityPicker(
                            label: "Section",
                            items: viewModel.sections.map { (id: $0.id, name: $0.name, icon: nil as String?) },
                            selectedID: $viewModel.selectedSectionID
                        )
                        .staggeredAppearance(index: 2)
                    }

                    // Tags multi-select
                    AddTaskTagMultiSelect(
                        tags: viewModel.tags,
                        selectedTagIDs: $viewModel.selectedTagIDs
                    )
                    .staggeredAppearance(index: 3)
                }
                .padding(.top, spacing.s8)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal: .opacity
                ))
            }
        }
        .padding(.horizontal, spacing.s4)
        .padding(.vertical, spacing.s4)
        .background(
            RoundedRectangle(cornerRadius: corner.r2)
                .fill(Color.tasker.surfaceSecondary.opacity(0.5))
        )
    }
}
