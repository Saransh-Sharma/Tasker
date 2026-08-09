//
//  MoodDialTheme.swift
//  MoodDialKit
//
//  Visual identity injection for the mood dial. OffRecord supplies its
//  pastel palette; LifeBoard supplies Sunrise Glass. The dial's interaction
//  logic and artwork stay shared while every color, font, and prompt string
//  flows through this theme.
//

import SwiftUI
import LifeBoardDomain

public struct MoodDialTheme {
    /// Background gradient behind the dial (top → bottom).
    public var backgroundTop: Color
    public var backgroundBottom: Color
    /// Primary accent: pointer fill, Done button background, Cancel label.
    public var accent: Color
    /// Content color on top of `accent` (Done label) and light button fills.
    public var accentContrast: Color
    /// Surface color for the pointer's inner dot.
    public var surface: Color
    /// Heading color for the prompt title.
    public var heading: Color
    /// Secondary text (mood sentence).
    public var textSecondary: Color
    /// Tertiary text (supportive copy, chevron).
    public var textTertiary: Color
    /// Prompt title font.
    public var titleFont: Font
    /// Button/sentence label font.
    public var labelFont: Font
    /// Supportive copy font.
    public var captionFont: Font
    /// The header prompt, e.g. "How are\nyou feeling?".
    public var promptTitle: String
    /// Fill color per dial segment.
    public var segmentColor: (Mood) -> Color
    /// Accent color per mood (chips, selected states outside the dial).
    public var moodAccent: (Mood) -> Color

    public init(
        backgroundTop: Color,
        backgroundBottom: Color,
        accent: Color,
        accentContrast: Color,
        surface: Color,
        heading: Color,
        textSecondary: Color,
        textTertiary: Color,
        titleFont: Font,
        labelFont: Font,
        captionFont: Font,
        promptTitle: String = "How are\nyou feeling?",
        segmentColor: @escaping (Mood) -> Color,
        moodAccent: @escaping (Mood) -> Color
    ) {
        self.backgroundTop = backgroundTop
        self.backgroundBottom = backgroundBottom
        self.accent = accent
        self.accentContrast = accentContrast
        self.surface = surface
        self.heading = heading
        self.textSecondary = textSecondary
        self.textTertiary = textTertiary
        self.titleFont = titleFont
        self.labelFont = labelFont
        self.captionFont = captionFont
        self.promptTitle = promptTitle
        self.segmentColor = segmentColor
        self.moodAccent = moodAccent
    }

    /// Grayscale fallback used when a host app forgets to inject a theme
    /// (previews, tests). Intentionally plain so the omission is visible.
    public static let neutral = MoodDialTheme(
        backgroundTop: Color(white: 0.97),
        backgroundBottom: Color(white: 0.93),
        accent: Color(white: 0.25),
        accentContrast: .white,
        surface: .white,
        heading: Color(white: 0.15),
        textSecondary: Color(white: 0.35),
        textTertiary: Color(white: 0.55),
        titleFont: .system(size: 30, weight: .bold, design: .rounded),
        labelFont: .system(size: 17, weight: .semibold, design: .rounded),
        captionFont: .system(size: 14, weight: .regular, design: .rounded),
        segmentColor: { _ in Color(white: 0.8) },
        moodAccent: { _ in Color(white: 0.4) }
    )
}

private struct MoodDialThemeKey: EnvironmentKey {
    static let defaultValue = MoodDialTheme.neutral
}

private struct JournalHapticsKey: EnvironmentKey {
    static let defaultValue: JournalHapticsProviding = NoopJournalHaptics()
}

extension EnvironmentValues {
    public var moodDialTheme: MoodDialTheme {
        get { self[MoodDialThemeKey.self] }
        set { self[MoodDialThemeKey.self] = newValue }
    }

    public var journalHaptics: JournalHapticsProviding {
        get { self[JournalHapticsKey.self] }
        set { self[JournalHapticsKey.self] = newValue }
    }
}
