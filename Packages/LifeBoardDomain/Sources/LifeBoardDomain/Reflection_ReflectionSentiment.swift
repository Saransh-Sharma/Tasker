//
//  ReflectionSentiment.swift
//  ReflectionKit
//
//  Deterministic mood/keyword sentiment used across reflection surfaces.
//  Extracted verbatim from OffRecord's ProactiveReflectionAnalyzer so both
//  apps score identically.
//

import Foundation

public enum ReflectionSentiment {
    public static func score(text: String, mood: String?) -> Double {
        if let mood {
            switch mood.lowercased() {
            case "happy", "excited", "grateful": return 0.55
            case "calm": return 0.25
            case "okay", "neutral": return 0.0
            case "tired": return -0.18
            case "sad", "anxious": return -0.45
            case "angry": return -0.55
            default: break
            }
        }

        let lower = text.lowercased()
        let positive = ["happy", "calm", "proud", "grateful", "lighter", "good", "better", "relieved", "peaceful"]
        let negative = ["stress", "anxious", "sad", "angry", "crushed", "regret", "worried", "tense", "heavy", "tired"]
        let positiveCount = positive.filter { lower.contains($0) }.count
        let negativeCount = negative.filter { lower.contains($0) }.count
        let total = max(1, positiveCount + negativeCount)
        return max(-0.8, min(0.8, Double(positiveCount - negativeCount) / Double(total)))
    }
}
