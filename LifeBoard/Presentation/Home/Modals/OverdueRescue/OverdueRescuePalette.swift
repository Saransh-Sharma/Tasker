//
//  EvaOverdueRescueSheetV2.swift
//  LifeBoard
//
//  Screenshot-aligned Overdue Rescue decision deck.
//

import SwiftUI
import UIKit

enum OverdueRescuePalette {
    static let ink = Color(red: 0.03, green: 0.14, blue: 0.36)
    static let secondaryInk = Color(red: 0.28, green: 0.39, blue: 0.56)
    static let backgroundTop = Color(red: 1.0, green: 0.995, blue: 0.975)
    static let backgroundMid = Color(red: 1.0, green: 0.975, blue: 0.925)
    static let backgroundBottom = Color(red: 1.0, green: 0.995, blue: 0.985)
    static let glassFill = Color.white.opacity(0.72)
    static let glassStroke = Color(red: 0.88, green: 0.82, blue: 0.72).opacity(0.42)
    static let softShadow = Color(red: 0.18, green: 0.12, blue: 0.06).opacity(0.10)
    static let progressTrack = Color(red: 0.86, green: 0.86, blue: 0.89)
    static let accentGradient = LinearGradient(
        colors: [
            Color(red: 0.37, green: 0.23, blue: 1.0),
            Color(red: 0.23, green: 0.20, blue: 0.98)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let keepFill = Color(red: 0.90, green: 0.96, blue: 0.92)
    static let keepForeground = Color(red: 0.08, green: 0.61, blue: 0.27)

    static let moveFill = Color(red: 1.0, green: 0.94, blue: 0.82)
    static let moveForeground = Color(red: 0.91, green: 0.52, blue: 0.02)

    static let editFill = Color(red: 0.91, green: 0.94, blue: 1.0)
    static let editForeground = Color(red: 0.11, green: 0.46, blue: 0.96)

    static let deleteFill = Color(red: 1.0, green: 0.92, blue: 0.91)
    static let deleteForeground = Color(red: 0.93, green: 0.15, blue: 0.14)
}
