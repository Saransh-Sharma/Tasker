//
//  AddTaskSheetView.swift
//  LifeBoard
//
//  V3-native Add sheet. Backward compatible with task-only callers, but now
//  scaffolded as a unified Task / Habit composer.
//

import SwiftUI

public enum AddTaskContainerMode: Equatable {
    case sheet
    case inspector
}

private enum AddItemSubmissionBehavior {
    case dismiss
    case addAnother
}

public struct AddTaskSheetView: View {
    @StateObject private var viewModel: AddItemViewModel
    @Environment(\.dismiss) private var dismiss
    private let onTaskCreated: ((UUID) -> Void)?
    private let onHabitCreated: ((UUID) -> Void)?
    private let onDismissWithoutTask: (() -> Void)?

    @State private var showDiscardConfirmation = false
    @State private var showAddAnother = false
    @State private var successFlash = false
    @State private var selectedDetent: PresentationDetent = .medium
    @State private var didCreateItem = false
    @State private var pendingTaskBehavior: AddItemSubmissionBehavior?
    @State private var successResetTask: Task<Void, Never>?

    public init(
        viewModel: AddTaskViewModel,
        habitViewModel: AddHabitViewModel,
        modePolicy: AddItemModePolicy? = nil,
        onTaskCreated: ((UUID) -> Void)? = nil,
        onHabitCreated: ((UUID) -> Void)? = nil,
        onDismissWithoutTask: (() -> Void)? = nil
    ) {
        let resolvedModePolicy = modePolicy ?? .taskOnly
        let allowedModes = resolvedModePolicy.allowedModes
        _viewModel = StateObject(
            wrappedValue: AddItemViewModel(
                taskViewModel: viewModel,
                habitViewModel: habitViewModel,
                allowedModes: allowedModes,
                selectedMode: resolvedModePolicy.defaultMode
            )
        )
        self.onTaskCreated = onTaskCreated
        self.onHabitCreated = onHabitCreated
        self.onDismissWithoutTask = onDismissWithoutTask
    }

    public init(
        itemViewModel: AddItemViewModel,
        modePolicy: AddItemModePolicy? = nil,
        onTaskCreated: ((UUID) -> Void)? = nil,
        onHabitCreated: ((UUID) -> Void)? = nil,
        onDismissWithoutTask: (() -> Void)? = nil
    ) {
        let resolvedModePolicy = modePolicy ?? Self.defaultModePolicy(for: itemViewModel)
        let allowedModes = resolvedModePolicy.allowedModes
        _viewModel = StateObject(
            wrappedValue: AddItemViewModel(
                taskViewModel: itemViewModel.taskViewModel,
                habitViewModel: itemViewModel.habitViewModel,
                allowedModes: allowedModes,
                selectedMode: allowedModes.contains(itemViewModel.selectedMode) ? itemViewModel.selectedMode : resolvedModePolicy.defaultMode
            )
        )
        self.onTaskCreated = onTaskCreated
        self.onHabitCreated = onHabitCreated
        self.onDismissWithoutTask = onDismissWithoutTask
    }

    public var body: some View {
        AddItemComposerView(
            viewModel: viewModel,
            containerMode: .sheet,
            showAddAnother: showAddAnother,
            successFlash: $successFlash,
            onCancel: handleCancel,
            onTaskCreate: handleTaskCreate,
            onTaskAddAnother: handleTaskAddAnother,
            onHabitCreate: handleHabitCreate,
            onHabitAddAnother: handleHabitAddAnother,
            onExpandToLarge: expandToLarge
        )
        .presentationDetents([.medium, .large], selection: $selectedDetent)
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(24)
        .interactiveDismissDisabled(viewModel.hasUnsavedChanges)
        .confirmationDialog(
            "Discard changes?",
            isPresented: $showDiscardConfirmation,
            titleVisibility: .visible
        ) {
            Button("Discard", role: .destructive) {
                dismiss()
            }
            Button("Keep Editing", role: .cancel) {}
        } message: {
            Text("You have unsaved changes that will be lost.")
        }
        .onDisappear {
            successResetTask?.cancel()
            if didCreateItem == false {
                onDismissWithoutTask?()
            }
        }
        .onChange(of: viewModel.taskViewModel.lastCreatedTaskID) { _, taskID in
            guard let taskID, let behavior = pendingTaskBehavior else { return }
            handleCreatedTask(taskID, behavior: behavior)
        }
    }

    private static func defaultModePolicy(for itemViewModel: AddItemViewModel) -> AddItemModePolicy {
        switch itemViewModel.allowedModes {
        case [.task]:
            return .taskOnly
        case [.habit]:
            return .habitOnly
        default:
            let defaultMode = itemViewModel.allowedModes.contains(itemViewModel.selectedMode)
                ? itemViewModel.selectedMode
                : itemViewModel.allowedModes.first ?? .task
            return .unified(defaultMode: defaultMode)
        }
    }

    private func handleCancel() {
        if viewModel.hasUnsavedChanges {
            LifeBoardFeedback.medium()
            showDiscardConfirmation = true
        } else {
            LifeBoardFeedback.light()
            dismiss()
        }
    }

    private func handleTaskCreate() {
        guard viewModel.allowedModes.contains(.task) else { return }
        guard viewModel.taskViewModel.viewState.canSubmit, !viewModel.taskViewModel.isLoading else { return }
        pendingTaskBehavior = .dismiss
        showAddAnother = false
        viewModel.taskViewModel.createTask()
    }

    private func handleTaskAddAnother() {
        guard viewModel.allowedModes.contains(.task) else { return }
        guard viewModel.taskViewModel.viewState.canSubmit, !viewModel.taskViewModel.isLoading else { return }
        pendingTaskBehavior = .addAnother
        showAddAnother = false
        viewModel.taskViewModel.createTask()
    }

    private func handleHabitCreate() {
        guard viewModel.allowedModes.contains(.habit) else { return }
        guard viewModel.habitViewModel.canSubmit, !viewModel.habitViewModel.isSaving else { return }
        viewModel.habitViewModel.createHabit { result in
            Task { @MainActor in
                guard case .success(let habit) = result else { return }
                didCreateItem = true
                onHabitCreated?(habit.id)
                LifeBoardFeedback.success()
                dismiss()
            }
        }
    }

    private func handleHabitAddAnother() {
        guard viewModel.allowedModes.contains(.habit) else { return }
        guard viewModel.habitViewModel.canSubmit, !viewModel.habitViewModel.isSaving else { return }
        viewModel.habitViewModel.createHabit { result in
            Task { @MainActor in
                guard case .success(let habit) = result else { return }
                didCreateItem = true
                onHabitCreated?(habit.id)
                runSuccessReset {
                    viewModel.habitViewModel.resetForm()
                    showAddAnother = true
                    selectedDetent = .medium
                }
            }
        }
    }

    private func expandToLarge() {
        LifeBoardFeedback.light()
        withAnimation(LifeBoardAnimation.gentle) {
            selectedDetent = .large
        }
    }

    private func handleCreatedTask(_ taskID: UUID, behavior: AddItemSubmissionBehavior) {
        guard viewModel.allowedModes.contains(.task) else {
            pendingTaskBehavior = nil
            return
        }
        pendingTaskBehavior = nil
        didCreateItem = true
        onTaskCreated?(taskID)

        switch behavior {
        case .dismiss:
            LifeBoardFeedback.success()
            dismiss()
        case .addAnother:
            runSuccessReset {
                viewModel.taskViewModel.resetForm()
                showAddAnother = true
                selectedDetent = .medium
            }
        }
    }

    private func runSuccessReset(afterReset: @escaping @MainActor () -> Void) {
        successResetTask?.cancel()
        LifeBoardFeedback.success()
        withAnimation(LifeBoardAnimation.snappy) {
            successFlash = true
        }
        successResetTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 450_000_000)
            guard Task.isCancelled == false else { return }
            withAnimation(LifeBoardAnimation.snappy) {
                successFlash = false
                afterReset()
            }
        }
    }
}

struct AddTaskInspectorContainer: View {
    @StateObject private var viewModel: AddItemViewModel
    @State private var successFlash = false
    @State private var pendingTaskCreation = false
    @State private var successResetTask: Task<Void, Never>?
    let onClose: () -> Void

    init(viewModel: AddTaskViewModel, habitViewModel: AddHabitViewModel, onClose: @escaping () -> Void) {
        _viewModel = StateObject(
            wrappedValue: AddItemViewModel(
                taskViewModel: viewModel,
                habitViewModel: habitViewModel
            )
        )
        self.onClose = onClose
    }

    var body: some View {
        AddItemComposerView(
            viewModel: viewModel,
            containerMode: .inspector,
            showAddAnother: false,
            successFlash: $successFlash,
            onCancel: onClose,
            onTaskCreate: handleTaskCreate,
            onTaskAddAnother: handleTaskCreate,
            onHabitCreate: handleHabitCreate,
            onHabitAddAnother: handleHabitCreate,
            onExpandToLarge: {}
        )
        .accessibilityIdentifier("home.ipad.detail.addTask")
        .onDisappear {
            successResetTask?.cancel()
        }
        .onChange(of: viewModel.taskViewModel.lastCreatedTaskID) { _, taskID in
            guard taskID != nil, pendingTaskCreation else { return }
            pendingTaskCreation = false
            runInspectorSuccessReset {
                viewModel.taskViewModel.resetForm()
            }
        }
    }

    private func handleTaskCreate() {
        guard viewModel.taskViewModel.viewState.canSubmit, !viewModel.taskViewModel.isLoading else { return }
        pendingTaskCreation = true
        viewModel.taskViewModel.createTask()
    }

    private func handleHabitCreate() {
        guard viewModel.habitViewModel.canSubmit, !viewModel.habitViewModel.isSaving else { return }
        viewModel.habitViewModel.createHabit { result in
            Task { @MainActor in
                guard case .success = result else { return }
                runInspectorSuccessReset {
                    viewModel.habitViewModel.resetForm()
                }
            }
        }
    }

    private func runInspectorSuccessReset(afterReset: @escaping @MainActor () -> Void) {
        successResetTask?.cancel()
        LifeBoardFeedback.success()
        withAnimation(LifeBoardAnimation.snappy) {
            successFlash = true
        }
        successResetTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard Task.isCancelled == false else { return }
            withAnimation(LifeBoardAnimation.snappy) {
                successFlash = false
                afterReset()
            }
        }
    }
}
