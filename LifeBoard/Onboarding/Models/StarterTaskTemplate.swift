import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

struct StarterTaskTemplate: Identifiable, Equatable, Sendable {
    let id: String
    let projectTemplateID: String
    let title: String
    let reason: String
    let durationMinutes: Int
    let priority: TaskPriority
    let type: TaskType
    let energy: TaskEnergy
    let category: TaskCategory
    let context: TaskContext
    let dueDateIntent: AddTaskPrefillDueIntent
    let isQuickWin: Bool
    let clearDoneState: Bool
    let recommendedProfiles: Set<OnboardingFrictionProfile>

    func makePrefill(project: Project) -> AddTaskPrefillTemplate {
        AddTaskPrefillTemplate(
            title: title,
            details: nil,
            projectID: project.id,
            projectName: project.name,
            lifeAreaID: project.lifeAreaID,
            priority: priority,
            type: type,
            dueDateIntent: dueDateIntent,
            estimatedDuration: TimeInterval(durationMinutes * 60),
            energy: energy,
            category: category,
            context: context,
            showMoreDetails: false,
            showAdvancedPlanning: false
        )
    }

    func makeRequest(project: Project) -> CreateTaskDefinitionRequest {
        CreateTaskDefinitionRequest(
            title: title,
            details: nil,
            projectID: project.id,
            projectName: project.name,
            lifeAreaID: project.lifeAreaID,
            dueDate: dueDateIntent.resolvedDate(),
            priority: priority,
            type: type,
            energy: energy,
            category: category,
            context: context,
            estimatedDuration: TimeInterval(durationMinutes * 60),
            createdAt: Date()
        )
    }
}
