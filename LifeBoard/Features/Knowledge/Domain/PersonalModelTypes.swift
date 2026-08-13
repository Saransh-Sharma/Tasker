import LifeBoardContracts
import LifeBoardDomain
import LifeBoardPersistence
import LifeBoardTokens
import LifeBoardUI
//
//  PersonalModelTypes.swift
//  KnowledgeGraphKit
//
//  Persona-neutral local-intelligence profile types: linguistic fingerprint,
//  emotional signature, cognitive tendencies, and behavioral rhythm. Learned
//  entirely on device; persisted via app-owned blob stores.
//

import Foundation

/// Captures how you express yourself - your linguistic fingerprint
public struct CommunicationStyle: Codable, Sendable {
    // Vocabulary metrics
    public var uniqueWordCount: Int = 0
    public var averageSentenceLength: Double = 0
    public var vocabularyRichness: Double = 0  // Type-Token Ratio
    public var totalWordsAnalyzed: Int = 0
    public var totalSentencesAnalyzed: Int = 0

    // Expression patterns
    public var usesExclamations: Double = 0     // 0-1 how often
    public var usesQuestions: Double = 0         // 0-1 how often
    public var usesEllipsis: Double = 0         // 0-1 trailing off...
    public var usesAllCaps: Double = 0          // EMPHASIS
    public var averageMessageLength: Double = 0

    // Formality spectrum (0 = very casual, 1 = very formal)
    public var formalityLevel: Double = 0.5

    // Emotional expressiveness (0 = reserved, 1 = very expressive)
    public var expressiveness: Double = 0.5

    // Directness (0 = indirect/hedging, 1 = very direct)
    public var directness: Double = 0.5

    // Top vocabulary - words you use most (beyond common words)
    public var signatureWords: [String: Int] = [:]

    // Phrases you repeat
    public var signaturePhrases: [String: Int] = [:]

    // How you start messages
    public var commonOpenings: [String: Int] = [:]

    // Update count for running averages
    public var analysisCount: Int = 0

    public init() {}
}

/// Your unique emotional fingerprint - how you experience and express feelings
public struct EmotionalSignature: Codable, Sendable {
    // Baseline emotional state (where you naturally settle)
    public var baselineValence: Double = 0      // -1 negative to +1 positive
    public var baselineArousal: Double = 0.5    // 0 calm to 1 activated
    public var baselineDominance: Double = 0.5  // 0 submissive to 1 dominant

    // Emotional range (how much you fluctuate)
    public var emotionalRange: Double = 0.5     // 0 = very stable, 1 = highly variable

    // Emotion frequency map (how often each emotion appears)
    public var emotionFrequency: [String: Double] = [:]

    // Emotional resilience (how quickly you bounce back)
    public var resilienceScore: Double = 0.5

    // Time-based patterns
    public var morningMood: Double = 0          // Average morning sentiment
    public var eveningMood: Double = 0          // Average evening sentiment
    public var weekdayMood: Double = 0          // Average weekday sentiment
    public var weekendMood: Double = 0          // Average weekend sentiment

    // Trigger patterns
    public var positiveTriggersTopics: [String: Double] = [:]  // Topics that lift mood
    public var negativeTriggersTopics: [String: Double] = [:]  // Topics that lower mood

    // Emotional trajectory (are things getting better/worse over time?)
    public var sentimentTrend: Double = 0       // -1 declining, 0 stable, +1 improving
    public var recentSentiments: [Double] = []  // Last 30 data points

    public var analysisCount: Int = 0

    public init() {}
}

/// Maps your cognitive tendencies and thinking style
public struct ThoughtPatterns: Codable, Sendable {
    // Cognitive style
    public var analyticalScore: Double = 0.5    // How much you analyze vs feel
    public var abstractScore: Double = 0.5      // Abstract vs concrete thinking
    public var futureOriented: Double = 0.5     // Past-focused vs future-focused
    public var selfFocused: Double = 0.5        // Internal vs external focus

    // Rumination patterns (0 = never, 1 = frequently)
    public var ruminationTendency: Double = 0
    public var topicPersistence: [String: Int] = [:]  // How long topics stay active

    // Growth indicators
    public var selfAwarenessLevel: Double = 0.5
    public var growthMindsetScore: Double = 0.5
    public var gratitudeTendency: Double = 0.5

    // Decision making style
    public var decisiveness: Double = 0.5       // Quick decisions vs deliberation
    public var riskTolerance: Double = 0.5      // Risk-averse vs risk-seeking

    // Primary concerns (ranked by frequency)
    public var topConcerns: [String: Double] = [:]

    public var analysisCount: Int = 0

    public init() {}
}

/// When and how you interact with the app
public struct BehavioralPatterns: Codable, Sendable {
    // Time patterns
    public var hourlyActivity: [Int: Int] = [:]  // Hour -> entry count
    public var dayOfWeekActivity: [Int: Int] = [:]  // 1=Sun, 7=Sat
    public var peakHour: Int?
    public var peakDay: Int?

    // Session patterns
    public var averageSessionLength: Double = 0  // In words
    public var sessionsPerWeek: Double = 0

    // Consistency
    public var currentStreak: Int = 0
    public var longestStreak: Int = 0
    public var consistencyScore: Double = 0  // 0-1

    // Entry patterns
    public var totalEntries: Int = 0
    public var totalWords: Int = 0
    public var averageWordsPerEntry: Double = 0

    // Interaction preferences
    public var prefersVoice: Double = 0.5  // 0 = text only, 1 = voice only
    public var prefersShortEntries: Double = 0.5  // 0 = long form, 1 = brief

    // Growth tracking
    public var weeklyEntryHistory: [String: Int] = [:]  // "2026-W09" -> count

    public var analysisCount: Int = 0

    public init() {}
}
