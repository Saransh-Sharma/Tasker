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
                AddItemModeSwitcher(
                    selectedMode: $viewModel.selectedMode,
                    allowedModes: viewModel.allowedModes
                )
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

private struct AddItemModeSwitcher: View {
    @Binding var selectedMode: AddItemMode
    let allowedModes: [AddItemMode]

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }

    var body: some View {
        HStack(spacing: spacing.s8) {
            ForEach(allowedModes) { mode in
                let isSelected = selectedMode == mode
                Button {
                    guard selectedMode != mode else { return }
                    TaskerFeedback.selection()
                    withAnimation(TaskerAnimation.snappy) {
                        selectedMode = mode
                    }
                } label: {
                    Text(mode.displayName)
                        .font(.tasker(.callout).weight(.semibold))
                        .foregroundStyle(isSelected ? Color.tasker.accentOnPrimary : Color.tasker.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 40)
                        .background(
                            Capsule()
                                .fill(isSelected ? Color.tasker.accentPrimary : Color.clear)
                        )
                }
                .buttonStyle(.plain)
                .scaleOnPress()
                .accessibilityIdentifier("addItem.mode.\(mode.rawValue)")
                .accessibilityLabel(mode.displayName)
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }
        }
        .padding(spacing.s4)
        .taskerChromeSurface(
            cornerRadius: TaskerTheme.CornerRadius.pill,
            accentColor: Color.tasker.accentSecondary,
            level: .e1
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("addItem.modePicker")
    }
}
