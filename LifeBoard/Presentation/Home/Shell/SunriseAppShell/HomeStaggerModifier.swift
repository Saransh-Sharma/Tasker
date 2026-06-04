//
//  SunriseAppShellView.swift
//  LifeBoard
//
//  New SwiftUI Home shell with backdrop/sunrise pattern.
//

import SwiftUI
import UIKit
import Combine

struct HomeStaggerModifier: ViewModifier {
    let isEnabled: Bool
    let index: Int

    func body(content: Content) -> some View {
        if isEnabled {
            content.enhancedStaggeredAppearance(index: index)
        } else {
            content
        }
    }
}
