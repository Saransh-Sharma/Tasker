import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

struct OnboardingProjectDraft: Identifiable, Codable, Equatable {
    let id: UUID
    let lifeAreaTemplateID: String
    var templateID: String
    var name: String
    var summary: String
    var suggestionTemplateIDs: [String]
    var suggestionIndex: Int
    var isSelected: Bool

    init(
        id: UUID = UUID(),
        lifeAreaTemplateID: String,
        templateID: String,
        name: String,
        summary: String,
        suggestionTemplateIDs: [String],
        suggestionIndex: Int,
        isSelected: Bool = true
    ) {
        self.id = id
        self.lifeAreaTemplateID = lifeAreaTemplateID
        self.templateID = templateID
        self.name = name
        self.summary = summary
        self.suggestionTemplateIDs = suggestionTemplateIDs
        self.suggestionIndex = suggestionIndex
        self.isSelected = isSelected
    }
}
