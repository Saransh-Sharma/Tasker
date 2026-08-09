//
//  OnboardingTaskDetailDismissBridge.swift
//  LifeBoard
//

import UIKit

final class OnboardingTaskDetailDismissBridge: NSObject, UIAdaptivePresentationControllerDelegate {
    private let onDismiss: () -> Void

    init(onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
    }

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        onDismiss()
    }
}
