import Foundation
import CoreData
import CryptoKit
import WatchCaptureKit

#if canImport(WatchConnectivity) && os(iOS)
import WatchConnectivity

/// Durable, file-protected holding area for captures that cannot be committed
/// immediately. It keeps private payloads out of UserDefaults and diagnostics.
actor LifeBoardWatchCaptureRecoveryStore {
    private var records: [WatchCaptureRecoveryRecord] = []
    private let fileURL: URL

    init(fileManager: FileManager = .default) {
        let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = support.appendingPathComponent("LifeBoardWatchCaptureRecovery", isDirectory: true)
        try? fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.complete]
        )
        fileURL = directory.appendingPathComponent("recovery.json")
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder.watchCapture.decode([WatchCaptureRecoveryRecord].self, from: data) {
            records = decoded
        }
    }

    func all() -> [WatchCaptureRecoveryRecord] { records }

    func upsert(_ record: WatchCaptureRecoveryRecord) {
        if let captureID = record.captureID,
           let index = records.firstIndex(where: { $0.captureID == captureID }) {
            records[index] = record
        } else {
            records.append(record)
        }
        persist()
    }

    func remove(captureID: UUID) {
        records.removeAll { $0.captureID == captureID }
        persist()
    }

    func remove(id: UUID) {
        records.removeAll { $0.id == id }
        persist()
    }

    private func persist() {
        do {
            let data = try JSONEncoder.watchCapture.encode(records)
            try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
            try FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.complete],
                ofItemAtPath: fileURL.path
            )
        } catch {
            logDebug("WATCH_CAPTURE recovery_store_unavailable")
        }
    }
}

/// The phone-side import boundary for Watch journal captures. Canonical
/// Journal storage is committed before an acknowledgement is created.
actor LifeBoardWatchCaptureImporter {
    enum ImportFailure: Error { case unsupportedEnvelope, missingAudio }

    private let repository: any LifeBoardPhaseIIRepository
    private let container: NSPersistentContainer

    init(repository: any LifeBoardPhaseIIRepository, container: NSPersistentContainer) {
        self.repository = repository
        self.container = container
    }

    func importCapture(
        _ envelope: WatchCaptureEnvelope,
        audioURL: URL? = nil
    ) async throws -> WatchCaptureReceipt {
        guard envelope.schemaVersion == WatchCaptureEnvelope.schemaVersion else {
            throw ImportFailure.unsupportedEnvelope
        }
        if let existing = try await existingReceipt(captureID: envelope.captureID) {
            return WatchCaptureReceipt(
                captureID: envelope.captureID,
                importedEntryID: existing,
                kind: envelope.kind
            )
        }

        let calendar = Calendar.current
        let dayDate = calendar.startOfDay(for: envelope.createdAtUTC)
        var day = try await repository.fetchJournalDay(containing: dayDate)
            ?? LifeBoardJournalDayValue(day: dayDate)
        let now = Date()

        switch envelope.kind {
        case .mood:
            let mood = envelope.moodValue.flatMap(LifeBoardJournalMood.init(rawValue:)) ?? .none
            day.blocks.append(.init(
                id: envelope.captureID,
                dayID: day.id,
                kind: .mood,
                mood: mood,
                createdAt: envelope.createdAtUTC,
                updatedAt: now,
                ordinal: day.blocks.count
            ))
        case .speak:
            let text = envelope.text?.trimmingCharacters(in: .whitespacesAndNewlines)
                ?? envelope.textPreview?.trimmingCharacters(in: .whitespacesAndNewlines)
                ?? "Watch thought"
            day.blocks.append(.init(
                id: envelope.captureID,
                dayID: day.id,
                kind: .voice,
                text: text,
                createdAt: envelope.createdAtUTC,
                updatedAt: now,
                ordinal: day.blocks.count
            ))
        case .audio:
            guard let audioURL else { throw ImportFailure.missingAudio }
            let mediaID = envelope.audioManifest?.audioAssetID ?? UUID()
            let destination = try Self.persistAudio(from: audioURL, mediaID: mediaID)
            day.media.append(.init(
                id: mediaID,
                dayID: day.id,
                kind: .audio,
                relativePath: destination.lastPathComponent,
                duration: envelope.audioManifest?.duration,
                createdAt: envelope.createdAtUTC,
                syncPolicy: .protectedLocalOnly
            ))
            day.blocks.append(.init(
                id: envelope.captureID,
                dayID: day.id,
                kind: .audio,
                text: envelope.text,
                mediaID: mediaID,
                createdAt: envelope.createdAtUTC,
                updatedAt: now,
                ordinal: day.blocks.count
            ))
        }
        day.updatedAt = now
        try await repository.saveJournalDay(day)
        try await saveReceipt(envelope: envelope, importedDayID: day.id)
        return WatchCaptureReceipt(
            captureID: envelope.captureID,
            importedEntryID: day.id,
            importedAtUTC: now,
            kind: envelope.kind
        )
    }

    private func existingReceipt(captureID: UUID) async throws -> UUID? {
        let context = container.newBackgroundContext()
        return try await context.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: "WatchImportReceipt")
            request.predicate = NSPredicate(format: "captureID == %@", captureID.uuidString)
            request.fetchLimit = 1
            return try context.fetch(request).first?.value(forKey: "importedDayID") as? UUID
        }
    }

    private func saveReceipt(envelope: WatchCaptureEnvelope, importedDayID: UUID) async throws {
        let encoded = try JSONEncoder.watchCapture.encode(envelope)
        let hash = SHA256.hash(data: encoded).map { String(format: "%02x", $0) }.joined()
        let context = container.newBackgroundContext()
        try await context.perform {
            let object = NSEntityDescription.insertNewObject(forEntityName: "WatchImportReceipt", into: context)
            object.setValue(UUID(), forKey: "id")
            object.setValue(envelope.captureID.uuidString, forKey: "captureID")
            object.setValue(hash, forKey: "importHash")
            object.setValue(importedDayID, forKey: "importedDayID")
            object.setValue(Date(), forKey: "importedAt")
            try context.save()
        }
    }

    private static func persistAudio(from source: URL, mediaID: UUID) throws -> URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = support.appendingPathComponent("LifeBoardJournalAudio", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.complete]
        )
        let destination = directory.appendingPathComponent(mediaID.uuidString).appendingPathExtension("m4a")
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.copyItem(at: source, to: destination)
        try FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.complete],
            ofItemAtPath: destination.path
        )
        return destination
    }
}

/// Single owner of WCSession for task snapshots, journal capture, fasting,
/// wellness and future receipt traffic. This prevents delegate replacement
/// from silently dropping transfers.
final class LifeBoardWatchConnectivityCoordinator: NSObject, WCSessionDelegate, @unchecked Sendable {
    static let shared = LifeBoardWatchConnectivityCoordinator()

    private var pendingTransfers: [String: Data] = [:]
    private var pendingAudioEnvelopes: [UUID: WatchCaptureEnvelope] = [:]
    private let lock = NSLock()
    private var importer: LifeBoardWatchCaptureImporter?
    private let recoveryStore = LifeBoardWatchCaptureRecoveryStore()

    private override init() { super.init() }

    func configure(repository: any LifeBoardPhaseIIRepository, container: NSPersistentContainer) {
        lock.lock()
        importer = LifeBoardWatchCaptureImporter(repository: repository, container: container)
        lock.unlock()
        activate()
        Task { await restorePendingCaptures() }
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        if session.activationState == .notActivated { session.activate() }
    }

    func sendTaskListSnapshot(_ snapshot: TaskListWidgetSnapshot) {
        send(snapshot, fileName: AppGroupConstants.taskListSnapshotFileName)
    }

    func sendGamificationSnapshot(_ snapshot: GamificationWidgetSnapshot) {
        send(snapshot, fileName: AppGroupConstants.snapshotFileName)
    }

    func journalRecoveryRecords() async -> [WatchCaptureRecoveryRecord] {
        await recoveryStore.all().sorted { $0.receivedAtUTC > $1.receivedAtUTC }
    }

    func retryJournalRecovery() async {
        await restorePendingCaptures()
    }

    func discardJournalRecoveryRecord(id: UUID) async {
        await recoveryStore.remove(id: id)
        NotificationCenter.default.post(name: .lifeboardJournalWatchCaptureNeedsAttention, object: nil)
    }

    private func send<T: Encodable>(_ value: T, fileName: String) {
        guard let data = try? JSONEncoder().encode(value), WCSession.isSupported() else { return }
        let session = WCSession.default
        activate()
        guard session.activationState == .activated else {
            lock.lock(); pendingTransfers[fileName] = data; lock.unlock()
            return
        }
        transfer(data: data, fileName: fileName, session: session)
    }

    private func transfer(data: Data, fileName: String, session: WCSession) {
        guard session.isPaired, session.isWatchAppInstalled else { return }
        do {
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(fileName)
            try data.write(to: url, options: .atomic)
            session.transferFile(url, metadata: ["snapshotFileName": fileName])
        } catch {
            logDebug("WATCH_SYNC transfer_failed file=\(fileName)")
        }
    }

    private func accept(_ envelope: WatchCaptureEnvelope, audioURL: URL? = nil) {
        lock.lock(); let importer = importer; lock.unlock()
        guard let importer else { return }
        Task {
            do {
                let receipt = try await importer.importCapture(envelope, audioURL: audioURL)
                await self.recoveryStore.remove(captureID: envelope.captureID)
                self.removePendingAudioEnvelope(captureID: envelope.captureID)
                WCSession.default.transferUserInfo(try receipt.userInfoPayload(namespace: .lifeBoard))
                NotificationCenter.default.post(name: .lifeboardJournalWatchCaptureImported, object: receipt)
            } catch LifeBoardWatchCaptureImporter.ImportFailure.missingAudio {
                self.storePendingAudioEnvelope(envelope)
                await self.recoveryStore.upsert(.init(reason: .awaitingAudio, envelope: envelope))
                NotificationCenter.default.post(name: .lifeboardJournalWatchCaptureNeedsAttention, object: envelope.captureID)
            } catch LifeBoardWatchCaptureImporter.ImportFailure.unsupportedEnvelope {
                let payload = try? JSONEncoder.watchCapture.encode(envelope)
                await self.recoveryStore.upsert(.init(
                    reason: .unsupportedSchema,
                    envelope: envelope,
                    protectedPayload: payload
                ))
                NotificationCenter.default.post(name: .lifeboardJournalWatchCaptureNeedsAttention, object: envelope.captureID)
            } catch {
                await self.recoveryStore.upsert(.init(reason: .persistenceUnavailable, envelope: envelope))
                logDebug("WATCH_CAPTURE import_failed capture=\(envelope.captureID.uuidString)")
                NotificationCenter.default.post(name: .lifeboardJournalWatchCaptureNeedsAttention, object: envelope.captureID)
            }
        }
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        do {
            let envelope = try WatchCaptureEnvelope.decoded(
                from: userInfo,
                namespace: .lifeBoard,
                acceptingLegacyNamespaces: []
            )
            accept(envelope)
        } catch {
            quarantineMalformedPayload(userInfo[WatchCaptureTransportNamespace.lifeBoard.capturePayloadKey] as? Data)
        }
    }

    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        let metadata = file.metadata ?? [:]
        var envelope = try? WatchCaptureEnvelope.decoded(
            from: metadata,
            namespace: .lifeBoard,
            acceptingLegacyNamespaces: []
        )
        if envelope == nil,
           let captureIDText = metadata[WatchCaptureTransportNamespace.lifeBoard.captureIDKey] as? String,
           let captureID = UUID(uuidString: captureIDText) {
            lock.lock(); envelope = pendingAudioEnvelopes.removeValue(forKey: captureID); lock.unlock()
        }
        guard let envelope else {
            quarantineMalformedPayload(metadata[WatchCaptureTransportNamespace.lifeBoard.capturePayloadKey] as? Data)
            return
        }
        accept(envelope, audioURL: file.fileURL)
    }

    private func storePendingAudioEnvelope(_ envelope: WatchCaptureEnvelope) {
        lock.lock()
        pendingAudioEnvelopes[envelope.captureID] = envelope
        lock.unlock()
    }

    private func removePendingAudioEnvelope(captureID: UUID) {
        lock.lock()
        pendingAudioEnvelopes.removeValue(forKey: captureID)
        lock.unlock()
    }

    private func quarantineMalformedPayload(_ payload: Data?) {
        Task {
            await recoveryStore.upsert(.init(reason: .malformedPayload, protectedPayload: payload))
            NotificationCenter.default.post(name: .lifeboardJournalWatchCaptureNeedsAttention, object: nil)
        }
    }

    private func restorePendingCaptures() async {
        let records = await recoveryStore.all()
        for record in records where record.isRetryable {
            guard let envelope = record.envelope else { continue }
            if envelope.kind == .audio {
                storePendingAudioEnvelope(envelope)
            } else {
                accept(envelope)
            }
        }
    }

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        guard activationState == .activated else { return }
        lock.lock(); let pending = pendingTransfers; pendingTransfers.removeAll(); lock.unlock()
        for (fileName, data) in pending { transfer(data: data, fileName: fileName, session: session) }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }
}

typealias WatchWidgetSnapshotSync = LifeBoardWatchConnectivityCoordinator

extension Notification.Name {
    static let lifeboardJournalWatchCaptureImported = Notification.Name("LifeBoardJournalWatchCaptureImported")
    static let lifeboardJournalWatchCaptureNeedsAttention = Notification.Name("LifeBoardJournalWatchCaptureNeedsAttention")
}
#endif
