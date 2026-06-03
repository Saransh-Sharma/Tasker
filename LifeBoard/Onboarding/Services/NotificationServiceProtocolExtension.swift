import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

extension NotificationServiceProtocol {
    func fetchAuthorizationStatusAsync() async -> LifeBoardNotificationAuthorizationStatus {
        await withCheckedContinuation { continuation in
            fetchAuthorizationStatus { status in
                continuation.resume(returning: status)
            }
        }
    }

    func requestPermissionAsync() async -> Bool {
        await withCheckedContinuation { continuation in
            requestPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}
