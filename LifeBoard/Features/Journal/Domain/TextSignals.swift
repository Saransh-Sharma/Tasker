//
//  TextSignals.swift
//  SemanticMemoryKit
//
//  Tokenization, concept expansion, entity/topic extraction, hashing, and
//  snippet helpers shared by chunking, search, and evidence rendering.
//

import Foundation
import NaturalLanguage
import CryptoKit

public enum TextSignals {
    public static let stopWords: Set<String> = [
        "the", "and", "for", "that", "with", "this", "from", "have", "was", "were", "are", "but", "not",
        "you", "your", "about", "into", "today", "really", "just", "they", "them", "then", "than", "when",
        "what", "where", "how", "why", "who", "had", "has", "been", "being", "will", "would", "could",
        "should", "there", "their", "because", "feel", "felt", "feeling"
    ]

    public static let conceptSynonyms: [String: Set<String>] = [
        "stress": ["stress", "stressed", "anxiety", "anxious", "pressure", "overwhelmed", "burnout", "tense", "worry", "worried"],
        "work": ["work", "office", "meeting", "deadline", "manager", "boss", "project", "job", "client", "shift"],
        "people": ["friend", "friends", "family", "mother", "father", "partner", "colleague", "coworker", "relationship", "people"],
        "missing": ["miss", "missing", "distant", "absence", "lonely", "alone", "nostalgic"],
        "decision": ["decide", "decided", "decision", "choice", "choose", "chose", "regret", "regretted", "should", "option"],
        "joy": ["happy", "happier", "joy", "grateful", "calm", "excited", "peaceful", "proud", "win"],
        "health": ["sleep", "tired", "energy", "health", "exercise", "walk", "run", "body", "sick", "therapy"],
        "growth": ["learn", "growth", "change", "better", "progress", "aware", "realized", "understand", "practice"]
    ]

    public static func tokens(in text: String) -> [String] {
        text.lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { $0.count > 2 && !stopWords.contains($0) }
    }

    public static func expandedTokens(in text: String) -> Set<String> {
        var result = Set(tokens(in: text))
        for token in Array(result) {
            for (_, synonyms) in conceptSynonyms where synonyms.contains(token) {
                result.formUnion(synonyms)
            }
        }
        return result
    }

    public static func extractEntities(from text: String) -> [String] {
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text
        var values: [String] = []
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType, options: [.omitWhitespace, .joinNames]) { tag, range in
            guard tag == .personalName || tag == .placeName || tag == .organizationName else { return true }
            let value = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            if value.count > 1 { values.append(value) }
            return true
        }
        return Array(Set(values)).sorted()
    }

    public static func extractTopics(from text: String, limit: Int = 10) -> [String] {
        let counts = Dictionary(grouping: tokens(in: text), by: { $0 }).mapValues(\.count)
        return counts.sorted { lhs, rhs in
            if lhs.value != rhs.value { return lhs.value > rhs.value }
            return lhs.key < rhs.key
        }
        .prefix(limit)
        .map(\.key)
    }

    public static func hash(_ text: String) -> String {
        let digest = SHA256.hash(data: Data(text.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    public static func slice(_ text: String, start: Int, end: Int) -> String {
        let safeStart = max(0, min(start, text.count))
        let safeEnd = max(safeStart, min(end, text.count))
        let lower = text.index(text.startIndex, offsetBy: safeStart)
        let upper = text.index(text.startIndex, offsetBy: safeEnd)
        return String(text[lower..<upper]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func snippet(from text: String, query: String, maxLength: Int = 170) -> String {
        let queryTokens = tokens(in: query)
        let lower = text.lowercased()
        let firstMatch = queryTokens.compactMap { lower.range(of: $0)?.lowerBound }.min()
        let startIndex: String.Index
        if let firstMatch {
            let offset = max(0, lower.distance(from: lower.startIndex, to: firstMatch) - 50)
            startIndex = text.index(text.startIndex, offsetBy: offset)
        } else {
            startIndex = text.startIndex
        }
        let endIndex = text.index(startIndex, offsetBy: min(maxLength, text.distance(from: startIndex, to: text.endIndex)), limitedBy: text.endIndex) ?? text.endIndex
        var snippet = String(text[startIndex..<endIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
        if startIndex > text.startIndex { snippet = "..." + snippet }
        if endIndex < text.endIndex { snippet += "..." }
        return snippet
    }
}
