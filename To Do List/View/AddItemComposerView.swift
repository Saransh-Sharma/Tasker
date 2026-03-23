import SwiftUI

struct AddItemComposerView: View {
    @ObservedObject var viewModel: AddItemViewModel
    let containerMode: AddTaskContainerMode
    let showAddAnother: Bool
    @Binding var successFlash: Bool
    let onCancel: () -> Void
    let onTaskCreate: () -> Void
    let onTaskAddAnother: () -> Void
    let onHabitCreate: () -> Void
    let onHabitAddAnother: () -> Void
    let onExpandToLarge: () -> Void

    @Environment(\.taskerLayoutClass) private var layoutClass
    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }
    private var readableWidth: CGFloat {
        switch containerMode {
        case .inspector:
            return layoutClass == .padExpanded ? 860 : 760
        case .sheet:
            return 720
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.showsModePicker {
                Picker("Item Type", selection: $viewModel.selectedMode) {
                    ForEach(viewModel.allowedModes) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, spacing.s16)
                .padding(.top, spacing.s8)
            }

            switch viewModel.selectedMode {
            case .task:
                AddTaskForedropView(
                    viewModel: viewModel.taskViewModel,
                    containerMode: containerMode,
                    showAddAnother: showAddAnother,
                    successFlash: $successFlash,
                    onCancel: onCancel,
                    onCreate: onTaskCreate,
                    onAddAnother: onTaskAddAnother,
                    onExpandToLarge: onExpandToLarge
                )
            case .habit:
                AddHabitForedropView(
                    viewModel: viewModel.habitViewModel,
                    containerMode: containerMode,
                    showAddAnother: showAddAnother,
                    successFlash: $successFlash,
                    onCancel: onCancel,
                    onCreate: onHabitCreate,
                    onAddAnother: onHabitAddAnother,
                    onExpandToLarge: onExpandToLarge
                )
            }
        }
        .taskerReadableContent(maxWidth: readableWidth, alignment: .center)
    }
}
