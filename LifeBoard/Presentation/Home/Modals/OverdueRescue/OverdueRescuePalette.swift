//
//  EvaOverdueRescueSheetV2.swift
//  LifeBoard
//
//  Screenshot-aligned Overdue Rescue decision deck.
//

import SwiftUI
import UIKit

enum OverdueRescuePalette {
    static let ink = adaptiveColor(
        light: uiColor(red: 0.03, green: 0.14, blue: 0.36),
        dark: uiColor(red: 0.92, green: 0.94, blue: 1.0)
    )
    static let secondaryInk = adaptiveColor(
        light: uiColor(red: 0.28, green: 0.39, blue: 0.56),
        dark: uiColor(red: 0.72, green: 0.78, blue: 0.90)
    )
    static let backgroundTop = adaptiveColor(
        light: uiColor(red: 1.0, green: 0.995, blue: 0.975),
        dark: uiColor(red: 0.04, green: 0.055, blue: 0.10)
    )
    static let backgroundMid = adaptiveColor(
        light: uiColor(red: 1.0, green: 0.975, blue: 0.925),
        dark: uiColor(red: 0.07, green: 0.07, blue: 0.14)
    )
    static let backgroundBottom = adaptiveColor(
        light: uiColor(red: 1.0, green: 0.995, blue: 0.985),
        dark: uiColor(red: 0.03, green: 0.045, blue: 0.08)
    )
    static let glassFill = adaptiveColor(
        light: uiColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.72),
        dark: uiColor(red: 0.10, green: 0.12, blue: 0.19, alpha: 0.78)
    )
    static let glassStroke = adaptiveColor(
        light: uiColor(red: 0.88, green: 0.82, blue: 0.72, alpha: 0.42),
        dark: uiColor(red: 0.58, green: 0.55, blue: 0.86, alpha: 0.30)
    )
    // Front task-card surface. Light keeps the warm cream gradient; dark uses an
    // elevated surface in the same family as `glassFill` so the adaptive `ink`
    // text stays legible.
    static let cardSurfaceTop = adaptiveColor(
        light: uiColor(red: 1.0, green: 0.985, blue: 0.93),
        dark: uiColor(red: 0.12, green: 0.13, blue: 0.20)
    )
    static let cardSurfaceBottom = adaptiveColor(
        light: uiColor(red: 1.0, green: 0.995, blue: 0.985),
        dark: uiColor(red: 0.09, green: 0.10, blue: 0.16)
    )
    static let cardStroke = adaptiveColor(
        light: uiColor(red: 0.97, green: 0.87, blue: 0.67),
        dark: uiColor(red: 0.58, green: 0.55, blue: 0.86, alpha: 0.28)
    )
    // Body copy inside the inner "needs a decision" box.
    static let innerBody = adaptiveColor(
        light: uiColor(red: 0.38, green: 0.36, blue: 0.33),
        dark: uiColor(red: 0.80, green: 0.80, blue: 0.84)
    )
    static let softShadow = adaptiveColor(
        light: uiColor(red: 0.18, green: 0.12, blue: 0.06, alpha: 0.10),
        dark: uiColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.42)
    )
    static let progressTrack = adaptiveColor(
        light: uiColor(red: 0.86, green: 0.86, blue: 0.89),
        dark: uiColor(red: 0.23, green: 0.27, blue: 0.36)
    )
    static let accentPrimary = adaptiveColor(
        light: uiColor(red: 0.37, green: 0.23, blue: 1.0),
        dark: uiColor(red: 0.73, green: 0.66, blue: 1.0)
    )
    static let accentSoftFill = adaptiveColor(
        light: uiColor(red: 0.94, green: 0.91, blue: 1.0, alpha: 0.74),
        dark: uiColor(red: 0.18, green: 0.15, blue: 0.30, alpha: 0.88)
    )
    static let accentSoftStroke = adaptiveColor(
        light: uiColor(red: 0.37, green: 0.23, blue: 1.0, alpha: 0.26),
        dark: uiColor(red: 0.73, green: 0.66, blue: 1.0, alpha: 0.42)
    )
    static let accentGradient = LinearGradient(
        colors: [
            adaptiveColor(
                light: uiColor(red: 0.37, green: 0.23, blue: 1.0),
                dark: uiColor(red: 0.57, green: 0.45, blue: 1.0)
            ),
            adaptiveColor(
                light: uiColor(red: 0.23, green: 0.20, blue: 0.98),
                dark: uiColor(red: 0.41, green: 0.34, blue: 0.94)
            )
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let keepFill = adaptiveColor(
        light: uiColor(red: 0.90, green: 0.96, blue: 0.92),
        dark: uiColor(red: 0.07, green: 0.16, blue: 0.11)
    )
    static let keepForeground = adaptiveColor(
        light: uiColor(red: 0.08, green: 0.61, blue: 0.27),
        dark: uiColor(red: 0.46, green: 0.89, blue: 0.56)
    )

    static let moveFill = adaptiveColor(
        light: uiColor(red: 1.0, green: 0.94, blue: 0.82),
        dark: uiColor(red: 0.19, green: 0.15, blue: 0.07)
    )
    static let moveForeground = adaptiveColor(
        light: uiColor(red: 0.91, green: 0.52, blue: 0.02),
        dark: uiColor(red: 1.0, green: 0.82, blue: 0.48)
    )

    static let editFill = adaptiveColor(
        light: uiColor(red: 0.91, green: 0.94, blue: 1.0),
        dark: uiColor(red: 0.08, green: 0.13, blue: 0.22)
    )
    static let editForeground = adaptiveColor(
        light: uiColor(red: 0.11, green: 0.46, blue: 0.96),
        dark: uiColor(red: 0.47, green: 0.70, blue: 1.0)
    )

    static let deleteFill = adaptiveColor(
        light: uiColor(red: 1.0, green: 0.92, blue: 0.91),
        dark: uiColor(red: 0.22, green: 0.08, blue: 0.08)
    )
    static let deleteForeground = adaptiveColor(
        light: uiColor(red: 0.93, green: 0.15, blue: 0.14),
        dark: uiColor(red: 1.0, green: 0.47, blue: 0.45)
    )

    // Deck-stack back cards. Light keeps the peach/blue/lavender/cream hues; dark
    // uses deep, low-luminance same-hue equivalents so the stack still reads as
    // layered against the dark rescue background.
    static func backCard(_ index: Int) -> Color {
        switch index {
        case 0:
            return adaptiveColor(
                light: uiColor(red: 1.0, green: 0.91, blue: 0.83),
                dark: uiColor(red: 0.20, green: 0.14, blue: 0.11)
            )
        case 1:
            return adaptiveColor(
                light: uiColor(red: 0.91, green: 0.96, blue: 1.0),
                dark: uiColor(red: 0.11, green: 0.15, blue: 0.22)
            )
        case 2:
            return adaptiveColor(
                light: uiColor(red: 0.94, green: 0.90, blue: 1.0),
                dark: uiColor(red: 0.16, green: 0.14, blue: 0.24)
            )
        default:
            return adaptiveColor(
                light: uiColor(red: 1.0, green: 0.96, blue: 0.86),
                dark: uiColor(red: 0.16, green: 0.15, blue: 0.11)
            )
        }
    }

    private static func adaptiveColor(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }

    private static func uiColor(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat = 1.0) -> UIColor {
        UIColor(red: red, green: green, blue: blue, alpha: alpha)
    }
}
