import Foundation
import CryptoKit
import Security
@preconcurrency import UIKit

/// Protected, local-only version history for deterministic weekly reflections.
/// This derived store is intentionally separate from the synced Journal schema.
public actor LocalWeeklyReflectionHistoryRepository: WeeklyReflectionHistoryRepository {
    private struct Envelope: Codable {
        var schemaVersion = 1
        var reports: [WeeklyReflectionReport]
    }

    private let fileURL: URL
    private let calendar: Calendar

    public init(rootURL: URL? = nil, calendar: Calendar = .current) throws {
        let baseURL: URL
        if let rootURL {
            baseURL = rootURL
        } else {
            guard let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
                throw JournalExportFailure.unableToCreateProtectedFile
            }
            baseURL = applicationSupport.appendingPathComponent("LifeBoard/JournalDerived", isDirectory: true)
        }
        try Self.prepareProtectedDirectory(baseURL)
        fileURL = baseURL.appendingPathComponent("WeeklyReflections.v1.json", isDirectory: false)
        self.calendar = calendar
    }

    public func reports(weekContaining date: Date? = nil) async throws -> [WeeklyReflectionReport] {
        try Task.checkCancellation()
        let values = try load()
        guard let date else { return values.sorted(by: Self.newestFirst) }
        let week = Self.weekInterval(containing: date, calendar: calendar)
        return values
            .filter { week.contains($0.weekStart) }
            .sorted { lhs, rhs in
                lhs.version == rhs.version ? lhs.createdAt > rhs.createdAt : lhs.version > rhs.version
            }
    }

    public func save(_ report: WeeklyReflectionReport) async throws {
        try Task.checkCancellation()
        var values = try load()
        values.removeAll { $0.id == report.id }
        values.append(report)
        try persist(values.sorted(by: Self.newestFirst))
    }

    public func delete(id: UUID) async throws {
        try Task.checkCancellation()
        var values = try load()
        values.removeAll { $0.id == id }
        try persist(values)
    }

    public func replaceAll(_ reports: [WeeklyReflectionReport]) async throws {
        try Task.checkCancellation()
        try persist(reports.sorted(by: Self.newestFirst))
    }

    private func load() throws -> [WeeklyReflectionReport] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        do {
            let data = try Data(contentsOf: fileURL)
            let envelope = try JSONDecoder.lifeBoardJournal.decode(Envelope.self, from: data)
            guard envelope.schemaVersion == 1 else { throw JournalExportFailure.encodingFailed }
            return envelope.reports
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            // A malformed derived file must never damage primary Journal data.
            let quarantine = fileURL.deletingPathExtension()
                .appendingPathExtension("corrupt-\(Int(Date().timeIntervalSince1970)).json")
            try? FileManager.default.moveItem(at: fileURL, to: quarantine)
            return []
        }
    }

    private func persist(_ reports: [WeeklyReflectionReport]) throws {
        do {
            let data = try JSONEncoder.lifeBoardJournal.encode(Envelope(reports: reports))
            try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
            try FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.complete],
                ofItemAtPath: fileURL.path
            )
        } catch {
            throw JournalExportFailure.unableToCreateProtectedFile
        }
    }

    private static func prepareProtectedDirectory(_ url: URL) throws {
        try FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.complete]
        )
    }

    private static func weekInterval(containing date: Date, calendar input: Calendar) -> DateInterval {
        var calendar = input
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        let day = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: day)
        let monday = calendar.date(byAdding: .day, value: -((weekday + 5) % 7), to: day) ?? day
        let end = calendar.date(byAdding: .day, value: 7, to: monday) ?? monday.addingTimeInterval(604_800)
        return DateInterval(start: monday, end: end)
    }

    private static func newestFirst(_ lhs: WeeklyReflectionReport, _ rhs: WeeklyReflectionReport) -> Bool {
        lhs.weekStart == rhs.weekStart ? lhs.version > rhs.version : lhs.weekStart > rhs.weekStart
    }
}

public actor LocalJournalExportService: JournalExporting {
    private struct ExportEnvelope: Codable {
        var schemaVersion = 1
        var generatedAt: Date
        var report: WeeklyReflectionReport
        var entries: [ExportEntry]
        var redactedSensitiveFields: Bool
    }

    private struct ExportEntry: Codable {
        var id: UUID
        var date: Date
        var title: String?
        var text: String
        var isStarred: Bool
        var mood: String?
        var energy: Int?
        var audioTranscriptions: [String]?
    }

    private let exportDirectory: URL

    public init(rootURL: URL? = nil) throws {
        let root: URL
        if let rootURL {
            root = rootURL
        } else {
            root = FileManager.default.temporaryDirectory
                .appendingPathComponent("LifeBoardProtectedExports", isDirectory: true)
        }
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.complete]
        )
        exportDirectory = root
    }

    public func export(_ request: JournalExportRequest) async throws -> JournalExportReceipt {
        try Task.checkCancellation()
        let selectedIDs = request.report.sourceSelection.includedEntryIDs
        let selected = request.entries
            .filter { selectedIDs.contains($0.id) }
            .sorted { $0.date < $1.date }
        guard request.report.density == .empty || selected.isEmpty == false else {
            throw JournalExportFailure.noSelectedEvidence
        }
        let redactsSensitive = request.includesSensitiveFields == false
        let envelope = ExportEnvelope(
            generatedAt: Date(),
            report: sanitizedReport(request.report),
            entries: selected.map { exportEntry($0, includesSensitiveFields: request.includesSensitiveFields) },
            redactedSensitiveFields: redactsSensitive
        )
        let data: Data
        switch request.format {
        case .json:
            data = try JSONEncoder.lifeBoardJournal.encode(envelope)
        case .markdown:
            data = Data(markdown(envelope).utf8)
        case .csv:
            data = Data(csv(envelope).utf8)
        case .pdf:
            let value = markdown(envelope)
            data = await MainActor.run { Self.pdf(text: value) }
        }
        try Task.checkCancellation()
        let fileURL = exportDirectory.appendingPathComponent(filename(for: request), isDirectory: false)
        do {
            try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
            try FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.complete],
                ofItemAtPath: fileURL.path
            )
        } catch {
            throw JournalExportFailure.unableToCreateProtectedFile
        }
        return JournalExportReceipt(
            fileURL: fileURL,
            format: request.format,
            redactedSensitiveFields: redactsSensitive
        )
    }

    private func exportEntry(_ entry: JournalEntrySnapshot, includesSensitiveFields: Bool) -> ExportEntry {
        let transcripts = entry.attachments.compactMap { attachment in
            attachment.kind == .audio ? attachment.transcription : nil
        }
        return ExportEntry(
            id: entry.id,
            date: entry.date,
            title: entry.title,
            text: entry.text,
            isStarred: entry.isStarred,
            mood: includesSensitiveFields ? entry.mood?.rawValue : nil,
            energy: includesSensitiveFields ? entry.energy : nil,
            audioTranscriptions: includesSensitiveFields && transcripts.isEmpty == false ? transcripts : nil
        )
    }

    private func sanitizedReport(_ report: WeeklyReflectionReport) -> WeeklyReflectionReport {
        var value = report
        // Stable source IDs are useful inside LifeBoard but not needed in a portable document.
        value.sourceSelection.includedEntryIDs = []
        return value
    }

    private func filename(for request: JournalExportRequest) -> String {
        let date = request.report.weekStart.formatted(.iso8601.year().month().day())
        return "LifeBoard-Journal-Week-\(date)-v\(request.report.version).\(request.format.rawValue)"
    }

    private func markdown(_ envelope: ExportEnvelope) -> String {
        var lines = [
            "# Weekly Reflection",
            "",
            "**Week:** \(envelope.report.weekStart.formatted(date: .long, time: .omitted)) – \(envelope.report.weekEnd.formatted(date: .long, time: .omitted))",
            "**Version:** \(envelope.report.version)",
            "**Density:** \(envelope.report.density.rawValue.capitalized)",
            "",
            envelope.report.summary
        ]
        if let takeaway = envelope.report.takeaway, takeaway.isEmpty == false {
            lines += ["", "## Takeaway", "", takeaway]
        }
        if envelope.redactedSensitiveFields {
            lines += ["", "> Mood, energy, audio transcription, media, and local semantic index data were excluded."]
        }
        for entry in envelope.entries {
            lines += ["", "## \(entry.date.formatted(date: .long, time: .omitted))", "", entry.text]
            if let mood = entry.mood { lines.append("\nMood: \(mood)") }
            if let energy = entry.energy { lines.append("Energy: \(energy)/5") }
            for transcript in entry.audioTranscriptions ?? [] { lines.append("\nAudio transcript: \(transcript)") }
        }
        return lines.joined(separator: "\n")
    }

    private func csv(_ envelope: ExportEnvelope) -> String {
        var rows = ["entry_id,date,title,text,starred,mood,energy,audio_transcriptions"]
        for entry in envelope.entries {
            rows.append([
                entry.id.uuidString,
                entry.date.formatted(.iso8601),
                entry.title ?? "",
                entry.text,
                entry.isStarred ? "true" : "false",
                entry.mood ?? "",
                entry.energy.map(String.init) ?? "",
                (entry.audioTranscriptions ?? []).joined(separator: " | ")
            ].map(Self.csvField).joined(separator: ","))
        }
        return rows.joined(separator: "\n")
    }

    private static func csvField(_ value: String) -> String {
        "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    @MainActor
    private static func pdf(text: String) -> Data {
        let page = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: page)
        return renderer.pdfData { context in
            let content = text as NSString
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11),
                .foregroundColor: UIColor.label
            ]
            let inset = page.insetBy(dx: 44, dy: 44)
            let layout = NSLayoutManager()
            let storage = NSTextStorage(string: content as String, attributes: attributes)
            storage.addLayoutManager(layout)
            var glyphIndex = 0
            while glyphIndex < layout.numberOfGlyphs {
                context.beginPage()
                let container = NSTextContainer(size: inset.size)
                container.lineFragmentPadding = 0
                layout.addTextContainer(container)
                let range = layout.glyphRange(for: container)
                layout.drawGlyphs(forGlyphRange: range, at: inset.origin)
                glyphIndex = NSMaxRange(range)
                if range.length == 0 { break }
            }
        }
    }
}

public actor LocalJournalBackupService: JournalBackupServicing {
    private struct EncryptedEnvelope: Codable {
        var formatVersion: Int
        var kdfIterations: Int
        var salt: Data
        var sealedPayload: Data
    }

    private let backupDirectory: URL
    private let audioDirectory: URL
    private let kdfIterations: Int
    private let maximumMediaBytes = 100 * 1_024 * 1_024
    private let maximumArchiveBytes = 750 * 1_024 * 1_024

    public init(rootURL: URL? = nil, audioRootURL: URL? = nil, kdfIterations: Int = 100_000) throws {
        guard (100...500_000).contains(kdfIterations) else { throw JournalBackupFailure.malformedArchive }
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        backupDirectory = rootURL ?? support.appendingPathComponent("LifeBoard/JournalBackups", isDirectory: true)
        audioDirectory = audioRootURL ?? support.appendingPathComponent("LifeBoardJournalAudio", isDirectory: true)
        self.kdfIterations = kdfIterations
        try Self.prepareProtectedDirectory(backupDirectory)
        try Self.prepareProtectedDirectory(audioDirectory)
    }

    public func createBackup(
        days: [LifeBoardJournalDayValue],
        reflections: [WeeklyReflectionReport],
        passphrase: String
    ) async throws -> JournalBackupReceipt {
        try validatePassphrase(passphrase)
        try Self.validate(days: days)
        var audioPayloads: [UUID: Data] = [:]
        var totalBytes = 0
        for media in days.flatMap(\.media) where media.kind == .audio {
            try Task.checkCancellation()
            guard let relativePath = media.relativePath else { continue }
            let url = try safeAudioURL(relativePath: relativePath)
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            let data = try Data(contentsOf: url, options: [.mappedIfSafe])
            guard data.count <= maximumMediaBytes else { throw JournalBackupFailure.payloadTooLarge }
            totalBytes += data.count
            guard totalBytes <= maximumArchiveBytes else { throw JournalBackupFailure.payloadTooLarge }
            audioPayloads[media.id] = data
        }
        let archive = JournalBackupArchive(
            appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown",
            days: days,
            reflectionReports: reflections,
            audioPayloads: audioPayloads
        )
        let plaintext = try JSONEncoder.lifeBoardJournal.encode(archive)
        guard plaintext.count <= maximumArchiveBytes else { throw JournalBackupFailure.payloadTooLarge }
        let salt = Self.randomData(count: 16)
        let key = try await Self.deriveKey(passphrase: passphrase, salt: salt, iterations: kdfIterations)
        let sealed = try AES.GCM.seal(plaintext, using: key)
        guard let combined = sealed.combined else { throw JournalBackupFailure.protectedFileFailure }
        let envelope = EncryptedEnvelope(
            formatVersion: 1,
            kdfIterations: kdfIterations,
            salt: salt,
            sealedPayload: combined
        )
        let data = try JSONEncoder.lifeBoardJournal.encode(envelope)
        let stamp = archive.createdAt.formatted(.iso8601.year().month().day().dateSeparator(.dash))
        let url = backupDirectory.appendingPathComponent("LifeBoard-Journal-\(stamp).lifeboardjournal")
        do {
            try data.write(to: url, options: [.atomic, .completeFileProtection])
            try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path)
        } catch {
            throw JournalBackupFailure.protectedFileFailure
        }
        return JournalBackupReceipt(fileURL: url, dayCount: days.count, audioCount: audioPayloads.count)
    }

    public func restoreBackup(
        from fileURL: URL,
        passphrase: String,
        duplicatePolicy: JournalBackupDuplicatePolicy,
        applyingTo applier: any JournalBackupImportApplying,
        reflectionRepository: any WeeklyReflectionHistoryRepository
    ) async throws -> JournalImportReceipt {
        try validatePassphrase(passphrase)
        let accessed = fileURL.startAccessingSecurityScopedResource()
        defer { if accessed { fileURL.stopAccessingSecurityScopedResource() } }
        let envelope: EncryptedEnvelope
        do {
            let data = try Data(contentsOf: fileURL, options: [.mappedIfSafe])
            guard data.count <= maximumArchiveBytes else { throw JournalBackupFailure.payloadTooLarge }
            envelope = try JSONDecoder.lifeBoardJournal.decode(EncryptedEnvelope.self, from: data)
        } catch let error as JournalBackupFailure {
            throw error
        } catch {
            throw JournalBackupFailure.malformedArchive
        }
        guard envelope.formatVersion == 1 else { throw JournalBackupFailure.unsupportedVersion }
        guard envelope.salt.count == 16,
              (100...500_000).contains(envelope.kdfIterations) else { throw JournalBackupFailure.malformedArchive }
        let archive: JournalBackupArchive
        do {
            let key = try await Self.deriveKey(
                passphrase: passphrase,
                salt: envelope.salt,
                iterations: envelope.kdfIterations
            )
            let box = try AES.GCM.SealedBox(combined: envelope.sealedPayload)
            let plaintext = try AES.GCM.open(box, using: key)
            archive = try JSONDecoder.lifeBoardJournal.decode(JournalBackupArchive.self, from: plaintext)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw JournalBackupFailure.authenticationFailed
        }
        guard archive.schemaVersion == 1 else { throw JournalBackupFailure.unsupportedVersion }
        try Self.validate(days: archive.days)
        try Self.validate(audioPayloads: archive.audioPayloads, maximumBytes: maximumMediaBytes, maximumTotal: maximumArchiveBytes)

        var days = archive.days
        var createdAudioURLs: [URL] = []
        do {
            for dayIndex in days.indices {
                for mediaIndex in days[dayIndex].media.indices where days[dayIndex].media[mediaIndex].kind == .audio {
                    let mediaID = days[dayIndex].media[mediaIndex].id
                    guard let payload = archive.audioPayloads[mediaID] else {
                        days[dayIndex].media[mediaIndex].relativePath = nil
                        continue
                    }
                    let name = UUID().uuidString + ".m4a"
                    let url = audioDirectory.appendingPathComponent(name, isDirectory: false)
                    try payload.write(to: url, options: [.atomic, .completeFileProtection])
                    try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path)
                    days[dayIndex].media[mediaIndex].relativePath = name
                    createdAudioURLs.append(url)
                }
            }
        } catch {
            createdAudioURLs.forEach { try? FileManager.default.removeItem(at: $0) }
            throw JournalBackupFailure.protectedFileFailure
        }

        let previousReflections = try await reflectionRepository.reports(weekContaining: nil)
        let mergedReflections = Self.mergeReflections(
            existing: previousReflections,
            imported: archive.reflectionReports,
            duplicatePolicy: duplicatePolicy
        )
        do {
            try await reflectionRepository.replaceAll(mergedReflections)
            let receipt = try await applier.importJournalDays(days, duplicatePolicy: duplicatePolicy)
            return receipt
        } catch {
            try? await reflectionRepository.replaceAll(previousReflections)
            createdAudioURLs.forEach { try? FileManager.default.removeItem(at: $0) }
            throw error
        }
    }

    private func validatePassphrase(_ passphrase: String) throws {
        guard passphrase.count >= 8 else { throw JournalBackupFailure.weakPassphrase }
    }

    private func safeAudioURL(relativePath: String) throws -> URL {
        guard relativePath == URL(fileURLWithPath: relativePath).lastPathComponent,
              relativePath.contains("/") == false,
              relativePath.contains("\\") == false else { throw JournalBackupFailure.unsafeMediaPath }
        return audioDirectory.appendingPathComponent(relativePath, isDirectory: false)
    }

    private static func validate(days: [LifeBoardJournalDayValue]) throws {
        var dayIDs = Set<UUID>()
        var blockIDs = Set<UUID>()
        var mediaIDs = Set<UUID>()
        for day in days {
            guard dayIDs.insert(day.id).inserted else { throw JournalBackupFailure.invalidIdentity }
            for block in day.blocks {
                guard block.dayID == day.id, blockIDs.insert(block.id).inserted else {
                    throw JournalBackupFailure.invalidIdentity
                }
            }
            for media in day.media {
                guard media.dayID == day.id, mediaIDs.insert(media.id).inserted else {
                    throw JournalBackupFailure.invalidIdentity
                }
                if let path = media.relativePath,
                   path != URL(fileURLWithPath: path).lastPathComponent || path.contains("/") || path.contains("\\") {
                    throw JournalBackupFailure.unsafeMediaPath
                }
            }
            let localMediaIDs = Set(day.media.map(\.id))
            guard day.blocks.compactMap(\.mediaID).allSatisfy(localMediaIDs.contains) else {
                throw JournalBackupFailure.invalidIdentity
            }
        }
    }

    private static func validate(
        audioPayloads: [UUID: Data],
        maximumBytes: Int,
        maximumTotal: Int
    ) throws {
        var total = 0
        for payload in audioPayloads.values {
            guard payload.count <= maximumBytes else { throw JournalBackupFailure.payloadTooLarge }
            total += payload.count
            guard total <= maximumTotal else { throw JournalBackupFailure.payloadTooLarge }
        }
    }

    private static func mergeReflections(
        existing: [WeeklyReflectionReport],
        imported: [WeeklyReflectionReport],
        duplicatePolicy: JournalBackupDuplicatePolicy
    ) -> [WeeklyReflectionReport] {
        var values = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
        for report in imported {
            switch duplicatePolicy {
            case .keepExisting:
                if values[report.id] == nil { values[report.id] = report }
            case .replaceExisting:
                values[report.id] = report
            case .duplicateWithNewIDs:
                let copy = WeeklyReflectionReport(
                    weekStart: report.weekStart,
                    weekEnd: report.weekEnd,
                    density: report.density,
                    summary: report.summary,
                    takeaway: report.takeaway,
                    sourceSelection: .init(includedEntryIDs: [], excludesSensitiveEntries: true),
                    version: report.version,
                    createdAt: Date(),
                    dismissedAt: report.dismissedAt
                )
                values[copy.id] = copy
            }
        }
        return Array(values.values)
    }

    private static func deriveKey(passphrase: String, salt: Data, iterations: Int) async throws -> SymmetricKey {
        let passwordKey = SymmetricKey(data: Data(passphrase.utf8))
        let block = Data([0, 0, 0, 1])
        var u = Data(HMAC<SHA256>.authenticationCode(for: salt + block, using: passwordKey))
        var result = [UInt8](u)
        if iterations > 1 {
            for iteration in 2...iterations {
                if iteration.isMultiple(of: 1_024) { try Task.checkCancellation() }
                u = Data(HMAC<SHA256>.authenticationCode(for: u, using: passwordKey))
                let bytes = [UInt8](u)
                for index in result.indices { result[index] ^= bytes[index] }
            }
        }
        return SymmetricKey(data: Data(result))
    }

    private static func randomData(count: Int) -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        _ = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        return Data(bytes)
    }

    private static func prepareProtectedDirectory(_ url: URL) throws {
        do {
            try FileManager.default.createDirectory(
                at: url,
                withIntermediateDirectories: true,
                attributes: [.protectionKey: FileProtectionType.complete]
            )
        } catch {
            throw JournalBackupFailure.protectedFileFailure
        }
    }
}

private extension JSONEncoder {
    static var lifeBoardJournal: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }
}

private extension JSONDecoder {
    static var lifeBoardJournal: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
