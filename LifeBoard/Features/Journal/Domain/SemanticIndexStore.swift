//
//  SemanticIndexStore.swift
//  SemanticMemoryKit
//
//  SQLite sidecar for chunk vectors and FTS lexical search. Local-only and
//  rebuildable; never syncs. File protection applies on iOS.
//

import Foundation
import SQLite3
import os

let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

final class LocalSemanticIndexStore {
    private let url: URL
    private var db: OpaquePointer?

    init(url: URL) throws {
        self.url = url
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        #if os(iOS)
        try? FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: url.deletingLastPathComponent().path)
        #endif
        guard sqlite3_open(url.path, &db) == SQLITE_OK else {
            throw StoreError.open(message: lastError)
        }
        try execute("PRAGMA journal_mode=WAL;")
        try execute("PRAGMA foreign_keys=ON;")
        try migrate()
        #if os(iOS)
        try? FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path)
        #endif
    }

    deinit {
        sqlite3_close(db)
    }

    enum StoreError: LocalizedError {
        case open(message: String)
        case sql(message: String)

        var errorDescription: String? {
            switch self {
            case .open(let message), .sql(let message):
                return message
            }
        }
    }

    private var lastError: String {
        if let db {
            return String(cString: sqlite3_errmsg(db))
        }
        return "SQLite database is not open."
    }

    func loadChunks() throws -> MemoryIndexSnapshot? {
        guard let schema = try metadataValue("schemaVersion").flatMap(Int.init),
              let chunking = try metadataValue("chunkingVersion").flatMap(Int.init),
              schema == MemoryIndexSnapshot.currentSchemaVersion,
              chunking == MemoryIndexSnapshot.currentChunkingVersion else {
            return nil
        }

        var statement: OpaquePointer?
        let sql = """
        SELECT id, entryID, chunkIndex, date, mood, textHash, entryTextHash, characterStart, characterEnd,
               entities, topics, embeddingModelID, embeddingRevision, embeddingDimension, language, vector, isStarred
        FROM chunks ORDER BY date DESC, chunkIndex ASC;
        """
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw StoreError.sql(message: lastError)
        }
        defer { sqlite3_finalize(statement) }

        var chunks: [MemoryChunk] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let id = string(statement, 0),
                  let entryIDString = string(statement, 1),
                  let entryID = UUID(uuidString: entryIDString),
                  let textHash = string(statement, 5),
                  let entryTextHash = string(statement, 6),
                  let entitiesJSON = string(statement, 9),
                  let topicsJSON = string(statement, 10),
                  let modelID = string(statement, 11),
                  let language = string(statement, 14) else { continue }

            let vector = data(statement, 15).map(Self.vector(from:)) ?? []
            chunks.append(
                MemoryChunk(
                    id: id,
                    entryID: entryID,
                    chunkIndex: Int(sqlite3_column_int(statement, 2)),
                    date: Date(timeIntervalSince1970: sqlite3_column_double(statement, 3)),
                    mood: string(statement, 4),
                    textHash: textHash,
                    entryTextHash: entryTextHash,
                    characterStart: Int(sqlite3_column_int(statement, 7)),
                    characterEnd: Int(sqlite3_column_int(statement, 8)),
                    entities: Self.decodeStringArray(entitiesJSON),
                    topics: Self.decodeStringArray(topicsJSON),
                    embeddingModelID: modelID,
                    embeddingRevision: Int(sqlite3_column_int(statement, 12)),
                    embeddingDimension: Int(sqlite3_column_int(statement, 13)),
                    language: language,
                    vector: vector,
                    isStarred: sqlite3_column_int(statement, 16) == 1
                )
            )
        }

        if !chunks.isEmpty {
            let metadataModelID = try metadataValue("embeddingModelID") ?? ""
            let metadataRevision = Int(try metadataValue("embeddingRevision") ?? "0") ?? 0
            let metadataDimension = Int(try metadataValue("embeddingDimension") ?? "0") ?? 0
            let providerMetadataMatchesChunks = chunks.allSatisfy { chunk in
                chunk.embeddingModelID == metadataModelID
                && chunk.embeddingRevision == metadataRevision
                && chunk.embeddingDimension == metadataDimension
                && chunk.vector.count == chunk.embeddingDimension
                && !chunk.vector.isEmpty
            }
            guard providerMetadataMatchesChunks else { return nil }
        }

        let snapshot = MemoryIndexSnapshot(
            schemaVersion: schema,
            chunkingVersion: chunking,
            embeddingModelID: try metadataValue("embeddingModelID") ?? "",
            embeddingRevision: Int(try metadataValue("embeddingRevision") ?? "0") ?? 0,
            embeddingDimension: Int(try metadataValue("embeddingDimension") ?? "0") ?? 0,
            updatedAt: Date(timeIntervalSince1970: Double(try metadataValue("updatedAt") ?? "0") ?? 0),
            chunks: chunks
        )
        return snapshot
    }

    func replaceAll(chunks: [MemoryChunk], textByChunkID: [String: String]) throws {
        try transaction {
            try deleteAllLocked()
            try insert(chunks: chunks, textByChunkID: textByChunkID)
            try writeMetadata(chunks: chunks)
        }
        protectSidecarFiles()
    }

    func upsert(entryID: UUID, chunks: [MemoryChunk], textByChunkID: [String: String]) throws {
        try transaction {
            try deleteEntryLocked(entryID)
            try insert(chunks: chunks, textByChunkID: textByChunkID)
            try writeMetadata(chunks: chunks.isEmpty ? try loadChunks()?.chunks ?? [] : allChunksMerged(with: chunks, replacing: entryID))
        }
        protectSidecarFiles()
    }

    func deleteEntry(_ entryID: UUID) throws {
        try transaction {
            try deleteEntryLocked(entryID)
            try writeMetadata(chunks: try loadChunks()?.chunks ?? [])
        }
        protectSidecarFiles()
    }

    func deleteAll() throws {
        try transaction {
            try deleteAllLocked()
            try setMetadata("schemaVersion", "\(MemoryIndexSnapshot.currentSchemaVersion)")
            try setMetadata("chunkingVersion", "\(MemoryIndexSnapshot.currentChunkingVersion)")
            try setMetadata("updatedAt", "\(Date().timeIntervalSince1970)")
        }
        protectSidecarFiles()
    }

    func lexicalSearch(query: String, limit: Int) throws -> [String] {
        guard let matchQuery = Self.ftsQuery(for: query) else { return [] }
        var statement: OpaquePointer?
        let sql = """
        SELECT id FROM chunk_fts
        WHERE chunk_fts MATCH ?
        ORDER BY bm25(chunk_fts)
        LIMIT ?;
        """
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw StoreError.sql(message: lastError)
        }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_text(statement, 1, matchQuery, -1, sqliteTransient)
        sqlite3_bind_int(statement, 2, Int32(limit))

        var ids: [String] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let id = string(statement, 0) {
                ids.append(id)
            }
        }
        return ids
    }

    private func migrate() throws {
        try execute("""
        CREATE TABLE IF NOT EXISTS chunks (
            id TEXT PRIMARY KEY NOT NULL,
            entryID TEXT NOT NULL,
            chunkIndex INTEGER NOT NULL,
            date REAL NOT NULL,
            mood TEXT,
            textHash TEXT NOT NULL,
            entryTextHash TEXT NOT NULL,
            characterStart INTEGER NOT NULL,
            characterEnd INTEGER NOT NULL,
            entities TEXT NOT NULL,
            topics TEXT NOT NULL,
            embeddingModelID TEXT NOT NULL,
            embeddingRevision INTEGER NOT NULL,
            embeddingDimension INTEGER NOT NULL,
            language TEXT NOT NULL,
            vector BLOB NOT NULL,
            isStarred INTEGER NOT NULL
        );
        """)
        try execute("CREATE INDEX IF NOT EXISTS idx_chunks_entry ON chunks(entryID);")
        try execute("CREATE TABLE IF NOT EXISTS metadata (key TEXT PRIMARY KEY NOT NULL, value TEXT NOT NULL);")
        try execute("CREATE VIRTUAL TABLE IF NOT EXISTS chunk_fts USING fts5(id UNINDEXED, entryID UNINDEXED, text, tokenize='unicode61');")
    }

    private func allChunksMerged(with newChunks: [MemoryChunk], replacing entryID: UUID) -> [MemoryChunk] {
        let current = (try? loadChunks()?.chunks) ?? []
        return current.filter { $0.entryID != entryID } + newChunks
    }

    private func insert(chunks: [MemoryChunk], textByChunkID: [String: String]) throws {
        let sql = """
        INSERT OR REPLACE INTO chunks
        (id, entryID, chunkIndex, date, mood, textHash, entryTextHash, characterStart, characterEnd, entities, topics,
         embeddingModelID, embeddingRevision, embeddingDimension, language, vector, isStarred)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        for chunk in chunks {
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw StoreError.sql(message: lastError)
            }
            defer { sqlite3_finalize(statement) }
            sqlite3_bind_text(statement, 1, chunk.id, -1, sqliteTransient)
            sqlite3_bind_text(statement, 2, chunk.entryID.uuidString, -1, sqliteTransient)
            sqlite3_bind_int(statement, 3, Int32(chunk.chunkIndex))
            sqlite3_bind_double(statement, 4, chunk.date.timeIntervalSince1970)
            bindOptionalText(statement, 5, chunk.mood)
            sqlite3_bind_text(statement, 6, chunk.textHash, -1, sqliteTransient)
            sqlite3_bind_text(statement, 7, chunk.entryTextHash, -1, sqliteTransient)
            sqlite3_bind_int(statement, 8, Int32(chunk.characterStart))
            sqlite3_bind_int(statement, 9, Int32(chunk.characterEnd))
            sqlite3_bind_text(statement, 10, Self.encodeStringArray(chunk.entities), -1, sqliteTransient)
            sqlite3_bind_text(statement, 11, Self.encodeStringArray(chunk.topics), -1, sqliteTransient)
            sqlite3_bind_text(statement, 12, chunk.embeddingModelID, -1, sqliteTransient)
            sqlite3_bind_int(statement, 13, Int32(chunk.embeddingRevision))
            sqlite3_bind_int(statement, 14, Int32(chunk.embeddingDimension))
            sqlite3_bind_text(statement, 15, chunk.language, -1, sqliteTransient)
            let vectorData = Self.data(from: chunk.vector)
            _ = vectorData.withUnsafeBytes { buffer in
                sqlite3_bind_blob(statement, 16, buffer.baseAddress, Int32(vectorData.count), sqliteTransient)
            }
            sqlite3_bind_int(statement, 17, chunk.isStarred ? 1 : 0)
            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw StoreError.sql(message: lastError)
            }

            try insertFTS(chunk: chunk, text: textByChunkID[chunk.id] ?? "")
        }
    }

    private func insertFTS(chunk: MemoryChunk, text: String) throws {
        var statement: OpaquePointer?
        let sql = "INSERT INTO chunk_fts(id, entryID, text) VALUES (?, ?, ?);"
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw StoreError.sql(message: lastError)
        }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_text(statement, 1, chunk.id, -1, sqliteTransient)
        sqlite3_bind_text(statement, 2, chunk.entryID.uuidString, -1, sqliteTransient)
        let tokenText = TextSignals.tokens(in: text).joined(separator: " ")
        sqlite3_bind_text(statement, 3, tokenText, -1, sqliteTransient)
        while true {
            let result = sqlite3_step(statement)
            switch result {
            case SQLITE_DONE:
                return
            case SQLITE_ROW:
                continue
            default:
                throw StoreError.sql(message: lastError)
            }
        }
    }

    private func deleteEntryLocked(_ entryID: UUID) throws {
        try execute("DELETE FROM chunks WHERE entryID = ?;", bindings: [entryID.uuidString])
        try execute("DELETE FROM chunk_fts WHERE entryID = ?;", bindings: [entryID.uuidString])
    }

    private func deleteAllLocked() throws {
        try execute("DELETE FROM chunks;")
        try execute("DELETE FROM chunk_fts;")
    }

    private func writeMetadata(chunks: [MemoryChunk]) throws {
        let first = chunks.first
        try setMetadata("schemaVersion", "\(MemoryIndexSnapshot.currentSchemaVersion)")
        try setMetadata("chunkingVersion", "\(MemoryIndexSnapshot.currentChunkingVersion)")
        try setMetadata("embeddingModelID", first?.embeddingModelID ?? "")
        try setMetadata("embeddingRevision", "\(first?.embeddingRevision ?? 0)")
        try setMetadata("embeddingDimension", "\(first?.embeddingDimension ?? 0)")
        try setMetadata("updatedAt", "\(Date().timeIntervalSince1970)")
    }

    private func setMetadata(_ key: String, _ value: String) throws {
        try execute(
            "INSERT OR REPLACE INTO metadata(key, value) VALUES (?, ?);",
            bindings: [key, value]
        )
    }

    private func metadataValue(_ key: String) throws -> String? {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT value FROM metadata WHERE key = ?;", -1, &statement, nil) == SQLITE_OK else {
            throw StoreError.sql(message: lastError)
        }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_text(statement, 1, key, -1, sqliteTransient)
        guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
        return string(statement, 0)
    }

    private func transaction(_ work: () throws -> Void) throws {
        try execute("BEGIN IMMEDIATE;")
        do {
            try work()
            try execute("COMMIT;")
        } catch {
            try? execute("ROLLBACK;")
            throw error
        }
    }

    private func execute(_ sql: String, bindings: [String] = []) throws {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw StoreError.sql(message: lastError)
        }
        defer { sqlite3_finalize(statement) }
        for (index, value) in bindings.enumerated() {
            sqlite3_bind_text(statement, Int32(index + 1), value, -1, sqliteTransient)
        }
        while true {
            let result = sqlite3_step(statement)
            switch result {
            case SQLITE_DONE:
                return
            case SQLITE_ROW:
                continue
            default:
                throw StoreError.sql(message: lastError)
            }
        }
    }

    private func string(_ statement: OpaquePointer?, _ index: Int32) -> String? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL,
              let pointer = sqlite3_column_text(statement, index) else { return nil }
        return String(cString: pointer)
    }

    private func data(_ statement: OpaquePointer?, _ index: Int32) -> Data? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL,
              let bytes = sqlite3_column_blob(statement, index) else { return nil }
        return Data(bytes: bytes, count: Int(sqlite3_column_bytes(statement, index)))
    }

    private func bindOptionalText(_ statement: OpaquePointer?, _ index: Int32, _ value: String?) {
        if let value {
            sqlite3_bind_text(statement, index, value, -1, sqliteTransient)
        } else {
            sqlite3_bind_null(statement, index)
        }
    }

    private func protectSidecarFiles() {
        #if os(iOS)
        for suffix in ["", "-wal", "-shm"] {
            try? FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path + suffix)
        }
        #endif
    }

    private static func encodeStringArray(_ values: [String]) -> String {
        guard let data = try? JSONEncoder().encode(values),
              let string = String(data: data, encoding: .utf8) else { return "[]" }
        return string
    }

    private static func decodeStringArray(_ string: String) -> [String] {
        guard let data = string.data(using: .utf8),
              let values = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return values
    }

    private static func data(from vector: [Float]) -> Data {
        vector.withUnsafeBufferPointer { buffer in
            Data(buffer: buffer)
        }
    }

    private static func vector(from data: Data) -> [Float] {
        data.withUnsafeBytes { rawBuffer in
            let buffer = rawBuffer.bindMemory(to: Float.self)
            return Array(buffer)
        }
    }

    private static func ftsQuery(for query: String) -> String? {
        let tokens = TextSignals.tokens(in: query)
        guard !tokens.isEmpty else { return nil }
        return tokens
            .prefix(8)
            .map { "\"\($0.replacingOccurrences(of: "\"", with: "\"\""))\"" }
            .joined(separator: " OR ")
    }

    #if DEBUG
    func overwriteMetadataForTesting(key: String, value: String) throws {
        try setMetadata(key, value)
    }
    #endif
}
