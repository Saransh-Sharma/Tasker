//
//  TranscriptionService.swift
//  TranscriptionKit
//
//  App-facing facade for transcribing saved audio recordings entirely through
//  SpeechAnalyzer. It bounds concurrency and applies an overall timeout so no
//  entry is left in .processing forever.
//
//  Jobs are isolated: starting a new transcription never cancels an
//  in-flight one (e.g. a Watch import arriving mid-recording).
//
//  Consent is injected: each host app supplies its own consent state
//  (OffRecord: SpeechTranscriptionConsent; LifeBoard: its consent store).
//

import Foundation
import os.log

public actor TranscriptionService {

    public typealias EngineFactory = @Sendable () async throws -> any TranscriptionEngine
    public typealias ConsentProvider = @Sendable () -> Bool

    private let limiter = AsyncJobLimiter(limit: 2)
    /// Generous ceiling covering long Watch recordings plus a first-use model download.
    private let jobTimeout: TimeInterval
    private let consentProvider: ConsentProvider
    private let engineFactory: EngineFactory

    #if os(iOS)
    /// Production initializer: routes to the best engine for this device.
    /// `consentProvider` gates every job; the host app owns the disclosure
    /// and persistence of that consent.
    public init(
        consentProvider: @escaping ConsentProvider,
        jobTimeout: TimeInterval = 600
    ) {
        self.jobTimeout = jobTimeout
        self.consentProvider = consentProvider
        self.engineFactory = { try await TranscriptionEngineRouter.makeEngine() }
    }
    #endif

    /// Testing/custom-routing initializer.
    init(
        jobTimeout: TimeInterval = 600,
        consentProvider: @escaping ConsentProvider = { true },
        engineFactory: @escaping EngineFactory
    ) {
        self.jobTimeout = jobTimeout
        self.consentProvider = consentProvider
        self.engineFactory = engineFactory
    }

    /// Transcribes the audio file at the given URL. Requires prior speech
    /// transcription consent; the recording itself is always saved by the
    /// caller before transcription starts.
    public func transcribe(from audioURL: URL) async throws -> FileTranscriptionResult {
        guard consentProvider() else {
            TranscriptionLog.speech.warning("Transcription blocked because Apple Speech consent is missing")
            throw TranscriptionError.appleSpeechConsentRequired
        }

        await limiter.acquire()
        do {
            let engine = try await engineFactory()
            let result = try await withTimeout(jobTimeout) {
                try await engine.transcribeFile(at: audioURL)
            }
            await limiter.release()
            return result
        } catch {
            await limiter.release()
            throw error
        }
    }

    /// Downloads the on-device speech model in the background so the first
    /// transcription doesn't wait on it. The caller is responsible for
    /// checking consent before invoking this.
    public static func prewarmPreferredModel() {
        #if os(iOS)
        if #available(iOS 26.0, *) {
            Task(priority: .utility) {
                await TranscriptionAssetManager.shared.prewarmPreferredModel()
            }
        }
        #endif
    }

    private func withTimeout<T: Sendable>(
        _ seconds: TimeInterval,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(for: .seconds(seconds))
                TranscriptionLog.speech.error("Transcription job timed out seconds=\(seconds, privacy: .public)")
                throw TranscriptionError.noFinalResult
            }
            guard let result = try await group.next() else {
                throw TranscriptionError.noFinalResult
            }
            group.cancelAll()
            return result
        }
    }
}

// MARK: - Concurrency limiter

/// Bounds the number of transcription jobs running at once so simultaneous
/// iPhone recordings and Watch imports don't compete for memory/power, while
/// still letting them all complete.
private actor AsyncJobLimiterState {
    private var available: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(limit: Int) {
        available = limit
    }

    func acquire() async {
        if available > 0 {
            available -= 1
            return
        }
        await withCheckedContinuation { waiters.append($0) }
    }

    func release() {
        if waiters.isEmpty {
            available += 1
        } else {
            waiters.removeFirst().resume()
        }
    }
}

private typealias AsyncJobLimiter = AsyncJobLimiterState
