import AVFAudio
import CryptoKit
import Foundation
import Observation

struct EvaPlaybackCompletionTracker: Equatable {
    private(set) var pendingBufferCount = 0
    private(set) var streamFinished = false

    mutating func scheduledBuffer() {
        pendingBufferCount += 1
    }

    mutating func finishedScheduling() -> Bool {
        streamFinished = true
        return pendingBufferCount == 0
    }

    mutating func completedBuffer() -> Bool {
        guard pendingBufferCount > 0 else { return false }
        pendingBufferCount -= 1
        return streamFinished && pendingBufferCount == 0
    }

    mutating func reset() {
        pendingBufferCount = 0
        streamFinished = false
    }
}

@MainActor
final class EvaAudioSessionArbiter {
    static let shared = EvaAudioSessionArbiter()

    private init() {}

    func beginSpokenOutput() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try session.setActive(true)
    }

    func endSpokenOutput() {
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }
}

@MainActor
@Observable
final class EvaSpokenOutputController {
    static let shared = EvaSpokenOutputController()

    enum State: Equatable {
        case idle
        case loading
        case playing
        case paused
        case failed(String)
    }

    private(set) var state: State = .idle
    private(set) var disclosure = String(localized: "AI-generated voice")
    private(set) var activeText: String?
    private(set) var requiresPaidRegeneration = false

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 24_000, channels: 1, interleaved: true)!
    private var streamTask: Task<Void, Never>?
    private var pendingByte: UInt8?
    private var completionTracker = EvaPlaybackCompletionTracker()
    private var interruptionObserver: NSObjectProtocol?
    private var routeObserver: NSObjectProtocol?

    private init() {
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            MainActor.assumeIsolated { self?.handleInterruption(rawType: rawType) }
        }
        routeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let rawReason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            MainActor.assumeIsolated { self?.handleRouteChange(rawReason: rawReason) }
        }
    }

    func play(text: String, allowPaidRegeneration: Bool = false) {
        stop()
        guard EvaCloudAccountState.shared.configuration?.ttsEnabled == true else {
            state = .failed(String(localized: "Spoken output is not available right now."))
            return
        }
        activeText = text
        requiresPaidRegeneration = false
        state = .loading
        streamTask = Task { [weak self] in
            guard let self else { return }
            do {
                if let cached = try await EvaSpeechCache.shared.data(for: text) {
                    try beginPlayback()
                    schedule(cached)
                    state = .playing
                    finishScheduling()
                    return
                }
                guard let ticket = await EvaSpeechTicketRegistry.shared.ticket(for: text) else {
                    throw EvaProviderError.unavailable(String(localized: "Spoken output is no longer cached. Generate it again from the answer menu."))
                }
                let stream = try await EvaCloudTransport.shared.speech(
                    requestId: ticket.requestId,
                    ticket: ticket.token,
                    text: text,
                    allowPaidRegeneration: allowPaidRegeneration
                )
                try beginPlayback()
                var cacheData = Data()
                for try await chunk in stream {
                    try Task.checkCancellation()
                    cacheData.append(chunk)
                    schedule(chunk)
                    if state == .loading { state = .playing }
                }
                try await EvaSpeechCache.shared.store(cacheData, for: text)
                finishScheduling()
            } catch is CancellationError {
                state = .idle
                EvaAudioSessionArbiter.shared.endSpokenOutput()
            } catch {
                if let envelope = error as? EvaErrorEnvelope,
                   envelope.code == "insufficient_credits" {
                    requiresPaidRegeneration = true
                }
                state = .failed(error.localizedDescription)
                EvaAudioSessionArbiter.shared.endSpokenOutput()
            }
        }
    }

    func pause() {
        guard player.isPlaying else { return }
        player.pause()
        state = .paused
    }

    func resume() {
        guard state == .paused else { return }
        player.play()
        state = .playing
    }

    func stop() {
        streamTask?.cancel()
        streamTask = nil
        player.stop()
        engine.stop()
        pendingByte = nil
        completionTracker.reset()
        requiresPaidRegeneration = false
        state = .idle
        EvaAudioSessionArbiter.shared.endSpokenOutput()
    }

    func replay() {
        guard let activeText else { return }
        play(text: activeText)
    }

    func stopForRecording() {
        stop()
    }

    func deleteCachedSpeech(for text: String) async {
        try? await EvaSpeechCache.shared.remove(text: text)
        await EvaSpeechTicketRegistry.shared.remove(text: text)
    }

    private func beginPlayback() throws {
        try EvaAudioSessionArbiter.shared.beginSpokenOutput()
        if !engine.isRunning { try engine.start() }
        if !player.isPlaying { player.play() }
    }

    private func schedule(_ incoming: Data) {
        var data = Data()
        if let pendingByte {
            data.append(pendingByte)
            self.pendingByte = nil
        }
        data.append(incoming)
        if data.count % 2 != 0 {
            pendingByte = data.removeLast()
        }
        guard !data.isEmpty else { return }
        let frames = AVAudioFrameCount(data.count / 2)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { return }
        buffer.frameLength = frames
        data.withUnsafeBytes { bytes in
            guard let source = bytes.baseAddress,
                  let destination = buffer.mutableAudioBufferList.pointee.mBuffers.mData else { return }
            destination.copyMemory(from: source, byteCount: data.count)
        }
        completionTracker.scheduledBuffer()
        player.scheduleBuffer(buffer, completionCallbackType: .dataPlayedBack) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.bufferDidFinishPlaying()
            }
        }
    }

    private func finishScheduling() {
        if completionTracker.finishedScheduling() { finishPlayback() }
    }

    private func bufferDidFinishPlaying() {
        if completionTracker.completedBuffer() { finishPlayback() }
    }

    private func finishPlayback() {
        player.stop()
        engine.stop()
        pendingByte = nil
        completionTracker.reset()
        streamTask = nil
        state = .idle
        EvaAudioSessionArbiter.shared.endSpokenOutput()
    }

    private func handleInterruption(rawType: UInt?) {
        guard let rawType,
              let type = AVAudioSession.InterruptionType(rawValue: rawType) else { return }
        if type == .began { pause() }
    }

    private func handleRouteChange(rawReason: UInt?) {
        guard let rawReason,
              AVAudioSession.RouteChangeReason(rawValue: rawReason) == .oldDeviceUnavailable else { return }
        pause()
    }
}

actor EvaSpeechCache {
    static let shared = EvaSpeechCache()

    private struct Metadata: Codable {
        var lastAccessedAt: Date
        let createdAt: Date
        let byteCount: Int
    }

    private let maximumBytes = 100 * 1024 * 1024
    private let lifetime: TimeInterval = 30 * 24 * 60 * 60

    func data(for text: String) async throws -> Data? {
        let key = Self.key(text)
        let audioURL = try directory().appending(path: "\(key).pcm")
        let metadataURL = try directory().appending(path: "\(key).json")
        guard let metadataData = try? Data(contentsOf: metadataURL),
              var metadata = try? JSONDecoder.evaCloud.decode(Metadata.self, from: metadataData),
              Date().timeIntervalSince(metadata.createdAt) <= lifetime,
              let audio = try? Data(contentsOf: audioURL) else {
            try? FileManager.default.removeItem(at: audioURL)
            try? FileManager.default.removeItem(at: metadataURL)
            await EvaSpeechTicketRegistry.shared.remove(textHash: key)
            return nil
        }
        metadata.lastAccessedAt = Date()
        try? JSONEncoder.evaCloud.encode(metadata).write(to: metadataURL, options: [.atomic, .completeFileProtection])
        return audio
    }

    func store(_ data: Data, for text: String) async throws {
        guard !data.isEmpty else { return }
        let base = try directory()
        try FileManager.default.createDirectory(
            at: base,
            withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.complete]
        )
        let key = Self.key(text)
        try data.write(to: base.appending(path: "\(key).pcm"), options: [.atomic, .completeFileProtection])
        let metadata = Metadata(lastAccessedAt: Date(), createdAt: Date(), byteCount: data.count)
        try JSONEncoder.evaCloud.encode(metadata).write(
            to: base.appending(path: "\(key).json"),
            options: [.atomic, .completeFileProtection]
        )
        try await evictIfNeeded()
    }

    func remove(text: String) throws {
        let key = Self.key(text)
        try? FileManager.default.removeItem(at: directory().appending(path: "\(key).pcm"))
        try? FileManager.default.removeItem(at: directory().appending(path: "\(key).json"))
    }

    private func evictIfNeeded() async throws {
        let base = try directory()
        let files = try FileManager.default.contentsOfDirectory(at: base, includingPropertiesForKeys: nil)
        var records: [(key: String, metadata: Metadata)] = []
        for metadataURL in files where metadataURL.pathExtension == "json" {
            guard let data = try? Data(contentsOf: metadataURL),
                  let metadata = try? JSONDecoder.evaCloud.decode(Metadata.self, from: data) else { continue }
            records.append((metadataURL.deletingPathExtension().lastPathComponent, metadata))
        }
        var total = records.reduce(0) { $0 + $1.metadata.byteCount }
        for record in records.sorted(by: { $0.metadata.lastAccessedAt < $1.metadata.lastAccessedAt }) where total > maximumBytes {
            try? FileManager.default.removeItem(at: base.appending(path: "\(record.key).pcm"))
            try? FileManager.default.removeItem(at: base.appending(path: "\(record.key).json"))
            await EvaSpeechTicketRegistry.shared.remove(textHash: record.key)
            total -= record.metadata.byteCount
        }
    }

    private func directory() throws -> URL {
        try FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appending(path: "EVACloudSpeech", directoryHint: .isDirectory)
    }

    private static func key(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
