//
//  MemoryChunker.swift
//  SemanticMemoryKit
//
//  Sentence-aware chunking with word-count targets and overlap.
//

import Foundation
import NaturalLanguage

public struct MemoryChunkDraft: Equatable, Sendable {
    public let text: String
    public let characterStart: Int
    public let characterEnd: Int

    public init(text: String, characterStart: Int, characterEnd: Int) {
        self.text = text
        self.characterStart = characterStart
        self.characterEnd = characterEnd
    }
}

public enum MemoryChunker {
    public static func chunks(for text: String, targetWords: Int = 150, overlapWords: Int = 30) -> [MemoryChunkDraft] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let words = trimmed.split { $0.isWhitespace || $0.isNewline }
        if words.count <= targetWords {
            return [MemoryChunkDraft(text: trimmed, characterStart: 0, characterEnd: trimmed.count)]
        }

        let sentences = sentenceSlices(in: trimmed)
        var drafts: [MemoryChunkDraft] = []
        var current: [SentenceSlice] = []
        var currentWords = 0

        for sentence in sentences {
            if !current.isEmpty, currentWords + sentence.wordCount > targetWords {
                drafts.append(draft(from: current, in: trimmed))
                current = overlapSuffix(from: current, targetWords: overlapWords)
                currentWords = current.reduce(0) { $0 + $1.wordCount }
            }
            current.append(sentence)
            currentWords += sentence.wordCount
        }

        if !current.isEmpty {
            drafts.append(draft(from: current, in: trimmed))
        }

        return drafts
    }

    private struct SentenceSlice {
        let range: Range<String.Index>
        let start: Int
        let end: Int
        let wordCount: Int
    }

    private static func sentenceSlices(in text: String) -> [SentenceSlice] {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        var slices: [SentenceSlice] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let sentence = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !sentence.isEmpty else { return true }
            slices.append(
                SentenceSlice(
                    range: range,
                    start: text.distance(from: text.startIndex, to: range.lowerBound),
                    end: text.distance(from: text.startIndex, to: range.upperBound),
                    wordCount: wordCount(sentence)
                )
            )
            return true
        }
        if slices.isEmpty {
            return [
                SentenceSlice(
                    range: text.startIndex..<text.endIndex,
                    start: 0,
                    end: text.count,
                    wordCount: wordCount(text)
                )
            ]
        }
        return slices
    }

    private static func draft(from slices: [SentenceSlice], in text: String) -> MemoryChunkDraft {
        guard let first = slices.first, let last = slices.last else {
            return MemoryChunkDraft(text: "", characterStart: 0, characterEnd: 0)
        }
        let chunkText = String(text[first.range.lowerBound..<last.range.upperBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        return MemoryChunkDraft(text: chunkText, characterStart: first.start, characterEnd: last.end)
    }

    private static func overlapSuffix(from slices: [SentenceSlice], targetWords: Int) -> [SentenceSlice] {
        guard targetWords > 0 else { return [] }
        var result: [SentenceSlice] = []
        var count = 0
        for slice in slices.reversed() {
            result.insert(slice, at: 0)
            count += slice.wordCount
            if count >= targetWords { break }
        }
        return result
    }

    private static func wordCount(_ text: String) -> Int {
        text.split { $0.isWhitespace || $0.isNewline }.count
    }
}
