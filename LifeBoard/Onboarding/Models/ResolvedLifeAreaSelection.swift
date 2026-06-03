import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

struct ResolvedLifeAreaSelection: Codable, Equatable {
    let templateID: String
    let lifeArea: LifeArea
    let reusedExisting: Bool
}
