import AVFoundation
import Foundation
import Observation

@MainActor
@Observable
final class JournalAudioRecorder: NSObject, AVAudioRecorderDelegate {
    private(set) var isRecording = false
    private(set) var duration: TimeInterval = 0
    private(set) var errorMessage: String?
    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private var startedAt: Date?

    func start() async {
        EvaSpokenOutputController.shared.stopForRecording()
        let permitted = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { continuation.resume(returning: $0) }
        }
        await MainActor.run { PermissionPromptState.recordRequested(.microphone) }
        guard permitted else {
            errorMessage = "Microphone is off. Turn it on in Settings to record."
            return
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true)
            let url = try JournalAudioFiles.newRecordingURL()
            let recorder = try AVAudioRecorder(url: url, settings: [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ])
            recorder.delegate = self
            recorder.record()
            self.recorder = recorder
            startedAt = Date()
            isRecording = true
            timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.duration = Date().timeIntervalSince(self?.startedAt ?? Date()) }
            }
        } catch { errorMessage = error.localizedDescription }
    }

    func stop() -> (url: URL, duration: TimeInterval)? {
        guard let recorder else { return nil }
        recorder.stop()
        timer?.invalidate()
        timer = nil
        isRecording = false
        duration = recorder.currentTime
        self.recorder = nil
        try? FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.complete],
            ofItemAtPath: recorder.url.path
        )
        try? AVAudioSession.sharedInstance().setActive(false)
        return (recorder.url, duration)
    }

    func cancel() {
        let url = recorder?.url
        recorder?.stop()
        timer?.invalidate()
        recorder = nil
        isRecording = false
        if let url { try? FileManager.default.removeItem(at: url) }
    }
}
