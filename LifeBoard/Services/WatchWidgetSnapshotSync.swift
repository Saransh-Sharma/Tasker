import Foundation

#if canImport(WatchConnectivity) && os(iOS)
import WatchConnectivity

final class WatchWidgetSnapshotSync: NSObject, WCSessionDelegate, @unchecked Sendable {
    static let shared = WatchWidgetSnapshotSync()

    /// Snapshots encoded before the WCSession finished activating, keyed by file
    /// name so only the most recent snapshot per file is retried (latest wins).
    private var pendingTransfers: [String: Data] = [:]
    private let pendingLock = NSLock()

    private override init() {
        super.init()
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        if session.delegate !== self {
            session.delegate = self
        }
        if session.activationState == .notActivated {
            session.activate()
        }
    }

    func sendTaskListSnapshot(_ snapshot: TaskListWidgetSnapshot) {
        send(snapshot, fileName: AppGroupConstants.taskListSnapshotFileName)
    }

    func sendGamificationSnapshot(_ snapshot: GamificationWidgetSnapshot) {
        send(snapshot, fileName: AppGroupConstants.snapshotFileName)
    }

    private func send<T: Encodable>(_ value: T, fileName: String) {
        guard WCSession.isSupported() else { return }
        guard let data = try? JSONEncoder().encode(value) else { return }
        let session = WCSession.default
        activate()
        guard session.activationState == .activated else {
            // Session is still activating; hold the latest snapshot and retry once
            // activation completes instead of dropping it permanently.
            pendingLock.lock()
            pendingTransfers[fileName] = data
            pendingLock.unlock()
            logDebug("WATCH_WIDGET_SYNC transfer_queued file=\(fileName) reason=session_activating")
            return
        }
        transfer(data: data, fileName: fileName, session: session)
    }

    private func transfer(data: Data, fileName: String, session: WCSession) {
        guard session.isPaired, session.isWatchAppInstalled else {
            logDebug("WATCH_WIDGET_SYNC transfer_skipped file=\(fileName) reason=counterpart_unavailable")
            return
        }

        do {
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(fileName)
            try data.write(to: url, options: .atomic)
            session.transferFile(url, metadata: ["snapshotFileName": fileName])
        } catch {
            logDebug("WATCH_WIDGET_SYNC transfer_failed file=\(fileName)")
        }
    }

    private func flushPendingTransfers(using session: WCSession) {
        pendingLock.lock()
        let pending = pendingTransfers
        pendingTransfers.removeAll()
        pendingLock.unlock()

        for (fileName, data) in pending {
            transfer(data: data, fileName: fileName, session: session)
        }
    }

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        guard activationState == .activated else { return }
        flushPendingTransfers(using: session)
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
}
#endif
