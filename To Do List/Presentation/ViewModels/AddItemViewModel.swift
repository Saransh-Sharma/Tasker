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

@MainActor
public final class AddItemViewModel: ObservableObject {
    @Published public var selectedMode: AddItemMode

    public let taskViewModel: AddTaskViewModel
    public let habitViewModel: AddHabitViewModel

    public init(
        taskViewModel: AddTaskViewModel,
        habitViewModel: AddHabitViewModel,
        selectedMode: AddItemMode = .task
    ) {
        self.taskViewModel = taskViewModel
        self.habitViewModel = habitViewModel
        self.selectedMode = selectedMode
    }

    public var hasUnsavedChanges: Bool {
        switch selectedMode {
        case .task:
            return taskViewModel.hasUnsavedChanges
        case .habit:
            return habitViewModel.hasUnsavedChanges
        }
    }
}
