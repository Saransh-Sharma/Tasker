//
//  LifeBoardTheme+SwiftUI.swift
//  LifeBoard
//
//  SwiftUI namespace bridge for the token-based design system.
//  Provides LifeBoardTheme.Colors / .Typography / .Spacing / .CornerRadius
//  so Presentation views can reference tokens with a clean API.
//

import SwiftUI

// MARK: - LifeBoardTheme.Colors

extension LifeBoardTheme {
    @MainActor
    public enum Colors {
        // XP / Gamification
        public static var xpGold: Color { Color.lifeboard(.statusWarning) }
        public static var xpGoldLight: Color { Color.lifeboard(.accentSecondaryWash) }

        // Text
        public static var textPrimary: Color { Color.lifeboard(.textPrimary) }
        public static var textSecondary: Color { Color.lifeboard(.textSecondary) }
        public static var textTertiary: Color { Color.lifeboard(.textTertiary) }
        public static var textQuaternary: Color { Color.lifeboard(.textQuaternary) }

        // Surfaces
        public static var cardBackground: Color { Color.lifeboard(.surfacePrimary) }
        public static var background: Color { Color.lifeboard(.bgCanvas) }
        public static var backgroundSecondary: Color { Color.lifeboard(.bgCanvasSecondary) }
        public static var surfaceSecondary: Color { Color.lifeboard(.surfaceSecondary) }

        // Brand
        public static var brandPrimary: Color { Color.lifeboard(.brandPrimary) }
        public static var brandSecondary: Color { Color.lifeboard(.brandSecondary) }
        public static var brandHighlight: Color { Color.lifeboard(.brandHighlight) }

        // Primary Accent
        public static var accentPrimary: Color { Color.lifeboard(.accentPrimary) }
        public static var accentMuted: Color { Color.lifeboard(.accentMuted) }
        public static var actionPrimary: Color { Color.lifeboard(.actionPrimary) }
        public static var actionFocus: Color { Color.lifeboard(.actionFocus) }

        // Secondary Accent
        public static var accentSecondary: Color { Color.lifeboard(.accentSecondary) }
        public static var accentSecondaryMuted: Color { Color.lifeboard(.accentSecondaryMuted) }

        // Status
        public static var statusSuccess: Color { Color.lifeboard(.statusSuccess) }
        public static var statusWarning: Color { Color.lifeboard(.statusWarning) }
        public static var statusDanger: Color { Color.lifeboard(.statusDanger) }
        public static var stateInfo: Color { Color.lifeboard(.stateInfo) }

        // Priority
        public static var priorityMax: Color { Color.lifeboard(.priorityMax) }
        public static var priorityHigh: Color { Color.lifeboard(.priorityHigh) }
        public static var priorityLow: Color { Color.lifeboard(.priorityLow) }
        public static var priorityNone: Color { Color.lifeboard(.priorityNone) }
    }
}

// MARK: - LifeBoardTheme.Typography

extension LifeBoardTheme {
    @MainActor
    public enum Typography {
        public static var heroDisplay: Font { .lifeboard(.heroDisplay) }
        public static var screenTitle: Font { .lifeboard(.screenTitle) }
        public static var sectionTitle: Font { .lifeboard(.sectionTitle) }
        public static var eyebrow: Font { .lifeboard(.eyebrow) }
        public static var display: Font { .lifeboard(.display) }
        public static var title1: Font { .lifeboard(.title1) }
        public static var title2: Font { .lifeboard(.title2) }
        public static var title3: Font { .lifeboard(.title3) }
        public static var headline: Font { .lifeboard(.headline) }
        public static var body: Font { .lifeboard(.body) }
        public static var bodyStrong: Font { .lifeboard(.bodyStrong) }
        public static var bodyMedium: Font { .lifeboard(.bodyEmphasis) }
        public static var support: Font { .lifeboard(.support) }
        public static var meta: Font { .lifeboard(.meta) }
        public static var metric: Font { .lifeboard(.metric) }
        public static var monoMeta: Font { .lifeboard(.monoMeta) }
        public static var callout: Font { .lifeboard(.callout) }
        public static var caption: Font { .lifeboard(.caption1) }
        public static var captionSemibold: Font { .lifeboard(.caption1).weight(.semibold) }
        public static var caption2: Font { .lifeboard(.caption2) }
    }
}

// MARK: - LifeBoardTheme.Spacing

extension LifeBoardTheme {
    @MainActor
    public enum Spacing {
        private static var tokens: LifeBoardSpacingTokens {
            LifeBoardThemeManager.shared.tokens(for: .phone, traits: .unspecified).spacing
        }

        public static var xs: CGFloat { tokens.s4 }
        public static var sm: CGFloat { tokens.s8 }
        public static var md: CGFloat { tokens.s12 }
        public static var lg: CGFloat { tokens.s16 }
        public static var xl: CGFloat { tokens.s20 }
        public static var xxl: CGFloat { tokens.s24 }
        public static var xxxl: CGFloat { tokens.s32 }

        public static var screenHorizontal: CGFloat { tokens.screenHorizontal }
        public static var cardPadding: CGFloat { tokens.cardPadding }
        public static var sectionGap: CGFloat { tokens.sectionGap }

        /// Extra bottom padding for views behind a tab bar
        public static var tabBarHeight: CGFloat { 80 }

        public static func forLayout(_ layoutClass: LifeBoardLayoutClass) -> LifeBoardSpacingTokens {
            LifeBoardThemeManager.tokens(for: layoutClass).spacing
        }
    }
}

// MARK: - LifeBoardTheme.CornerRadius

extension LifeBoardTheme {
    @MainActor
    public enum CornerRadius {
        private static var tokens: LifeBoardCornerTokens {
            LifeBoardThemeManager.shared.tokens(for: .phone, traits: .unspecified).corner
        }

        public static var sm: CGFloat { tokens.r1 }
        public static var md: CGFloat { tokens.r2 }
        public static var lg: CGFloat { tokens.r3 }
        public static var xl: CGFloat { tokens.r4 }
        public static var card: CGFloat { tokens.card }
        public static var modal: CGFloat { tokens.modal }
        public static var pill: CGFloat { tokens.pill }

        public static func forLayout(_ layoutClass: LifeBoardLayoutClass) -> LifeBoardCornerTokens {
            LifeBoardThemeManager.tokens(for: layoutClass).corner
        }
    }
}
