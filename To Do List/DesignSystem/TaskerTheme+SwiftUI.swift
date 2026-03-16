//
//  TaskerTheme+SwiftUI.swift
//  Tasker
//
//  SwiftUI namespace bridge for the token-based design system.
//  Provides TaskerTheme.Colors / .Typography / .Spacing / .CornerRadius
//  so Presentation views can reference tokens with a clean API.
//

import SwiftUI

// MARK: - TaskerTheme.Colors

extension TaskerTheme {
    @MainActor
    public enum Colors {
        // XP / Gamification
        public static var xpGold: Color { Color.tasker(.statusWarning) }
        public static var xpGoldLight: Color { Color.tasker(.accentSecondaryWash) }

        // Text
        public static var textPrimary: Color { Color.tasker(.textPrimary) }
        public static var textSecondary: Color { Color.tasker(.textSecondary) }
        public static var textTertiary: Color { Color.tasker(.textTertiary) }
        public static var textQuaternary: Color { Color.tasker(.textQuaternary) }

        // Surfaces
        public static var cardBackground: Color { Color.tasker(.surfacePrimary) }
        public static var background: Color { Color.tasker(.bgCanvas) }
        public static var backgroundSecondary: Color { Color.tasker(.bgCanvasSecondary) }
        public static var surfaceSecondary: Color { Color.tasker(.surfaceSecondary) }

        // Brand
        public static var brandPrimary: Color { Color.tasker(.brandPrimary) }
        public static var brandSecondary: Color { Color.tasker(.brandSecondary) }
        public static var brandHighlight: Color { Color.tasker(.brandHighlight) }

        // Primary Accent
        public static var accentPrimary: Color { Color.tasker(.accentPrimary) }
        public static var accentMuted: Color { Color.tasker(.accentMuted) }
        public static var actionPrimary: Color { Color.tasker(.actionPrimary) }
        public static var actionFocus: Color { Color.tasker(.actionFocus) }

        // Secondary Accent
        public static var accentSecondary: Color { Color.tasker(.accentSecondary) }
        public static var accentSecondaryMuted: Color { Color.tasker(.accentSecondaryMuted) }

        // Status
        public static var statusSuccess: Color { Color.tasker(.statusSuccess) }
        public static var statusWarning: Color { Color.tasker(.statusWarning) }
        public static var statusDanger: Color { Color.tasker(.statusDanger) }
        public static var stateInfo: Color { Color.tasker(.stateInfo) }

        // Priority
        public static var priorityMax: Color { Color.tasker(.priorityMax) }
        public static var priorityHigh: Color { Color.tasker(.priorityHigh) }
        public static var priorityLow: Color { Color.tasker(.priorityLow) }
        public static var priorityNone: Color { Color.tasker(.priorityNone) }
    }
}

// MARK: - TaskerTheme.Typography

extension TaskerTheme {
    @MainActor
    public enum Typography {
        public static var heroDisplay: Font { .tasker(.heroDisplay) }
        public static var screenTitle: Font { .tasker(.screenTitle) }
        public static var sectionTitle: Font { .tasker(.sectionTitle) }
        public static var eyebrow: Font { .tasker(.eyebrow) }
        public static var display: Font { .tasker(.display) }
        public static var title1: Font { .tasker(.title1) }
        public static var title2: Font { .tasker(.title2) }
        public static var title3: Font { .tasker(.title3) }
        public static var headline: Font { .tasker(.headline) }
        public static var body: Font { .tasker(.body) }
        public static var bodyStrong: Font { .tasker(.bodyStrong) }
        public static var bodyMedium: Font { .tasker(.bodyEmphasis) }
        public static var support: Font { .tasker(.support) }
        public static var meta: Font { .tasker(.meta) }
        public static var metric: Font { .tasker(.metric) }
        public static var monoMeta: Font { .tasker(.monoMeta) }
        public static var callout: Font { .tasker(.callout) }
        public static var caption: Font { .tasker(.caption1) }
        public static var captionSemibold: Font { .tasker(.caption1).weight(.semibold) }
        public static var caption2: Font { .tasker(.caption2) }
    }
}

// MARK: - TaskerTheme.Spacing

extension TaskerTheme {
    @MainActor
    public enum Spacing {
        private static var tokens: TaskerSpacingTokens {
            TaskerThemeManager.shared.tokens(for: .phone, traits: .unspecified).spacing
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

        public static func forLayout(_ layoutClass: TaskerLayoutClass) -> TaskerSpacingTokens {
            TaskerThemeManager.tokens(for: layoutClass).spacing
        }
    }
}

// MARK: - TaskerTheme.CornerRadius

extension TaskerTheme {
    @MainActor
    public enum CornerRadius {
        private static var tokens: TaskerCornerTokens {
            TaskerThemeManager.shared.tokens(for: .phone, traits: .unspecified).corner
        }

        public static var sm: CGFloat { tokens.r1 }
        public static var md: CGFloat { tokens.r2 }
        public static var lg: CGFloat { tokens.r3 }
        public static var xl: CGFloat { tokens.r4 }
        public static var card: CGFloat { tokens.card }
        public static var modal: CGFloat { tokens.modal }
        public static var pill: CGFloat { tokens.pill }

        public static func forLayout(_ layoutClass: TaskerLayoutClass) -> TaskerCornerTokens {
            TaskerThemeManager.tokens(for: layoutClass).corner
        }
    }
}
