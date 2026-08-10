//
//  UniversalDictationController.swift
//  LifeBoard
//
//  Reusable microphone-to-SpeechAnalyzer streaming controller for the
//  universal input composer and the EVA structured composer.
//
//  Wraps `LiveTranscriptionSession` (TranscriptionKit, iOS 26) behind a
//  `LiveTranscriptionSessionProviding` protocol so the shell and chat
//  composer can share one implementation without coupling either surface
//  to the concrete type.
//

import Foundation
import Observation
#if canImport(LifeBoardTranscription)
import LifeBoardTranscription
#endif
#if canImport(AVFoundation)
import AVFoundation
#endif

#if canImport(LifeBoardTranscription)
/// Provider seam around `LiveTranscriptionSession` so app-facing code is
/// isolated from the concrete package type.
@MainActor
public protocol LiveTranscriptionSessionProviding: AnyObject {
    var events: AsyncStream<LiveTranscriptionEvent> { get }
    func start() async throws
    func stop() async throws
    func cancel() async
}

/// Default factory that vends the real `LiveTranscriptionSession` on
/// iOS 26+. Availability failures are surfaced as controller recovery.
@MainActor
public struct LiveTranscriptionSessionFactory {
    public init() {}

    @available(iOS 26.0, *)
    public static func makeSession(preferredLocale: Locale = .current) async throws -> LiveTranscriptionSessionProviding {
        let session = try await LiveTranscriptionSession.prepare(preferredLocale: preferredLocale)
        return RealLiveTranscriptionSession(session: session)
    }
}

@available(iOS 26.0, *)
@MainActor
final class RealLiveTranscriptionSession: LiveTranscriptionSessionProviding {
    private let session: LiveTranscriptionSession
    init(session: LiveTranscriptionSession) { self.session = session }
    var events: AsyncStream<LiveTranscriptionEvent> { session.events }
    func start() async throws { try await session.start() }
    func stop() async throws { try await session.stop() }
    func cancel() async { await session.cancel() }
}
#endif

/// Lifecycle phase of the dictation controller. Only the error phases are
/// terminal without an explicit `cancel()`/`stop()`/`start()` call.
public enum UniversalDictationPhase: String, Sendable, Equatable {
    case idle
    case preparing
    case recording
    case finalizing
    /// Microphone permission was denied, or the user previously denied mic
    /// access. Caller surfaces the existing "Open Settings" affordance.
    case denied
    /// SpeechAnalyzer has no installed/on-device model for the requested
    /// locale. Recovery is app-level guidance, not a retry.
    case unsupportedLocale
    /// The on-device model could not be installed/finalized.
    case assetInstallFailed
    /// A transient failure from the analyzer or audio engine.
    case failed
}

/// Privacy-safe recovery surface. Carries enough to render distinct copy
/// but never transcript content (per plan §safety/privacy).
public struct UniversalDictationRecovery: Sendable, Equatable {
    public let phase: UniversalDictationPhase
    public let message: String
    public init(phase: UniversalDictationPhase, message: String) {
        self.phase = phase
        self.message = message
    }
}

/// Reusable microphone-to-SpeechAnalyzer streaming controller shared by
/// the universal input shell composer and the EVA structured composer.
///
/// Responsibilities:
/// - Preserve any text already present in the composer when recording
///   begins (so typing and dictation merge safely).
/// - Treat the cumulative live transcript as volatile until stop. The
///   package event does not expose SpeechAnalyzer's finalized range, so
///   committing earlier would risk either duplication or transcript loss.
/// - Surface distinct error/recovery phases (denied, unsupported locale,
///   asset install failed, transient failure) without leaking transcript
///   content.
@MainActor
@Observable
public final class UniversalDictationController {

    /// Combined composer text while dictating: `{preexistingPrefix} {finalized} {volatile}`.
    public private(set) var draftText: String = ""
    /// True only of the trailing volatile segment of `draftText`.
    public private(set) var volatileSegment: String = ""
    public private(set) var isRecording: Bool = false
    public private(set) var phase: UniversalDictationPhase = .idle
    public private(set) var recovery: UniversalDictationRecovery?
    public private(set) var recordingStartedAt: Date?
    public private(set) var elapsedSeconds: Int = 0

    private var prefixSnapshot: String = ""
    private var finalizedText: String = ""
    private var latestTranscript: String = ""
    private var session: AnyBoxedSession?
    private var startupTask: Task<Void, Never>?
    private var streamTask: Task<Void, Never>?
    private var tickerTask: Task<Void, Never>?
    private var generation: UInt = 0

    public init() {}

    /// Begin a dictation session. `existingDraft` is the text already
    /// present in the composer and is preserved as a prefix so typing +
    /// dictation never collide.
    public func start(existingDraft: String) {
        guard phase != .preparing, phase != .recording, phase != .finalizing else { return }
        cancelPendingWork()
        generation &+= 1
        let startGeneration = generation
        prefixSnapshot = existingDraft
        finalizedText = ""
        latestTranscript = ""
        volatileSegment = ""
        recovery = nil
        elapsedSeconds = 0
        recordingStartedAt = Date()
        phase = .preparing
        draftText = existingDraft
        startTicker()

        startupTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.beginSession(generation: startGeneration)
        }
    }

    /// Stop recording and await analyzer finalization. The final
    /// transcript becomes the committed draft.
    public func stop() async {
        guard isRecording || phase == .preparing || phase == .finalizing else {
            return
        }
        phase = .finalizing
        generation &+= 1
        let startup = startupTask
        startupTask = nil
        startup?.cancel()
        await startup?.value

        var terminalPhase: UniversalDictationPhase = .idle
        if let session {
            do {
                try await session.stop()
            } catch {
                recovery = UniversalDictationRecovery(
                    phase: .failed,
                    message: "Couldn’t finalize the last part of the transcript. What you saw is still in the composer."
                )
                terminalPhase = .failed
            }
        }
        commitLatestTranscript()
        completeSession(phase: terminalPhase)
    }

    /// Cancel the recording; restore the pre-dictation draft.
    public func cancel() async {
        generation &+= 1
        let startup = startupTask
        startupTask = nil
        startup?.cancel()
        await startup?.value
        if let session {
            await session.cancel()
        }
        draftText = prefixSnapshot
        finalizedText = ""
        latestTranscript = ""
        volatileSegment = ""
        recovery = nil
        completeSession(phase: .idle)
        elapsedSeconds = 0
    }

    /// Reset to the idle state without audio side effects. Safe to call
    /// after `stop()` completes.
    public func reset() {
        session = nil
        cancelPendingWork()
        phase = .idle
        recovery = nil
        isRecording = false
        recordingStartedAt = nil
        elapsedSeconds = 0
    }

    private func beginSession(generation startGeneration: UInt) async {
        #if canImport(LifeBoardTranscription)
        do {
            try await requestMicrophoneAuthorization()
        } catch {
            guard isCurrent(startGeneration) else { return }
            fail(
                phase: .denied,
                message: "Microphone access is off. Enable it in Settings to dictate."
            )
            return
        }
        guard isCurrent(startGeneration), Task.isCancelled == false else { return }

        if #available(iOS 26.0, *) {
            do {
                let resolved = try await LiveTranscriptionSessionFactory.makeSession()
                let boxed = AnyBoxedSession(real: resolved)
                guard isCurrent(startGeneration), Task.isCancelled == false else {
                    await boxed.cancel()
                    return
                }
                try await boxed.start()
                guard isCurrent(startGeneration), Task.isCancelled == false else {
                    await boxed.cancel()
                    return
                }
                session = boxed
                isRecording = true
                phase = .recording
                startupTask = nil
                startStreamingEvents(from: boxed)
            } catch let error as TranscriptionError {
                guard isCurrent(startGeneration) else { return }
                switch error {
                case .localeUnsupported, .unsupportedOS:
                    fail(
                        phase: .unsupportedLocale,
                        message: "Live transcription isn’t available for your language yet."
                    )
                case .modelNotInstalled, .appleSpeechConsentRequired:
                    fail(
                        phase: .assetInstallFailed,
                        message: "The on-device speech model couldn’t be installed. Try again later."
                    )
                default:
                    fail(
                        phase: .failed,
                        message: "Couldn’t start dictation. Check your microphone and try again."
                    )
                }
            } catch {
                guard isCurrent(startGeneration) else { return }
                fail(
                    phase: .failed,
                    message: "Couldn’t start dictation. Check your microphone and try again."
                )
            }
        } else {
            fail(
                phase: .unsupportedLocale,
                message: "Live voice transcription requires iOS 26."
            )
        }
        #else
        fail(
            phase: .unsupportedLocale,
            message: "Live voice transcription isn’t available on this device."
        )
        #endif
    }

    private func startStreamingEvents(from session: AnyBoxedSession) {
        let box = session
        streamTask?.cancel()
        streamTask = Task { @MainActor [weak self] in
            guard let self else { return }
            for await event in box.events {
                if Task.isCancelled { break }
                self.handle(event)
            }
            if self.phase == .recording {
                self.commitLatestTranscript()
                self.completeSession(phase: .idle)
            }
        }
    }

    private func handle(_ event: LiveTranscriptionEvent) {
        #if canImport(LifeBoardTranscription)
        switch event {
        case .transcript(let text):
            consumeCumulativeTranscript(text)
        case .failure(let message):
            let failedSession = session
            commitLatestTranscript()
            fail(phase: .failed, message: message)
            Task { await failedSession?.cancel() }
        }
        #endif
    }

    /// Consumes the cumulative transcript emitted by TranscriptionKit.
    /// Internal visibility keeps the transcript-preservation invariant
    /// directly testable without opening an audio session.
    func consumeCumulativeTranscript(_ text: String) {
        latestTranscript = text.trimmingCharacters(in: .whitespacesAndNewlines)
        volatileSegment = latestTranscript
        draftText = joinNonEmpty(prefixSnapshot, "", volatileSegment)
    }

    func commitLatestTranscript() {
        finalizedText = latestTranscript
        volatileSegment = ""
        draftText = joinNonEmpty(prefixSnapshot, finalizedText, "")
    }

    private func completeSession(phase terminalPhase: UniversalDictationPhase) {
        startupTask?.cancel()
        startupTask = nil
        streamTask?.cancel()
        streamTask = nil
        tickerTask?.cancel()
        tickerTask = nil
        session = nil
        isRecording = false
        recordingStartedAt = nil
        phase = terminalPhase
    }

    private func fail(phase failurePhase: UniversalDictationPhase, message: String) {
        recovery = UniversalDictationRecovery(phase: failurePhase, message: message)
        completeSession(phase: failurePhase)
    }

    private func isCurrent(_ startGeneration: UInt) -> Bool {
        generation == startGeneration
    }

    private func startTicker() {
        tickerTask?.cancel()
        tickerTask = Task { @MainActor [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { break }
                if let start = self.recordingStartedAt {
                    self.elapsedSeconds = max(0, Int(Date().timeIntervalSince(start)))
                }
            }
        }
    }

    private func cancelPendingWork() {
        startupTask?.cancel()
        startupTask = nil
        streamTask?.cancel()
        streamTask = nil
        tickerTask?.cancel()
        tickerTask = nil
    }

    private func joinNonEmpty(_ parts: String...) -> String {
        parts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
            .joined(separator: " ")
    }

    private func requestMicrophoneAuthorization() async throws {
        #if canImport(AVFoundation) && os(iOS)
        let granted = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
        guard granted else {
            throw NSError(domain: "UniversalDictationController", code: 1, userInfo: [NSLocalizedDescriptionKey: "Microphone unavailable"])
        }
        #endif
    }

    /// Type-erased box so we can store the boxed session behind
    /// `#if canImport(LifeBoardTranscription)` without exposing the package
    /// to non-iOS-26 callers.
    @MainActor
    private final class AnyBoxedSession {
        #if canImport(LifeBoardTranscription)
        let real: LiveTranscriptionSessionProviding
        init(real: LiveTranscriptionSessionProviding) { self.real = real }
        var events: AsyncStream<LiveTranscriptionEvent> { real.events }
        func start() async throws { try await real.start() }
        func stop() async throws { try await real.stop() }
        func cancel() async { await real.cancel() }
        #else
        init() {}
        #endif
    }
}
