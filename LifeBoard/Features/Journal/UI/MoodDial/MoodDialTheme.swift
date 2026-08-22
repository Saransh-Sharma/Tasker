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
import Foundation
#if canImport(UIKit)
import UIKit
#endif

public struct MoodDialTheme: @unchecked Sendable {
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
    ///
    /// Plain, but not light-only. Every value here used to be a fixed
    /// `Color(white:)`, so if this fallback ever reached a running app in dark
    /// appearance it rendered a white slab with near-black ink — the omission
    /// would have been visible as a bug rather than as a plain theme. These are
    /// the same neutral steps, mirrored for dark.
    public static let neutral = MoodDialTheme(
        backgroundTop: Color(uiColor: .lifeboardDynamic(lightHex: "#F7F7F7", darkHex: "#16161A")),
        backgroundBottom: Color(uiColor: .lifeboardDynamic(lightHex: "#EDEDED", darkHex: "#1E1E24")),
        accent: Color(uiColor: .lifeboardDynamic(lightHex: "#404040", darkHex: "#C8C8CE")),
        accentContrast: Color(uiColor: .lifeboardDynamic(lightHex: "#FFFFFF", darkHex: "#16161A")),
        surface: Color(uiColor: .lifeboardDynamic(lightHex: "#FFFFFF", darkHex: "#22222A")),
        heading: Color(uiColor: .lifeboardDynamic(lightHex: "#262626", darkHex: "#F2F2F5")),
        textSecondary: Color(uiColor: .lifeboardDynamic(lightHex: "#595959", darkHex: "#B8B8C0")),
        textTertiary: Color(uiColor: .lifeboardDynamic(lightHex: "#8C8C8C", darkHex: "#8E8E96")),
        titleFont: .system(size: 30, weight: .bold, design: .rounded),
        labelFont: .system(size: 17, weight: .semibold, design: .rounded),
        captionFont: .system(size: 14, weight: .regular, design: .rounded),
        segmentColor: { _ in Color(uiColor: .lifeboardDynamic(lightHex: "#CCCCCC", darkHex: "#3A3A44")) },
        moodAccent: { _ in Color(uiColor: .lifeboardDynamic(lightHex: "#666666", darkHex: "#9A9AA4")) }
    )
}

#if canImport(UIKit)
public enum MoodAssetPreheater {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var didPreheat = false
    private static let queue = DispatchQueue(label: "mood-dial-kit.mood-preheater", qos: .userInitiated)

    public static func preheatMoodAssets() {
        lock.lock()
        let shouldPreheat = !didPreheat
        didPreheat = true
        lock.unlock()

        guard shouldPreheat else { return }

        MoodDialSignposts.event("MoodAssetPreheatScheduled")
        let assetNames = Set(Mood.dialMoods.map(\.dialFaceAssetName))
        queue.async {
            let token = MoodDialSignposts.begin("MoodAssetPreheat")
            for name in assetNames {
                autoreleasepool {
                    _ = UIImage(named: name, in: .module, with: nil)?.preparingForDisplay()
                }
            }
            MoodDialSignposts.end(token)
        }
    }

    #if DEBUG
    public static func resetForTesting() {
        lock.lock()
        didPreheat = false
        lock.unlock()
    }
    #endif
}
#else
public enum MoodAssetPreheater {
    public static func preheatMoodAssets() {}
}
#endif

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
