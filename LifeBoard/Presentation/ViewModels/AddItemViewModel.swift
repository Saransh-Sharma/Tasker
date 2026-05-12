import Combine
import Foundation
import SwiftUI

public enum AddItemMode: String, CaseIterable, Identifiable {
    case task
    case habit

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .task: return "Task"
        case .habit: return "Habit"
        }
    }
}

public enum AddItemModePolicy: Equatable {
    case taskOnly
    case habitOnly
    case unified(defaultMode: AddItemMode = .task)

    public var allowedModes: [AddItemMode] {
        switch self {
        case .taskOnly:
            return [.task]
        case .habitOnly:
            return [.habit]
        case .unified:
            return AddItemMode.allCases
        }
    }

    public var defaultMode: AddItemMode {
        switch self {
        case .taskOnly:
            return .task
        case .habitOnly:
            return .habit
        case .unified(let defaultMode):
            return defaultMode
        }
    }
}

@MainActor
public final class AddItemViewModel: ObservableObject {
    @Published public var selectedMode: AddItemMode

    public let taskViewModel: AddTaskViewModel
    public let habitViewModel: AddHabitViewModel
    public let allowedModes: [AddItemMode]
    private var cancellables = Set<AnyCancellable>()

    public init(
        taskViewModel: AddTaskViewModel,
        habitViewModel: AddHabitViewModel,
        allowedModes: [AddItemMode] = AddItemMode.allCases,
        selectedMode: AddItemMode = .task
    ) {
        self.taskViewModel = taskViewModel
        self.habitViewModel = habitViewModel
        self.allowedModes = allowedModes.isEmpty ? AddItemMode.allCases : allowedModes
        self.selectedMode = self.allowedModes.contains(selectedMode) ? selectedMode : self.allowedModes[0]

        taskViewModel.objectWillChange
            .sink { [weak self] _ in
                guard let self, self.selectedMode == .task else { return }
                self.objectWillChange.send()
            }
            .store(in: &cancellables)

        habitViewModel.objectWillChange
            .sink { [weak self] _ in
                guard let self, self.selectedMode == .habit else { return }
                self.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    public var showsModePicker: Bool {
        allowedModes.count > 1
    }

    public var hasUnsavedChanges: Bool {
        taskViewModel.hasUnsavedChanges || habitViewModel.hasUnsavedChanges
    }
}
