import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

extension AppOnboardingSummary {
    enum CodingKeys: String, CodingKey {
        case lifeAreaCount
        case projectCount
        case createdHabitCount
        case createdHabitTitles
        case createdHabitCurrentStreak
        case createdHabitBestStreak
        case createdTaskCount
        case completedTaskCount
        case completedTaskTitle
        case nextTaskTitle
        case evaState
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        lifeAreaCount = try container.decode(Int.self, forKey: .lifeAreaCount)
        projectCount = try container.decode(Int.self, forKey: .projectCount)
        createdHabitCount = try container.decodeIfPresent(Int.self, forKey: .createdHabitCount) ?? 0
        createdHabitTitles = try container.decodeIfPresent([String].self, forKey: .createdHabitTitles) ?? []
        createdHabitCurrentStreak = try container.decodeIfPresent(Int.self, forKey: .createdHabitCurrentStreak) ?? 0
        createdHabitBestStreak = try container.decodeIfPresent(Int.self, forKey: .createdHabitBestStreak) ?? createdHabitCurrentStreak
        createdTaskCount = try container.decode(Int.self, forKey: .createdTaskCount)
        completedTaskCount = try container.decode(Int.self, forKey: .completedTaskCount)
        completedTaskTitle = try container.decodeIfPresent(String.self, forKey: .completedTaskTitle)
        nextTaskTitle = try container.decodeIfPresent(String.self, forKey: .nextTaskTitle)
        evaState = try container.decodeIfPresent(OnboardingEvaPreparationState.self, forKey: .evaState) ?? OnboardingEvaPreparationState()
    }
}
