import Foundation
import WidgetKit

#if canImport(WatchConnectivity)
import WatchConnectivity

final class WatchSnapshotReceiver: NSObject, ObservableObject, WCSessionDelegate {
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

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {}

    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        guard let fileName = file.metadata?["snapshotFileName"] as? String else { return }
        copySnapshot(from: file.fileURL, fileName: fileName)
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
        } catch {
            // Snapshot transfer failures fall back to the extension's stale/default state.
        }
    }

    private func destinationURL(for fileName: String) -> URL? {
        switch fileName {
        case AppGroupConstants.taskListSnapshotFileName:
            return AppGroupConstants.taskListSnapshotURL
        case AppGroupConstants.snapshotFileName:
            return AppGroupConstants.snapshotURL
        default:
            return nil
        }
    }
}
#else
final class WatchSnapshotReceiver: ObservableObject {
    func activate() {}
}
#endif
