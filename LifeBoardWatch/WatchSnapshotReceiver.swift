import Foundation
import WatchCaptureKit
import WidgetKit

#if canImport(WatchConnectivity)
@preconcurrency import WatchConnectivity

/// The only WCSession delegate in the Watch app. Snapshot delivery and private
/// Journal capture share this coordinator so neither feature replaces the
/// other's delegate during relaunch or background delivery.
@MainActor
final class WatchSnapshotReceiver: NSObject, ObservableObject {
    static let shared = WatchSnapshotReceiver()

    @Published private(set) var isReachable = false
    @Published private(set) var activationState: WCSessionActivationState = .notActivated
    var onReceipt: ((WatchCaptureReceipt) -> Void)?

    private override init() { super.init() }

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    func transfer(_ envelope: WatchCaptureEnvelope) throws {
        guard WCSession.isSupported() else { return }
        WCSession.default.transferUserInfo(
            try envelope.userInfoPayload(namespace: .lifeBoard)
        )
    }

    func transferAudio(fileURL: URL, envelope: WatchCaptureEnvelope) throws {
        guard WCSession.isSupported() else { return }
        WCSession.default.transferFile(
            fileURL,
            metadata: try envelope.userInfoPayload(namespace: .lifeBoard)
        )
    }

    private func copySnapshot(from sourceURL: URL, fileName: String) {
        guard let destinationURL = destinationURL(for: fileName) else { return }
        do {
            let data = try Data(contentsOf: sourceURL)
            try data.write(to: destinationURL, options: .atomic)
            if fileName == AppGroupConstants.taskListSnapshotFileName,
               let backupURL = AppGroupConstants.taskListSnapshotBackupURL {
                try? data.write(to: backupURL, options: .atomic)
            }
            WidgetCenter.shared.reloadAllTimelines()
            NotificationCenter.default.post(name: .lifeboardWatchSnapshotUpdated, object: nil)
        } catch {
            // Existing snapshots remain visible and are clearly marked stale.
        }
    }

    private func destinationURL(for fileName: String) -> URL? {
        switch fileName {
        case AppGroupConstants.taskListSnapshotFileName: AppGroupConstants.taskListSnapshotURL
        case AppGroupConstants.snapshotFileName: AppGroupConstants.snapshotURL
        default: nil
        }
    }
}

extension WatchSnapshotReceiver: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        let reachable = session.isReachable
        Task { @MainActor in
            self.activationState = activationState
            self.isReachable = reachable
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        Task { @MainActor in self.isReachable = reachable }
    }

    nonisolated func session(_ session: WCSession, didReceive file: WCSessionFile) {
        guard let fileName = file.metadata?["snapshotFileName"] as? String else { return }
        let temporaryCopy = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        do {
            try FileManager.default.copyItem(at: file.fileURL, to: temporaryCopy)
            Task { @MainActor in
                self.copySnapshot(from: temporaryCopy, fileName: fileName)
                try? FileManager.default.removeItem(at: temporaryCopy)
            }
        } catch { }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let receipt = try? WatchCaptureReceipt.decoded(
            from: userInfo,
            namespace: .lifeBoard,
            acceptingLegacyNamespaces: []
        ) else { return }
        Task { @MainActor in self.onReceipt?(receipt) }
    }
}
#else
@MainActor
final class WatchSnapshotReceiver: ObservableObject {
    static let shared = WatchSnapshotReceiver()
    @Published private(set) var isReachable = false
    var onReceipt: ((WatchCaptureReceipt) -> Void)?
    func activate() {}
    func transfer(_ envelope: WatchCaptureEnvelope) throws {}
    func transferAudio(fileURL: URL, envelope: WatchCaptureEnvelope) throws {}
}
#endif

extension Notification.Name {
    static let lifeboardWatchSnapshotUpdated = Notification.Name("LifeBoardWatchSnapshotUpdated")
}
