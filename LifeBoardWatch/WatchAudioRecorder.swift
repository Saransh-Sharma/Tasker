import AVFoundation
import Foundation
import WatchKit

@MainActor
final class WatchAudioRecorder: NSObject, ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var level: Float = 0
    @Published var errorMessage: String?

    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    static let hardLimit: TimeInterval = 10 * 60

    func start() {
        guard !isRecording else { return }
        errorMessage = nil
        AVAudioApplication.requestRecordPermission { [weak self] allowed in
            Task { @MainActor in
                guard let self else { return }
                guard allowed else {
                    self.errorMessage = "Microphone access is off"
                    WatchHaptics.warning()
                    return
                }
                do { try self.beginRecording() }
                catch {
                    self.errorMessage = "Recording couldn’t start"
                    WatchHaptics.failure()
                }
            }
        }
    }

    func stop() -> (url: URL, duration: TimeInterval)? {
        guard let recorder else { return nil }
        let result = (recorder.url, recorder.currentTime)
        recorder.stop()
        self.recorder = nil
        timer?.invalidate()
        timer = nil
        isRecording = false
        duration = result.1
        level = 0
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        WatchHaptics.stop()
        return result
    }

    func cancel() {
        guard let recorder else { return }
        let url = recorder.url
        recorder.stop()
        self.recorder = nil
        timer?.invalidate()
        timer = nil
        isRecording = false
        duration = 0
        level = 0
        try? FileManager.default.removeItem(at: url)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func beginRecording() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .spokenAudio)
        try session.setActive(true)
        let url = Self.recordingsDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 24_000,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 64_000,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]
        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.isMeteringEnabled = true
        guard recorder.record() else { throw CocoaError(.fileWriteUnknown) }
        self.recorder = recorder
        isRecording = true
        duration = 0
        WatchHaptics.start()
        timer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let recorder = self.recorder else { return }
                recorder.updateMeters()
                self.duration = recorder.currentTime
                self.level = max(0, min(1, (recorder.averagePower(forChannel: 0) + 60) / 60))
                if recorder.currentTime >= Self.hardLimit { _ = self.stop() }
            }
        }
    }

    static let recordingsDirectory: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = base.appendingPathComponent("WatchJournalRecordings", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.complete]
        )
        return directory
    }()
}

enum WatchHaptics {
    static func selection() { WKInterfaceDevice.current().play(.click) }
    static func start() { WKInterfaceDevice.current().play(.start) }
    static func stop() { WKInterfaceDevice.current().play(.stop) }
    static func success() { WKInterfaceDevice.current().play(.success) }
    static func warning() { WKInterfaceDevice.current().play(.retry) }
    static func failure() { WKInterfaceDevice.current().play(.failure) }
}
