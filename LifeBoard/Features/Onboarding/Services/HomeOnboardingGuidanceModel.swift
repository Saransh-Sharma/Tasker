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
        /// Invitations are dismissible and lead somewhere; completion guides are
        /// transient notices that clear themselves.
        var isInvitation = false
    }

    @Published private(set) var state: State?

    /// The non-blocking replacement for the established-workspace modal.
    ///
    /// Existing users used to be interrupted by a full-screen sheet before they
    /// could reach their own workspace. The Life Map is worth offering, but not
    /// worth seizing the launch for — so it arrives as a banner they can ignore
    /// forever, and the permanent entry lives in Life Management.
    func showLifeMapInvitation() {
        state = State(
            taskID: UUID(),
            title: "Build your Life Map",
            message: "Shape LifeBoard around what you're carrying. Your existing areas and records are preserved.",
            isInvitation: true
        )
    }

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
