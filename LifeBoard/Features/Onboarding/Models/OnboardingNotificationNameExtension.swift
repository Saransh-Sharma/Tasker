import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

extension Notification.Name {
    static let lifeboardStartOnboardingRequested = Notification.Name("LifeBoardStartOnboardingRequested")
    static let lifeboardOpenSetupCenterDeepLink = Notification.Name("LifeBoardOpenSetupCenterDeepLink")

    /// Posted by the Life OS shell on its first frame. First run used to be
    /// triggered only by the legacy Home controller switching to its tasks face,
    /// which never happens when the adaptive Home is the root.
    static let lifeboardShellDidBecomeInteractive = Notification.Name("LifeBoardShellDidBecomeInteractive")
}
