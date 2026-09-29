import LifeBoardDomain
import CryptoKit
import Foundation

// MARK: - Legacy Daily Reflection Migration

/// Imports the only durable user-authored value from the retired Sunrise Daily
/// Reflection feature into the canonical ReflectionNote repository.
///
/// This migration intentionally decodes neither completion markers nor
/// `DailyPlanDraft`. Those values were advisory UI state, not canonical acts,
/// and must never be converted into Daily Loop receipts or task mutations.
public final class LegacyDailyReflectionImporter: @unchecked Sendable {
    public struct Report: Equatable, Sendable {
        public let discoveredTextCount: Int
        public let importedTextCount: Int
        public let alreadyCompleted: Bool

        public init(discoveredTextCount: Int, importedTextCount: Int, alreadyCompleted: Bool) {
            self.discoveredTextCount = discoveredTextCount
            self.importedTextCount = importedTextCount
            self.alreadyCompleted = alreadyCompleted
        }
    }

    private struct LegacyStateFile: Decodable {
        let payloadsByDateKey: [String: LegacyPayload]
    }

    private struct LegacyPayload: Decodable {
        let reflectionDate: Date
        let note: String?
        let createdAt: Date
        let updatedAt: Date
    }

    static let legacyStorageKey = "tasker.dailyReflection.localState.v1"
    static let migrationMarkerKey = "tasker.migration.dailyReflectionTextToJournal.v1"

    private let defaults: UserDefaults
    private let repository: any ReflectionNoteRepositoryProtocol
    private let callbackQueue: DispatchQueue

    public init(
        defaults: UserDefaults = .standard,
        repository: any ReflectionNoteRepositoryProtocol,
        callbackQueue: DispatchQueue = .main
    ) {
        self.defaults = defaults
        self.repository = repository
        self.callbackQueue = callbackQueue
    }

    public func migrate(completion: @escaping @Sendable (Result<Report, Error>) -> Void) {
        guard defaults.bool(forKey: Self.migrationMarkerKey) == false else {
            callbackQueue.async {
                completion(.success(Report(discoveredTextCount: 0, importedTextCount: 0, alreadyCompleted: true)))
            }
            return
        }

        do {
            let notes = try makeNotes()
            importNext(notes[...], importedCount: 0, completion: completion)
        } catch {
            callbackQueue.async { completion(.failure(error)) }
        }
    }

    private func makeNotes() throws -> [ReflectionNote] {
        guard let data = defaults.data(forKey: Self.legacyStorageKey) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let file = try decoder.decode(LegacyStateFile.self, from: data)

        return file.payloadsByDateKey
            .values
            .compactMap { payload -> ReflectionNote? in
                guard let note = payload.note?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                      note.isEmpty == false else {
                    return nil
                }
                return ReflectionNote(
                    id: Self.deterministicID(for: payload),
                    kind: .legacyDailyReflection,
                    prompt: Self.provenanceLabel(for: payload.reflectionDate),
                    noteText: note,
                    createdAt: payload.createdAt,
                    updatedAt: payload.updatedAt
                )
            }
            .sorted { lhs, rhs in
                if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
                return lhs.id.uuidString < rhs.id.uuidString
            }
    }

    private func importNext(
        _ remaining: ArraySlice<ReflectionNote>,
        importedCount: Int,
        completion: @escaping @Sendable (Result<Report, Error>) -> Void
    ) {
        guard let note = remaining.first else {
            defaults.set(true, forKey: Self.migrationMarkerKey)
            let report = Report(
                discoveredTextCount: importedCount,
                importedTextCount: importedCount,
                alreadyCompleted: false
            )
            callbackQueue.async { completion(.success(report)) }
            return
        }

        repository.saveNote(note) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success:
                self.importNext(remaining.dropFirst(), importedCount: importedCount + 1, completion: completion)
            case .failure(let error):
                self.callbackQueue.async { completion(.failure(error)) }
            }
        }
    }

    private static func deterministicID(for payload: LegacyPayload) -> UUID {
        let seed = [
            "legacy-daily-reflection-v1",
            String(payload.reflectionDate.timeIntervalSinceReferenceDate),
            String(payload.createdAt.timeIntervalSinceReferenceDate)
        ].joined(separator: "|")
        var bytes = Array(SHA256.hash(data: Data(seed.utf8)).prefix(16))
        bytes[6] = (bytes[6] & 0x0F) | 0x50
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }

    private static func provenanceLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateFormat = "MMM d, yyyy"
        return "Imported from Daily Reflection · \(formatter.string(from: date))"
    }
}
