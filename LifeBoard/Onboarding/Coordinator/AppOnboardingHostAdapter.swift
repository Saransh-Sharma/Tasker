import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

@MainActor
protocol AppOnboardingHostAdapter: AnyObject {
    var currentOnboardingLayoutClass: LifeBoardLayoutClass { get }
    var presentedViewController: UIViewController? { get }

    func prepareForOnboardingHomeGuidance()
    func present(_ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)?)
    func makeOnboardingAddTaskController(
        prefill: AddTaskPrefillTemplate,
        onTaskCreated: @escaping (UUID) -> Void,
        onDismissWithoutTask: (() -> Void)?
    ) -> UIViewController?
    func makeOnboardingAddHabitController(
        prefill: AddHabitPrefillTemplate,
        onHabitCreated: @escaping (UUID) -> Void,
        onDismissWithoutTask: (() -> Void)?
    ) -> UIViewController?
    func makeOnboardingTaskDetailController(
        task: TaskDefinition,
        onDismiss: @escaping () -> Void
    ) -> UIViewController?
}
