import Foundation
import WatchCaptureKit

@MainActor
final class WatchJournalCaptureStore: ObservableObject {
    static let shared = WatchJournalCaptureStore()

    @Published private(set) var outbox: [WatchRecentCapture] = []
    @Published var showPrivatePreviews: Bool {
        didSet { UserDefaults.standard.set(showPrivatePreviews, forKey: Self.previewKey) }
    }

    private let connectivity = WatchSnapshotReceiver.shared
    private static let previewKey = "lifeboard.watch.showPrivateJournalPreviews"
    private static let syncedRetention = 20
    private static let totalRetention = 200

    private init() {
        showPrivatePreviews = UserDefaults.standard.bool(forKey: Self.previewKey)
        outbox = Self.load(from: Self.storeURL)
        normalizeAndPersist()
        connectivity.onReceipt = { [weak self] receipt in self?.markSynced(receipt) }
    }

    var recent: [WatchRecentCapture] {
        WatchCaptureQueuePolicy.recentProjection(from: outbox)
    }

    var pendingCount: Int { outbox.filter { $0.syncState != .synced }.count }

    var syncSummary: String {
        if pendingCount == 0 { return "Everything is on iPhone" }
        return connectivity.isReachable
            ? "\(pendingCount) sending to iPhone"
            : "\(pendingCount) safe on this Watch"
    }

    func start() {
        connectivity.activate()
        retryPending()
    }

    func saveMood(_ mood: WatchJournalMood) {
        enqueue(.init(
            kind: .mood,
            sourceSurface: .app,
            moodValue: mood.rawValue,
            textPreview: mood.title
        ))
        WatchHaptics.success()
    }

    func saveText(_ text: String) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        enqueue(.init(
            kind: .speak,
            sourceSurface: .app,
            text: String(clean.prefix(2_000)),
            textPreview: String(clean.prefix(64)),
            speechTruthState: .transcriptOnWatchNow
        ))
        WatchHaptics.success()
    }

    func saveAudio(fileURL: URL, duration: TimeInterval) {
        let captureID = UUID()
        let byteCount = ((try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size]) as? NSNumber)?.int64Value ?? 0
        let manifest = WatchAudioManifest(
            captureID: captureID,
            fileName: fileURL.lastPathComponent,
            duration: duration,
            byteCount: byteCount
        )
        enqueue(.init(
            captureID: captureID,
            kind: .audio,
            sourceSurface: .app,
            textPreview: "Voice moment",
            speechTruthState: .transcriptOnIPhoneLater,
            audioManifest: manifest
        ))
        WatchHaptics.success()
    }

    func retry(_ captureID: UUID) {
        guard let item = outbox.first(where: { $0.id == captureID }) else { return }
        send(item, force: true)
    }

    func retryPending() {
        let now = Date()
        for item in outbox where WatchCaptureQueuePolicy.shouldAttemptTransfer(item, now: now) {
            send(item)
        }
    }

    func preview(for item: WatchRecentCapture) -> String {
        guard showPrivatePreviews else {
            switch item.envelope.kind {
            case .mood: return item.envelope.moodValue.flatMap(WatchJournalMood.init(rawValue:))?.title ?? "Mood"
            case .speak: return "Private thought"
            case .audio: return "Private recording"
            }
        }
        return item.envelope.privacySafePreview
    }

    private func enqueue(_ envelope: WatchCaptureEnvelope) {
        let item = WatchRecentCapture(
            envelope: envelope,
            syncState: .queued,
            transferKind: envelope.kind == .audio ? .audioFile : .metadata,
            updatedAtUTC: Date()
        )
        outbox.removeAll { $0.id == item.id }
        outbox.insert(item, at: 0)
        normalizeAndPersist()
        send(item, force: true)
    }

    private func send(_ item: WatchRecentCapture, force: Bool = false) {
        if !force, !WatchCaptureQueuePolicy.shouldAttemptTransfer(item, now: Date()) { return }
        markAttempt(item.id)
        do {
            if item.envelope.kind == .audio {
                guard let fileURL = audioURL(for: item.envelope),
                      FileManager.default.fileExists(atPath: fileURL.path) else {
                    markFailed(item.id, message: "Recording is unavailable", isPermanent: true)
                    return
                }
                try connectivity.transferAudio(fileURL: fileURL, envelope: item.envelope)
            } else {
                try connectivity.transfer(item.envelope)
            }
        } catch {
            markFailed(item.id, message: "Couldn’t send yet", isPermanent: false)
        }
    }

    private func markAttempt(_ captureID: UUID) {
        guard let index = outbox.firstIndex(where: { $0.id == captureID }) else { return }
        let now = Date()
        outbox[index].syncState = .sending
        outbox[index].attemptCount += 1
        outbox[index].lastAttemptAtUTC = now
        outbox[index].nextAttemptAtUTC = now.addingTimeInterval(
            WatchCaptureQueuePolicy.backoffDelay(forAttempt: outbox[index].attemptCount)
        )
        outbox[index].lastError = nil
        outbox[index].updatedAtUTC = now
        persist()
    }

    private func markFailed(_ captureID: UUID, message: String, isPermanent: Bool) {
        guard let index = outbox.firstIndex(where: { $0.id == captureID }) else { return }
        outbox[index].syncState = .failed
        outbox[index].lastError = message
        outbox[index].audioFileMissing = isPermanent
        outbox[index].nextAttemptAtUTC = isPermanent ? nil : Date().addingTimeInterval(
            WatchCaptureQueuePolicy.backoffDelay(forAttempt: outbox[index].attemptCount)
        )
        outbox[index].updatedAtUTC = Date()
        persist()
    }

    private func markSynced(_ receipt: WatchCaptureReceipt) {
        guard let index = outbox.firstIndex(where: { $0.id == receipt.captureID }) else { return }
        if outbox[index].envelope.kind == .audio,
           let fileURL = audioURL(for: outbox[index].envelope) {
            try? FileManager.default.removeItem(at: fileURL)
        }
        outbox[index].syncState = .synced
        outbox[index].nextAttemptAtUTC = nil
        outbox[index].lastError = nil
        outbox[index].audioFileMissing = false
        outbox[index].updatedAtUTC = Date()
        normalizeAndPersist()
    }

    private func audioURL(for envelope: WatchCaptureEnvelope) -> URL? {
        guard let fileName = envelope.audioManifest?.fileName else { return nil }
        return WatchAudioRecorder.recordingsDirectory.appendingPathComponent(fileName)
    }

    private func normalizeAndPersist() {
        outbox.sort { $0.updatedAtUTC > $1.updatedAtUTC }
        var retainedSynced = 0
        outbox.removeAll { item in
            guard item.syncState == .synced else { return false }
            retainedSynced += 1
            return retainedSynced > Self.syncedRetention
        }
        if outbox.count > Self.totalRetention {
            let pending = outbox.filter { $0.syncState != .synced }
            let synced = outbox.filter { $0.syncState == .synced }
            outbox = Array((pending + synced).prefix(max(Self.totalRetention, pending.count)))
        }
        persist()
    }

    private func persist() {
        do {
            let data = try JSONEncoder.watchCapture.encode(outbox)
            try data.write(to: Self.storeURL, options: [.atomic, .completeFileProtection])
        } catch { }
    }

    private static func load(from url: URL) -> [WatchRecentCapture] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder.watchCapture.decode([WatchRecentCapture].self, from: data)) ?? []
    }

    private static let storeURL: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = base.appendingPathComponent("WatchJournal", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.complete]
        )
        return directory.appendingPathComponent("outbox.json")
    }()
}
