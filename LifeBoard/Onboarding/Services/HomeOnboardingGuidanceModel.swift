import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

@MainActor
final class HomeOnboardingGuidanceModel: ObservableObject {
    struct State: Equatable {
        let taskID: UUID
        let title: String
        let message: String
    }

    @Published private(set) var state: State?

    func showCompletionGuide(task: TaskDefinition) {
        state = State(
            taskID: task.id,
            title: "Your first task is ready",
            message: "Finish \"\(task.title)\" to complete setup."
        )
    }

    func showHabitGuide(habit: HabitDefinitionRecord) {
        state = State(
            taskID: habit.id,
            title: "Your starter habit is ready",
            message: "\"\(habit.title)\" will show up on Home so tomorrow feels easier to start."
        )
    }

    func clear() {
        state = nil
    }
}
