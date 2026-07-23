import Accelerate
import CryptoKit
import Foundation
import NaturalLanguage
import SQLite3

/// A protected, rebuildable search sidecar for Journal. The database never syncs and
/// contains no source-of-truth Journal state.
public actor LocalJournalDerivedIndexRepository: JournalDerivedIndexRepository {
    public enum IndexError: LocalizedError, Sendable {
        case applicationSupportUnavailable
        case database(String)
        case fileProtection(String)

        public var errorDescription: String? {
            switch self {
            case .applicationSupportUnavailable:
                return "Journal search storage is unavailable on this device."
            case .database(let message):
                return "Journal search could not open its local index: \(message)"
            case .fileProtection(let message):
                return "Journal search could not protect its local index: \(message)"
            }
        }
    }

    private struct Chunk: Sendable {
        let id: String
        let entryID: UUID
        let date: Date
        let text: String
        let vector: [Float]
        let isStarred: Bool
    }

    private static let schemaVersion = 1
    private static let embeddingDimension = 128
    private static let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    private let databaseURL: URL
    // SQLite's opaque handle is not Sendable. Access remains serialized by this
    // actor; the unsafe annotation only permits deterministic close from deinit.
    nonisolated(unsafe) private var database: OpaquePointer?

    public init(databaseURL: URL? = nil) throws {
        let resolvedURL: URL
        if let databaseURL {
            resolvedURL = databaseURL
        } else {
            guard let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
                throw IndexError.applicationSupportUnavailable
            }
            resolvedURL = support
                .appendingPathComponent("LifeBoard", isDirectory: true)
                .appendingPathComponent("JournalDerivedIndex", isDirectory: true)
                .appendingPathComponent("journal-search.sqlite", isDirectory: false)
        }
        self.databaseURL = resolvedURL

    }

    deinit {
        sqlite3_close(database)
    }

    public func rebuild(entries: [JournalEntrySnapshot]) async throws {
        try ensureDatabase()
        var chunks: [Chunk] = []
        for (entryOffset, entry) in entries.enumerated() {
            try Task.checkCancellation()
            let drafts = Self.chunk(entry.text)
            for (chunkOffset, text) in drafts.enumerated() {
                try Task.checkCancellation()
                let id = Self.chunkID(entryID: entry.id, offset: chunkOffset, text: text)
                chunks.append(
                    Chunk(
                        id: id,
                        entryID: entry.id,
                        date: entry.date,
                        text: text,
                        vector: embeddingVector(for: text),
                        isStarred: entry.isStarred
                    )
                )
            }
            if entryOffset.isMultiple(of: 8) { await Task.yield() }
        }

        try transaction {
            try execute("DELETE FROM journal_chunks;")
            try execute("DELETE FROM journal_chunks_fts;")
            for chunk in chunks { try insert(chunk) }
            try setMetadata(key: "schemaVersion", value: String(Self.schemaVersion))
            try setMetadata(key: "updatedAt", value: String(Date().timeIntervalSince1970))
        }
        try protectDatabaseFiles()
    }

    public func upsert(entry: JournalEntrySnapshot) async throws {
        try ensureDatabase()
        var chunks: [Chunk] = []
        for (offset, text) in Self.chunk(entry.text).enumerated() {
            try Task.checkCancellation()
            chunks.append(
                Chunk(
                    id: Self.chunkID(entryID: entry.id, offset: offset, text: text),
                    entryID: entry.id,
                    date: entry.date,
                    text: text,
                    vector: embeddingVector(for: text),
                    isStarred: entry.isStarred
                )
            )
        }
        try transaction {
            try delete(entryID: entry.id)
            for chunk in chunks { try insert(chunk) }
            try setMetadata(key: "updatedAt", value: String(Date().timeIntervalSince1970))
        }
        try protectDatabaseFiles()
    }

    public func remove(entryID: UUID) async throws {
        try ensureDatabase()
        try transaction {
            try delete(entryID: entryID)
            try setMetadata(key: "updatedAt", value: String(Date().timeIntervalSince1970))
        }
        try protectDatabaseFiles()
    }

    public func search(query: String, limit: Int) async throws -> [JournalEvidenceReference] {
        try ensureDatabase()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, limit > 0 else { return [] }
        try Task.checkCancellation()

        let chunks = try loadChunks()
        guard !chunks.isEmpty else { return [] }
        let lexicalIDs = try lexicalSearch(query: trimmed, limit: max(24, limit * 4))
        let lexicalRanks = Dictionary(uniqueKeysWithValues: lexicalIDs.enumerated().map { ($0.element, $0.offset) })
        let queryVector = embeddingVector(for: trimmed)
        let loweredQuery = trimmed.lowercased()
        let now = Date()

        let ranked = chunks.compactMap { chunk -> (Chunk, Double, JournalEvidenceReference.MatchReason)? in
            let semantic = Self.cosine(queryVector, chunk.vector)
            let lexicalRank = lexicalRanks[chunk.id]
            guard semantic > 0.08 || lexicalRank != nil else { return nil }

            let semanticRankScore = max(0, semantic) * 0.56
            let lexicalRankScore = lexicalRank.map { 0.36 / (1 + Double($0) * 0.16) } ?? 0
            let ageDays = max(0, Calendar.current.dateComponents([.day], from: chunk.date, to: now).day ?? 0)
            let recency = max(0, 0.05 - Double(ageDays) * 0.0015)
            let starred = chunk.isStarred ? 0.03 : 0
            let exact = chunk.text.lowercased().contains(loweredQuery)
            let reason: JournalEvidenceReference.MatchReason = exact ? .exact : (lexicalRank != nil ? .topic : (recency > 0.025 ? .recent : .meaning))
            return (chunk, min(1, semanticRankScore + lexicalRankScore + recency + starred), reason)
        }
        .sorted { lhs, rhs in
            if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
            if lhs.0.date != rhs.0.date { return lhs.0.date > rhs.0.date }
            return lhs.0.id < rhs.0.id
        }

        var seenEntries = Set<UUID>()
        var references: [JournalEvidenceReference] = []
        for (chunk, score, reason) in ranked where seenEntries.insert(chunk.entryID).inserted {
            try Task.checkCancellation()
            references.append(
                JournalEvidenceReference(
                    id: chunk.id,
                    entryID: chunk.entryID,
                    date: chunk.date,
                    snippet: Self.snippet(from: chunk.text, query: trimmed),
                    score: score,
                    matchReason: reason
                )
            )
            if references.count == limit { break }
        }
        return references
    }

    public func invalidate() async throws {
        try ensureDatabase()
        try transaction {
            try execute("DELETE FROM journal_chunks;")
            try execute("DELETE FROM journal_chunks_fts;")
            try setMetadata(key: "updatedAt", value: String(Date().timeIntervalSince1970))
        }
        try protectDatabaseFiles()
    }

    private func migrate() throws {
        try execute(
            """
            CREATE TABLE IF NOT EXISTS journal_chunks (
                id TEXT PRIMARY KEY NOT NULL,
                entryID TEXT NOT NULL,
                date REAL NOT NULL,
                text TEXT NOT NULL,
                vector BLOB NOT NULL,
                isStarred INTEGER NOT NULL
            );
            """
        )
        try execute("CREATE INDEX IF NOT EXISTS journal_chunks_entry ON journal_chunks(entryID);")
        try execute("CREATE TABLE IF NOT EXISTS journal_index_metadata (key TEXT PRIMARY KEY NOT NULL, value TEXT NOT NULL);")
        try execute("CREATE VIRTUAL TABLE IF NOT EXISTS journal_chunks_fts USING fts5(id UNINDEXED, entryID UNINDEXED, text, tokenize='unicode61');")

        let existingVersion = try metadataValue(key: "schemaVersion").flatMap(Int.init)
        if existingVersion != nil, existingVersion != Self.schemaVersion {
            try execute("DELETE FROM journal_chunks;")
            try execute("DELETE FROM journal_chunks_fts;")
        }
        try setMetadata(key: "schemaVersion", value: String(Self.schemaVersion))
    }

    private func ensureDatabase() throws {
        guard database == nil else { return }

        let directory = databaseURL.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try Self.protectAndExcludeFromBackup(directory)
        } catch {
            throw IndexError.fileProtection(error.localizedDescription)
        }

        do {
            try openAndMigrate()
        } catch let error as IndexError {
            guard case .database = error else { throw error }
            // The sidecar is entirely derived. A malformed or incompatible file
            // is safer to discard and rebuild than to hide the user's Journal.
            try removeDatabaseFiles()
            try openAndMigrate()
        }
        try protectDatabaseFiles()
    }

    private func openAndMigrate() throws {
        var openedDatabase: OpaquePointer?
        guard sqlite3_open_v2(
            databaseURL.path,
            &openedDatabase,
            SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX,
            nil
        ) == SQLITE_OK else {
            let message = openedDatabase.map { String(cString: sqlite3_errmsg($0)) } ?? "Unknown SQLite error"
            sqlite3_close(openedDatabase)
            throw IndexError.database(message)
        }
        database = openedDatabase
        do {
            try execute("PRAGMA journal_mode=WAL;")
            try execute("PRAGMA synchronous=NORMAL;")
            try migrate()
        } catch {
            sqlite3_close(openedDatabase)
            database = nil
            throw error
        }
    }

    private func removeDatabaseFiles() throws {
        sqlite3_close(database)
        database = nil
        for suffix in ["", "-wal", "-shm"] {
            let path = databaseURL.path + suffix
            guard FileManager.default.fileExists(atPath: path) else { continue }
            do {
                try FileManager.default.removeItem(atPath: path)
            } catch {
                throw IndexError.database("The damaged Journal search index could not be replaced: \(error.localizedDescription)")
            }
        }
    }

    private func insert(_ chunk: Chunk) throws {
        var statement: OpaquePointer?
        let sql = "INSERT OR REPLACE INTO journal_chunks(id, entryID, date, text, vector, isStarred) VALUES (?, ?, ?, ?, ?, ?);"
        try prepare(sql, statement: &statement)
        defer { sqlite3_finalize(statement) }
        bind(chunk.id, to: statement, at: 1)
        bind(chunk.entryID.uuidString, to: statement, at: 2)
        sqlite3_bind_double(statement, 3, chunk.date.timeIntervalSince1970)
        bind(chunk.text, to: statement, at: 4)
        let vectorData = chunk.vector.withUnsafeBufferPointer { Data(buffer: $0) }
        _ = vectorData.withUnsafeBytes { bytes in
            sqlite3_bind_blob(statement, 5, bytes.baseAddress, Int32(bytes.count), Self.sqliteTransient)
        }
        sqlite3_bind_int(statement, 6, chunk.isStarred ? 1 : 0)
        try step(statement)

        var ftsStatement: OpaquePointer?
        try prepare("INSERT INTO journal_chunks_fts(id, entryID, text) VALUES (?, ?, ?);", statement: &ftsStatement)
        defer { sqlite3_finalize(ftsStatement) }
        bind(chunk.id, to: ftsStatement, at: 1)
        bind(chunk.entryID.uuidString, to: ftsStatement, at: 2)
        bind(chunk.text, to: ftsStatement, at: 3)
        try step(ftsStatement)
    }

    private func delete(entryID: UUID) throws {
        try execute("DELETE FROM journal_chunks WHERE entryID = ?;", bindings: [entryID.uuidString])
        try execute("DELETE FROM journal_chunks_fts WHERE entryID = ?;", bindings: [entryID.uuidString])
    }

    private func loadChunks() throws -> [Chunk] {
        var statement: OpaquePointer?
        try prepare("SELECT id, entryID, date, text, vector, isStarred FROM journal_chunks ORDER BY date DESC;", statement: &statement)
        defer { sqlite3_finalize(statement) }
        var chunks: [Chunk] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let id = string(statement, at: 0),
                  let entryIDString = string(statement, at: 1),
                  let entryID = UUID(uuidString: entryIDString),
                  let text = string(statement, at: 3),
                  let vector = vector(statement, at: 4),
                  vector.count == Self.embeddingDimension else { continue }
            chunks.append(
                Chunk(
                    id: id,
                    entryID: entryID,
                    date: Date(timeIntervalSince1970: sqlite3_column_double(statement, 2)),
                    text: text,
                    vector: vector,
                    isStarred: sqlite3_column_int(statement, 5) == 1
                )
            )
        }
        return chunks
    }

    private func lexicalSearch(query: String, limit: Int) throws -> [String] {
        let tokens = Self.tokens(in: query)
        guard !tokens.isEmpty else { return [] }
        let matchQuery = tokens.map { "\"\($0.replacingOccurrences(of: "\"", with: "\"\""))\"*" }.joined(separator: " OR ")
        var statement: OpaquePointer?
        try prepare("SELECT id FROM journal_chunks_fts WHERE journal_chunks_fts MATCH ? ORDER BY bm25(journal_chunks_fts) LIMIT ?;", statement: &statement)
        defer { sqlite3_finalize(statement) }
        bind(matchQuery, to: statement, at: 1)
        sqlite3_bind_int(statement, 2, Int32(limit))
        var ids: [String] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let value = string(statement, at: 0) { ids.append(value) }
        }
        return ids
    }

    private func embeddingVector(for text: String) -> [Float] {
        // Do not retain NLEmbedding across actor destruction. NaturalLanguage owns
        // the system model and cheaply resolves the language-specific handle.
        if let raw = NLEmbedding.sentenceEmbedding(for: .english)?.vector(for: text), !raw.isEmpty {
            return Self.projectAndNormalize(raw.map(Float.init), dimension: Self.embeddingDimension)
        }
        var fallback = Array(repeating: Float.zero, count: Self.embeddingDimension)
        for token in Self.tokens(in: text) {
            let digest = SHA256.hash(data: Data(token.utf8))
            let bucket = digest.withUnsafeBytes { bytes in
                (Int(bytes[0]) | (Int(bytes[1]) << 8)) % Self.embeddingDimension
            }
            fallback[bucket] += 1
        }
        return Self.normalize(fallback)
    }

    private static func projectAndNormalize(_ source: [Float], dimension: Int) -> [Float] {
        guard source.count != dimension else { return normalize(source) }
        var projected = Array(repeating: Float.zero, count: dimension)
        for (offset, value) in source.enumerated() {
            projected[offset % dimension] += value
        }
        return normalize(projected)
    }

    private static func normalize(_ vector: [Float]) -> [Float] {
        let magnitude = sqrt(vDSP.sumOfSquares(vector))
        guard magnitude > 0 else { return vector }
        return vDSP.divide(vector, magnitude)
    }

    private static func cosine(_ lhs: [Float], _ rhs: [Float]) -> Double {
        guard lhs.count == rhs.count, !lhs.isEmpty else { return 0 }
        return Double(vDSP.dot(lhs, rhs))
    }

    private static func chunk(_ text: String, targetWords: Int = 150, overlapWords: Int = 24) -> [String] {
        let words = text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).map(String.init)
        guard !words.isEmpty else { return [] }
        guard words.count > targetWords else { return [words.joined(separator: " ")] }
        var result: [String] = []
        var start = 0
        while start < words.count {
            let end = min(words.count, start + targetWords)
            result.append(words[start..<end].joined(separator: " "))
            if end == words.count { break }
            start = max(start + 1, end - overlapWords)
        }
        return result
    }

    private static func tokens(in text: String) -> [String] {
        text.lowercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
            .filter { $0.count > 2 }
    }

    private static func chunkID(entryID: UUID, offset: Int, text: String) -> String {
        let digest = SHA256.hash(data: Data("\(entryID.uuidString)|\(offset)|\(text)".utf8))
        return digest.prefix(12).map { String(format: "%02x", $0) }.joined()
    }

    private static func snippet(from text: String, query: String, maximumLength: Int = 190) -> String {
        guard text.count > maximumLength else { return text }
        let lowered = text.lowercased()
        let firstToken = tokens(in: query).first
        let matchOffset = firstToken.flatMap { lowered.range(of: $0) }.map { lowered.distance(from: lowered.startIndex, to: $0.lowerBound) } ?? 0
        let start = max(0, min(text.count - maximumLength, matchOffset - 55))
        let lower = text.index(text.startIndex, offsetBy: start)
        let upper = text.index(lower, offsetBy: maximumLength, limitedBy: text.endIndex) ?? text.endIndex
        return (start > 0 ? "…" : "") + text[lower..<upper] + (upper < text.endIndex ? "…" : "")
    }

    private func transaction(_ operation: () throws -> Void) throws {
        try execute("BEGIN IMMEDIATE;")
        do {
            try operation()
            try execute("COMMIT;")
        } catch {
            do { try execute("ROLLBACK;") } catch { /* Preserve the original failure. */ }
            throw error
        }
    }

    private func prepare(_ sql: String, statement: inout OpaquePointer?) throws {
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw IndexError.database(lastDatabaseError)
        }
    }

    private func step(_ statement: OpaquePointer?) throws {
        while true {
            switch sqlite3_step(statement) {
            case SQLITE_DONE:
                return
            case SQLITE_ROW:
                continue
            default:
                throw IndexError.database(lastDatabaseError)
            }
        }
    }

    private func execute(_ sql: String, bindings: [String] = []) throws {
        var statement: OpaquePointer?
        try prepare(sql, statement: &statement)
        defer { sqlite3_finalize(statement) }
        for (offset, binding) in bindings.enumerated() {
            bind(binding, to: statement, at: Int32(offset + 1))
        }
        try step(statement)
    }

    private func setMetadata(key: String, value: String) throws {
        try execute("INSERT OR REPLACE INTO journal_index_metadata(key, value) VALUES (?, ?);", bindings: [key, value])
    }

    private func metadataValue(key: String) throws -> String? {
        var statement: OpaquePointer?
        try prepare("SELECT value FROM journal_index_metadata WHERE key = ?;", statement: &statement)
        defer { sqlite3_finalize(statement) }
        bind(key, to: statement, at: 1)
        guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
        return string(statement, at: 0)
    }

    private func bind(_ value: String, to statement: OpaquePointer?, at index: Int32) {
        sqlite3_bind_text(statement, index, value, -1, Self.sqliteTransient)
    }

    private func string(_ statement: OpaquePointer?, at index: Int32) -> String? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL,
              let pointer = sqlite3_column_text(statement, index) else { return nil }
        return String(cString: pointer)
    }

    private func vector(_ statement: OpaquePointer?, at index: Int32) -> [Float]? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL,
              let pointer = sqlite3_column_blob(statement, index) else { return nil }
        let byteCount = Int(sqlite3_column_bytes(statement, index))
        guard byteCount.isMultiple(of: MemoryLayout<Float>.stride) else { return nil }
        return Data(bytes: pointer, count: byteCount).withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
    }

    private var lastDatabaseError: String {
        database.map { String(cString: sqlite3_errmsg($0)) } ?? "SQLite database is closed."
    }

    private func protectDatabaseFiles() throws {
        for suffix in ["", "-wal", "-shm"] {
            let url = URL(fileURLWithPath: databaseURL.path + suffix)
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            do {
                try Self.protectAndExcludeFromBackup(url)
            } catch {
                throw IndexError.fileProtection(error.localizedDescription)
            }
        }
    }

    private static func protectAndExcludeFromBackup(_ url: URL) throws {
        #if os(iOS)
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path)
        #endif
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutableURL = url
        try mutableURL.setResourceValues(values)
    }
}
