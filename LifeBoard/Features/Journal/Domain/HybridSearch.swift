//
//  HybridSearch.swift
//  SemanticMemoryKit
//
//  Reciprocal-rank fusion of semantic (cosine) and lexical (FTS) rankings
//  with recency and starred boosts.
//

import Foundation
import LifeBoardDomain

public struct LexicalHit: Sendable {
    public let chunkID: String
    public let reason: EvidenceReference.MatchReason

    public init(chunkID: String, reason: EvidenceReference.MatchReason) {
        self.chunkID = chunkID
        self.reason = reason
    }
}

public struct HybridSearchResult: Sendable {
    public let chunk: MemoryChunk
    public let score: Double
    public let reason: EvidenceReference.MatchReason
    public let semanticScore: Double
    public let lexicalRank: Int?

    public init(chunk: MemoryChunk, score: Double, reason: EvidenceReference.MatchReason, semanticScore: Double, lexicalRank: Int?) {
        self.chunk = chunk
        self.score = score
        self.reason = reason
        self.semanticScore = semanticScore
        self.lexicalRank = lexicalRank
    }
}

public enum HybridMemorySearchService {
    public static func search(query: String, chunks: [MemoryChunk], queryVector: [Float], lexicalHits: [LexicalHit], limit: Int = 18) -> [HybridSearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let semantic = semanticRanking(chunks: chunks, queryVector: queryVector)
        let fused = fuse(semantic: semantic, lexicalHits: lexicalHits, chunks: chunks)

        return Array(fused.prefix(limit))
    }

    public static func lexicalHits(query: String, chunks: [MemoryChunk], textByChunkID: [String: String], rankedChunkIDs: [String]) -> [LexicalHit] {
        let queryTokens = TextSignals.expandedTokens(in: query)
        let rankedSet = Set(rankedChunkIDs)
        guard !queryTokens.isEmpty else { return [] }

        let hits = chunks.compactMap { chunk -> LexicalHit? in
            guard rankedSet.contains(chunk.id), let text = textByChunkID[chunk.id] else { return nil }
            let entityMatch = chunk.entities.map { $0.lowercased() }.contains { query.lowercased().contains($0) }
            let exactPhrase = text.localizedCaseInsensitiveContains(query)
            let topicMatch = chunk.topics.contains { queryTokens.contains($0) }
            let reason: EvidenceReference.MatchReason
            if exactPhrase {
                reason = .exact
            } else if entityMatch || topicMatch {
                reason = .entity
            } else {
                reason = .meaning
            }
            return LexicalHit(chunkID: chunk.id, reason: reason)
        }
        let order = Dictionary(uniqueKeysWithValues: rankedChunkIDs.enumerated().map { ($0.element, $0.offset) })
        return hits.sorted { (order[$0.chunkID] ?? Int.max) < (order[$1.chunkID] ?? Int.max) }
    }

    private static func semanticRanking(chunks: [MemoryChunk], queryVector: [Float]) -> [(String, Double)] {
        chunks.map { chunk in
            (chunk.id, VectorMath.cosine(queryVector, chunk.vector))
        }
        .filter { $0.1 > 0 }
        .sorted { $0.1 > $1.1 }
    }

    private static func fuse(semantic: [(String, Double)], lexicalHits: [LexicalHit], chunks: [MemoryChunk]) -> [HybridSearchResult] {
        let chunkMap = Dictionary(uniqueKeysWithValues: chunks.map { ($0.id, $0) })
        let semanticScores = Dictionary(uniqueKeysWithValues: semantic)
        var scores: [String: Double] = [:]
        var reasons: [String: EvidenceReference.MatchReason] = [:]
        var lexicalRankByID: [String: Int] = [:]
        let k = 60.0

        for (rank, item) in semantic.enumerated() {
            scores[item.0, default: 0] += 1.0 / (k + Double(rank + 1))
            if reasons[item.0] == nil { reasons[item.0] = .meaning }
        }
        for (rank, hit) in lexicalHits.enumerated() {
            scores[hit.chunkID, default: 0] += 1.25 / (k + Double(rank + 1))
            lexicalRankByID[hit.chunkID] = rank
            if hit.reason == .exact || hit.reason == .entity || reasons[hit.chunkID] == nil {
                reasons[hit.chunkID] = hit.reason
            }
        }

        let now = Date()
        return scores.compactMap { id, score -> HybridSearchResult? in
            guard let chunk = chunkMap[id] else { return nil }
            let ageDays = Calendar.current.dateComponents([.day], from: chunk.date, to: now).day ?? 0
            let recencyBoost = max(0, 0.008 - Double(ageDays) * 0.00025)
            let starredBoost = chunk.isStarred ? 0.004 : 0
            let finalScore = score + recencyBoost + starredBoost
            let reason = reasons[id] ?? (recencyBoost > 0.004 ? .recent : .meaning)
            return HybridSearchResult(
                chunk: chunk,
                score: finalScore,
                reason: reason,
                semanticScore: semanticScores[id] ?? 0,
                lexicalRank: lexicalRankByID[id]
            )
        }
        .sorted { $0.score > $1.score }
    }
}
