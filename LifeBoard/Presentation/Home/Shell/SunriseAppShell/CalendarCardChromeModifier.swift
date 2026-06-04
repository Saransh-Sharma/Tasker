//
//  SunriseAppShellView.swift
//  LifeBoard
//
//  New SwiftUI Home shell with backdrop/sunrise pattern.
//

import SwiftUI
import UIKit
import Combine

struct CalendarCardChromeModifier: ViewModifier {
    @Environment(\.lifeboardLayoutClass) private var layoutClass

    var spacing: LifeBoardSpacingTokens {
        LifeBoardThemeManager.shared.tokens(for: layoutClass).spacing
    }

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, spacing.s16)
            .padding(.vertical, spacing.s12)
            .background(
                RoundedRectangle(cornerRadius: LifeBoardTheme.CornerRadius.card, style: .continuous)
                    .fill(Color.lifeboard.surfacePrimary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: LifeBoardTheme.CornerRadius.card, style: .continuous)
                    .stroke(Color.lifeboard.strokeHairline.opacity(0.72), lineWidth: 1)
            )
    }
}
