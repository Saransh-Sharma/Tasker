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

    var body: some View {
        TaskEditorSectionCard(
            section: .organize,
            summary: viewModel.organizeSummary,
            isExpanded: viewModel.isSectionExpanded(.organize)
        ) {
            viewModel.toggleSection(.organize)
            if viewModel.isSectionExpanded(.organize) {
                onExpand()
            }
        } content: {
            VStack(spacing: TaskerTheme.Spacing.sm) {
                AddTaskDescriptionField(
                    text: $viewModel.taskDetails,
                    isFocused: $descriptionFocused
                )

                if !viewModel.lifeAreas.isEmpty {
                    AddTaskEntityPicker(
                        label: "Life Area",
                        items: viewModel.lifeAreas.map { (id: $0.id, name: $0.name, icon: $0.icon) },
                        selectedID: $viewModel.selectedLifeAreaID
                    )
                }

                if !viewModel.sections.isEmpty {
                    AddTaskEntityPicker(
                        label: "Section",
                        items: viewModel.sections.map { (id: $0.id, name: $0.name, icon: nil as String?) },
                        selectedID: $viewModel.selectedSectionID
                    )
                }

                AddTaskTagMultiSelect(
                    tags: viewModel.tags,
                    selectedTagIDs: $viewModel.selectedTagIDs,
                    onCreateTag: { name, completion in
                        viewModel.createTag(name: name, completion: completion)
                    }
                )
            }
        }
    }
}
