import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

struct AppOnboardingSummary: Codable, Equatable {
    let lifeAreaCount: Int
    let projectCount: Int
    let createdHabitCount: Int
    let createdHabitTitles: [String]
    let createdHabitCurrentStreak: Int
    let createdHabitBestStreak: Int
    let createdTaskCount: Int
    let completedTaskCount: Int
    let completedTaskTitle: String?
    let nextTaskTitle: String?
    let evaState: OnboardingEvaPreparationState

    init(
        lifeAreaCount: Int,
        projectCount: Int,
        createdHabitCount: Int = 0,
        createdHabitTitles: [String] = [],
        createdHabitCurrentStreak: Int = 0,
        createdHabitBestStreak: Int = 0,
        createdTaskCount: Int,
        completedTaskCount: Int,
        completedTaskTitle: String?,
        nextTaskTitle: String?,
        evaState: OnboardingEvaPreparationState
    ) {
        self.lifeAreaCount = lifeAreaCount
        self.projectCount = projectCount
        self.createdHabitCount = createdHabitCount
        self.createdHabitTitles = createdHabitTitles
        self.createdHabitCurrentStreak = createdHabitCurrentStreak
        self.createdHabitBestStreak = createdHabitBestStreak
        self.createdTaskCount = createdTaskCount
        self.completedTaskCount = completedTaskCount
        self.completedTaskTitle = completedTaskTitle
        self.nextTaskTitle = nextTaskTitle
        self.evaState = evaState
    }
}
