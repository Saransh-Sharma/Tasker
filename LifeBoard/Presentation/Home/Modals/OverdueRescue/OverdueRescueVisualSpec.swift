//
//  EvaOverdueRescueSheetV2.swift
//  LifeBoard
//
//  Screenshot-aligned Overdue Rescue decision deck.
//

import SwiftUI
import UIKit

enum OverdueRescueVisualSpec {
    static let screenHorizontalPadding: CGFloat = 28
    static let topButtonSize: CGFloat = 58
    static let cardCorner: CGFloat = 34
    static let innerCardCorner: CGFloat = 22
    static let largeCardCorner: CGFloat = 28
    static let primaryButtonHeight: CGFloat = 68
    static let secondaryButtonHeight: CGFloat = 62
    static let primaryButtonCorner: CGFloat = 24
    static let sheetMaxWidth: CGFloat = 390

    static func primaryButtonBackground(cornerRadius: CGFloat = primaryButtonCorner) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(OverdueRescuePalette.accentGradient)
            .shadow(color: Color(red: 0.27, green: 0.18, blue: 0.93).opacity(0.22), radius: 18, y: 10)
    }

    static func glassCard(cornerRadius: CGFloat = largeCardCorner, fill: Color = OverdueRescuePalette.glassFill) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(fill)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(OverdueRescuePalette.glassStroke, lineWidth: 1)
            )
            .shadow(color: OverdueRescuePalette.softShadow, radius: 24, y: 12)
    }
}
