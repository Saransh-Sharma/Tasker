// Device+Notch.swift
// Provides a shared UIDevice extension for notch detection

import UIKit

extension UIDevice {
    /// `true` on iPhone X-style (notched) devices
    var hasNotch: Bool {
        guard #available(iOS 11.0, *) else { return false }
        let windowScene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        let window = windowScene?.windows.first(where: \.isKeyWindow) ?? windowScene?.windows.first
        let topInset = window?.safeAreaInsets.top ?? 0
        return topInset > 20
    }
}
