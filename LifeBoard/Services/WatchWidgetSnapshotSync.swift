import Foundation

#if canImport(WatchConnectivity) && os(iOS)
import WatchConnectivity

final class WatchWidgetSnapshotSync: NSObject, WCSessionDelegate, @unchecked Sendable {
    static let shared = WatchWidgetSnapshotSync()

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
        let session = WCSession.default
        activate()
        guard session.activationState == .activated else {
            logDebug("WATCH_WIDGET_SYNC transfer_skipped file=\(fileName) reason=session_activating")
            return
        }
        guard session.isPaired, session.isWatchAppInstalled else {
            logDebug("WATCH_WIDGET_SYNC transfer_skipped file=\(fileName) reason=counterpart_unavailable")
            return
        }
        guard let data = try? JSONEncoder().encode(value) else { return }

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

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {}

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
}
#endif
