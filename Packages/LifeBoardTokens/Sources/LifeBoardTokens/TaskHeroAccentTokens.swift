@preconcurrency import SwiftUI
import UIKit

/// Surface, border and accent for the six Focus Now hero cards.
///
/// These were fixed pastel hexes in `SunriseEvaSheets.swift`. The cards draw
/// their title and summary in the adaptive clay inks, which turn cream in dark
/// appearance, so in dark the task title sat cream-on-pastel at roughly 1.2:1.
/// Each hero now has a deep tint of the same hue for dark, and an accent that
/// clears 4.5:1 on its own surface in both appearances (the light sunrise
/// accent was 3.45:1 and is darkened). Measured 2026-09-18:
/// `navy`, `navyMuted` and the accent all clear 4.5:1 on every surface.
public enum TaskHeroAccentRole: String, CaseIterable, Sendable {
    case meditation
    case clouds
    case lake
    case greenPath
    case sunrise
    case desk

    public var surface: UIColor {
        switch self {
        case .meditation: Self.adaptive(light: "#FFF4EA", dark: "#2A2420")
        case .clouds: Self.adaptive(light: "#F4FAFF", dark: "#1C2638")
        case .lake: Self.adaptive(light: "#F4EEFF", dark: "#241F3A")
        case .greenPath: Self.adaptive(light: "#F2FAEE", dark: "#1C2A22")
        case .sunrise: Self.adaptive(light: "#FFF0E6", dark: "#2E221C")
        case .desk: Self.adaptive(light: "#FFF7EC", dark: "#2A241C")
        }
    }

    public var border: UIColor {
        switch self {
        case .meditation, .greenPath: Self.adaptive(light: "#CFE6C5", dark: "#35523F")
        case .clouds: Self.adaptive(light: "#D5E6F7", dark: "#2F4466")
        case .lake: Self.adaptive(light: "#D9C9FF", dark: "#4A3D78")
        case .sunrise, .desk: Self.adaptive(light: "#F2D9C4", dark: "#5A4230")
        }
    }

    public var accent: UIColor {
        switch self {
        case .meditation, .greenPath: Self.adaptive(light: "#2F7A4D", dark: "#8FD3A6")
        case .clouds: Self.adaptive(light: "#4F2CFF", dark: "#C7B9FF")
        case .lake: Self.adaptive(light: "#6F57B8", dark: "#C3B5FF")
        case .sunrise: Self.adaptive(light: "#A8521E", dark: "#F0A874")
        case .desk: Self.adaptive(light: "#4A3A2A", dark: "#E7DFD1")
        }
    }

    private static func adaptive(light: String, dark: String) -> UIColor {
        UIColor { traits in
            UIColor(lifeboardHex: traits.userInterfaceStyle == .dark ? dark : light)
        }
    }
}
