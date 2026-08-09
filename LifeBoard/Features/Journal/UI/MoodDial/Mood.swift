//
//  Mood.swift
//  MoodDialKit
//
//  The shared mood vocabulary and its bundled artwork. App-specific colors
//  (OffRecord pastels, LifeBoard Sunrise Glass) are supplied via
//  MoodDialTheme; this type carries only identity, copy, and asset names.
//

import SwiftUI

public enum Mood: String, CaseIterable, Identifiable, Sendable, Codable {
    case none = ""
    case happy = "happy"
    case calm = "calm"
    case grateful = "grateful"
    case excited = "excited"
    case tired = "tired"
    case anxious = "anxious"
    case sad = "sad"
    case angry = "angry"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .none: return "No mood"
        case .happy: return "Happy"
        case .calm: return "Calm"
        case .grateful: return "Grateful"
        case .excited: return "Excited"
        case .tired: return "Tired"
        case .anxious: return "Anxious"
        case .sad: return "Sad"
        case .angry: return "Angry"
        }
    }

    public var icon: String {
        switch self {
        case .none: return "circle.dashed"
        case .happy: return "sun.max.fill"
        case .calm: return "leaf.fill"
        case .grateful: return "heart.fill"
        case .excited: return "star.fill"
        case .tired: return "moon.zzz.fill"
        case .anxious: return "wind"
        case .sad: return "cloud.rain.fill"
        case .angry: return "flame.fill"
        }
    }

    public static var selectableMoods: [Mood] {
        allCases.filter { $0 != .none }
    }

    public static let dialMoods: [Mood] = [
        .angry,
        .sad,
        .anxious,
        .tired,
        .none,
        .calm,
        .grateful,
        .happy,
        .excited
    ]

    public static var neutralDialIndex: Int {
        dialMoods.firstIndex(of: .none) ?? 0
    }

    public var moodSentence: String {
        switch self {
        case .none: return "I feel neutral."
        case .happy: return "I feel happy."
        case .calm: return "I feel calm."
        case .grateful: return "I feel grateful."
        case .excited: return "I feel excited."
        case .tired: return "I feel tired."
        case .anxious: return "I feel anxious."
        case .sad: return "I feel sad."
        case .angry: return "I feel angry."
        }
    }

    public var supportiveCopy: String {
        switch self {
        case .none: return "Nothing to force."
        case .happy: return "Something feels lighter."
        case .calm: return "A steady moment."
        case .grateful: return "Something mattered today."
        case .excited: return "There's energy here."
        case .tired: return "Move gently."
        case .anxious: return "Come back to now."
        case .sad: return "Hold this softly."
        case .angry: return "Name it without judging it."
        }
    }

    public var largeMoodAssetName: String {
        switch self {
        case .none: return "NoMood_Neutral_Large"
        case .happy: return "Happy_Large"
        case .calm: return "Calm_Large"
        case .grateful: return "Grateful_Large"
        case .excited: return "Excited_Large"
        case .tired: return "Tired_Large"
        case .anxious: return "Anxious_Large"
        case .sad: return "Sad_Large"
        case .angry: return "Angry_Large"
        }
    }

    public var miniMoodAssetName: String {
        switch self {
        case .none: return "NoMood_Neutral_Mini"
        case .happy: return "Happy_Mini"
        case .calm: return "Calm_Mini"
        case .grateful: return "Grateful_Mini"
        case .excited: return "Excited_Mini"
        case .tired: return "Tired_Mini"
        case .anxious: return "Anxious_Mini"
        case .sad: return "Sad_Mini"
        case .angry: return "Angry_Mini"
        }
    }

    public var dialFaceAssetName: String {
        switch self {
        case .none: return "Neutral_face"
        case .happy: return "Happy_face"
        case .calm: return "Calm_face"
        case .grateful: return "Grateful_face"
        case .excited: return "Excited_face"
        case .tired: return "Sleepy_face"
        case .anxious: return "Anxious_face"
        case .sad: return "Sad_face"
        case .angry: return "Angry_face"
        }
    }

    public var moodGlowAssetName: String {
        switch self {
        case .angry, .sad, .anxious, .tired:
            return "Difficult_Glow"
        case .none:
            return "Neutral_Glow"
        case .calm, .grateful, .happy, .excited:
            return "Positive_Glow"
        }
    }

    public init(rawEmotion: String) {
        switch rawEmotion.lowercased() {
        case "joy", "happy":
            self = .happy
        case "sadness", "sad":
            self = .sad
        case "anger", "disgust", "angry":
            self = .angry
        case "fear", "anxious":
            self = .anxious
        case "surprise", "anticipation", "excited":
            self = .excited
        case "trust", "grateful":
            self = .grateful
        case "calm":
            self = .calm
        case "tired":
            self = .tired
        default:
            self = .none
        }
    }
}

extension Mood {
    /// The bundle carrying the mood artwork; use with `Image(_:bundle:)`.
    public static var assetBundle: Bundle { .module }

    public var largeImage: Image { Image(largeMoodAssetName, bundle: .module) }
    public var miniImage: Image { Image(miniMoodAssetName, bundle: .module) }
    public var dialFaceImage: Image { Image(dialFaceAssetName, bundle: .module) }
    public var glowImage: Image { Image(moodGlowAssetName, bundle: .module) }
}

public struct MiniMoodIcon: View {
    let mood: Mood
    let size: CGFloat
    let opacity: Double
    let accessibilityLabel: String?

    public init(
        mood: Mood,
        size: CGFloat = 16,
        opacity: Double = 0.76,
        accessibilityLabel: String? = nil
    ) {
        self.mood = mood
        self.size = size
        self.opacity = opacity
        self.accessibilityLabel = accessibilityLabel
    }

    public var body: some View {
        mood.miniImage
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .opacity(opacity)
            .accessibilityLabel(accessibilityLabel ?? "\(mood.displayName) mood")
            .accessibilityHidden(accessibilityLabel == nil)
    }
}
