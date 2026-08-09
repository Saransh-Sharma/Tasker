import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

struct StarterProjectTemplate: Identifiable, Equatable, Sendable {
    let id: String
    let lifeAreaTemplateID: String
    let name: String
    let summary: String
    let aliases: [String]
    let taskTemplates: [StarterTaskTemplate]
}
