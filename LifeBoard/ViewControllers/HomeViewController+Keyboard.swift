//
//  HomeViewController+Keyboard.swift
//  LifeBoard
//
//  Move-only HomeViewController decomposition.
//

import UIKit
import SwiftUI
@preconcurrency import Combine
import SwiftData


extension HomeViewController {
    func observeKeyboardFrameChanges() {
        notificationCenter.publisher(for: UIResponder.keyboardWillChangeFrameNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                self?.handleKeyboardFrameChange(notification)
            }
            .store(in: &cancellables)

        notificationCenter.publisher(for: UIResponder.keyboardWillHideNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.setKeyboardOverlapHeight(0)
            }
            .store(in: &cancellables)
    }

    func handleKeyboardFrameChange(_ notification: Notification) {
        guard currentLayoutClass == .phone else {
            setKeyboardOverlapHeight(0)
            return
        }

        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
            return
        }

        let keyboardFrameInView = view.convert(keyboardFrame, from: nil)
        let overlapHeight = max(0, view.bounds.maxY - keyboardFrameInView.minY)
        let adjustedOverlapHeight = max(0, overlapHeight - view.safeAreaInsets.bottom)
        setKeyboardOverlapHeight(adjustedOverlapHeight)
    }

    func setKeyboardOverlapHeight(_ newValue: CGFloat) {
        let sanitizedValue = max(0, newValue)
        guard abs(keyboardOverlapHeight - sanitizedValue) > 0.5 else { return }
        keyboardOverlapHeight = sanitizedValue
        refreshLayoutMetrics()
        mountBottomBarOverlayIfNeeded(animated: true)
        updateBottomBarBottomConstraint(animated: true)
    }

    var isBottomBarConcealedForChatInput: Bool {
        HomeBottomBarVisibilityPolicy.shouldConcealBottomBar(
            activeFace: faceCoordinator.activeFace,
            isPromptFocused: isEmbeddedChatPromptFocused,
            keyboardOverlapHeight: keyboardOverlapHeight
        )
    }

    func setEmbeddedChatPromptFocused(_ isFocused: Bool) {
        guard isEmbeddedChatPromptFocused != isFocused else {
            refreshLayoutMetrics()
            mountBottomBarOverlayIfNeeded(animated: true)
            updateBottomBarBottomConstraint(animated: true)
            return
        }
        isEmbeddedChatPromptFocused = isFocused
        refreshLayoutMetrics()
        mountBottomBarOverlayIfNeeded(animated: true)
        updateBottomBarBottomConstraint(animated: true)
    }
}
