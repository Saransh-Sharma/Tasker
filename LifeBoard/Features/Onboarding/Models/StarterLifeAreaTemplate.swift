import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

struct StarterLifeAreaTemplate: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let subtitle: String
    let icon: String
    let colorHex: String
    let aliases: [String]
    let projects: [StarterProjectTemplate]
}
