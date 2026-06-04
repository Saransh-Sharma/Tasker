import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

struct StarterHabitTemplate: Identifiable, Equatable, Sendable {
    let id: String
    let lifeAreaTemplateID: String
    let projectTemplateID: String?
    let title: String
    let reason: String
    let kind: HabitKind
    let trackingMode: HabitTrackingMode
    let cadence: HabitCadenceDraft
    let icon: HabitIconMetadata
    let notes: String?
    let recommendedProfiles: Set<OnboardingFrictionProfile>

    var isPositive: Bool {
        kind == .positive
    }

    func makePrefill(lifeAreaID: UUID, projectID: UUID?) -> AddHabitPrefillTemplate {
        AddHabitPrefillTemplate(
            title: title,
            notes: notes,
            lifeAreaID: lifeAreaID,
            projectID: projectID,
            kind: kind == .positive ? .positive : .negative,
            trackingMode: trackingMode == .dailyCheckIn ? .dailyCheckIn : .lapseOnly,
            cadence: cadence,
            iconSymbolName: icon.symbolName
        )
    }

    func makeRequest(lifeAreaID: UUID, projectID: UUID?) -> CreateHabitRequest {
        CreateHabitRequest(
            title: title,
            lifeAreaID: lifeAreaID,
            projectID: projectID,
            kind: kind,
            trackingMode: trackingMode,
            icon: icon,
            targetConfig: HabitTargetConfig(notes: notes, targetCountPerDay: 1),
            metricConfig: HabitMetricConfig(unitLabel: nil, showNotesOnCompletion: notes != nil),
            cadence: cadence
        )
    }
}
