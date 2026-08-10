//
//  LiveTranscriptionSession.swift
//  TranscriptionKit
//
//  Microphone-to-SpeechAnalyzer streaming with finalized and volatile text.
//

#if os(iOS)
@preconcurrency import AVFoundation
import Foundation
import Speech

public enum LiveTranscriptionEvent: Sendable, Equatable {
    case transcript(String)
    case failure(String)
}

private final class AudioConversionInput: @unchecked Sendable {
    private let lock = NSLock()
    private let buffer: AVAudioPCMBuffer
    private var consumed = false

    init(buffer: AVAudioPCMBuffer) {
        self.buffer = buffer
    }

    func next(status: UnsafeMutablePointer<AVAudioConverterInputStatus>) -> AVAudioBuffer? {
        lock.lock()
        defer { lock.unlock() }
        guard consumed == false else {
            status.pointee = .noDataNow
            return nil
        }
        consumed = true
        status.pointee = .haveData
        return buffer
    }
}

@available(iOS 26.0, *)
public final class LiveTranscriptionSession: @unchecked Sendable {
    public let engine: TranscriptionEngineKind
    public let locale: Locale
    public let events: AsyncStream<LiveTranscriptionEvent>

    private enum Module {
        case speech(SpeechTranscriber)
        case dictation(DictationTranscriber)

        var speechModule: any SpeechModule {
            switch self {
            case .speech(let module): return module
            case .dictation(let module): return module
            }
        }
    }

    private let module: Module
    private let analyzer: SpeechAnalyzer
    private let audioEngine = AVAudioEngine()
    private let analyzerFormat: AVAudioFormat
    private let inputSequence: AsyncStream<AnalyzerInput>
    private let inputContinuation: AsyncStream<AnalyzerInput>.Continuation
    private let eventContinuation: AsyncStream<LiveTranscriptionEvent>.Continuation

    private var resultsTask: Task<Void, Never>?
    private var converter: AVAudioConverter?
    private var reportedConversionFailure = false
    private var started = false
    private var tapInstalled = false

    private init(
        engine: TranscriptionEngineKind,
        locale: Locale,
        module: Module,
        analyzer: SpeechAnalyzer,
        analyzerFormat: AVAudioFormat
    ) {
        self.engine = engine
        self.locale = locale
        self.module = module
        self.analyzer = analyzer
        self.analyzerFormat = analyzerFormat
        (inputSequence, inputContinuation) = AsyncStream.makeStream()
        (events, eventContinuation) = AsyncStream.makeStream()
    }

    public static func prepare(
        preferredLocale: Locale = .current,
        modelProgress: TranscriptionAssetManager.ProgressHandler? = nil
    ) async throws -> LiveTranscriptionSession {
        let kind: TranscriptionEngineKind
        let locale: Locale
        let module: Module

        if SpeechTranscriber.isAvailable,
           let resolved = await SpeechTranscriber.supportedLocale(equivalentTo: preferredLocale) {
            let transcriber = SpeechTranscriber(
                locale: resolved,
                transcriptionOptions: [],
                reportingOptions: [.volatileResults, .fastResults],
                attributeOptions: [.audioTimeRange]
            )
            try await TranscriptionAssetManager.shared.ensureInstalled(
                for: [transcriber],
                locale: resolved,
                kind: .speechTranscriber,
                progressHandler: modelProgress
            )
            kind = .speechTranscriber
            locale = resolved
            module = .speech(transcriber)
        } else if let resolved = await DictationTranscriber.supportedLocale(equivalentTo: preferredLocale) {
            let transcriber = DictationTranscriber(
                locale: resolved,
                preset: .progressiveShortDictation
            )
            try await TranscriptionAssetManager.shared.ensureInstalled(
                for: [transcriber],
                locale: resolved,
                kind: .dictationTranscriber,
                progressHandler: modelProgress
            )
            kind = .dictationTranscriber
            locale = resolved
            module = .dictation(transcriber)
        } else {
            throw TranscriptionError.localeUnsupported
        }

        guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(
            compatibleWith: [module.speechModule]
        ) else {
            throw TranscriptionError.recognizerUnavailable
        }
        let analyzer = SpeechAnalyzer(
            modules: [module.speechModule],
            options: .init(priority: .userInitiated, modelRetention: .lingering)
        )
        return LiveTranscriptionSession(
            engine: kind,
            locale: locale,
            module: module,
            analyzer: analyzer,
            analyzerFormat: format
        )
    }

    public func start() async throws {
        guard !started else { return }
        started = true
        startResultsTask()

        do {
            try await analyzer.prepareToAnalyze(in: analyzerFormat)
            try await analyzer.start(inputSequence: inputSequence)

            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(
                onBus: 0,
                bufferSize: 1024,
                format: recordingFormat
            ) { [weak self] buffer, _ in
                self?.append(buffer)
            }
            tapInstalled = true
            audioEngine.prepare()
            try audioEngine.start()
        } catch {
            await cancel()
            throw error
        }
    }

    public func stop() async throws {
        guard started else { return }
        started = false
        audioEngine.stop()
        removeTapIfNeeded()
        inputContinuation.finish()

        do {
            try await analyzer.finalizeAndFinishThroughEndOfInput()
            await resultsTask?.value
            eventContinuation.finish()
        } catch {
            await analyzer.cancelAndFinishNow()
            resultsTask?.cancel()
            eventContinuation.yield(.failure(error.localizedDescription))
            eventContinuation.finish()
            throw error
        }
    }

    public func cancel() async {
        started = false
        audioEngine.stop()
        removeTapIfNeeded()
        inputContinuation.finish()
        resultsTask?.cancel()
        await analyzer.cancelAndFinishNow()
        eventContinuation.finish()
    }

    deinit {
        audioEngine.stop()
        if tapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        inputContinuation.finish()
        resultsTask?.cancel()
        eventContinuation.finish()
    }

    private func startResultsTask() {
        let eventContinuation = eventContinuation
        switch module {
        case .speech(let transcriber):
            resultsTask = Task {
                var finalized = ""
                var volatile = ""
                do {
                    for try await result in transcriber.results {
                        let text = String(result.text.characters)
                        if result.isFinal {
                            finalized += text
                            volatile = ""
                        } else {
                            volatile = text
                        }
                        eventContinuation.yield(.transcript(finalized + volatile))
                    }
                } catch is CancellationError {
                    return
                } catch {
                    eventContinuation.yield(.failure(error.localizedDescription))
                }
            }
        case .dictation(let transcriber):
            resultsTask = Task {
                var finalized = ""
                var volatile = ""
                do {
                    for try await result in transcriber.results {
                        let text = String(result.text.characters)
                        if result.isFinal {
                            finalized += text
                            volatile = ""
                        } else {
                            volatile = text
                        }
                        eventContinuation.yield(.transcript(finalized + volatile))
                    }
                } catch is CancellationError {
                    return
                } catch {
                    eventContinuation.yield(.failure(error.localizedDescription))
                }
            }
        }
    }

    private func append(_ buffer: AVAudioPCMBuffer) {
        do {
            inputContinuation.yield(AnalyzerInput(buffer: try convert(buffer)))
        } catch {
            guard !reportedConversionFailure else { return }
            reportedConversionFailure = true
            eventContinuation.yield(.failure(TranscriptionError.audioConversionFailed.localizedDescription))
        }
    }

    private func removeTapIfNeeded() {
        guard tapInstalled else { return }
        audioEngine.inputNode.removeTap(onBus: 0)
        tapInstalled = false
    }

    private func convert(_ buffer: AVAudioPCMBuffer) throws -> AVAudioPCMBuffer {
        if buffer.format == analyzerFormat {
            return buffer
        }

        if converter == nil
            || converter?.inputFormat != buffer.format
            || converter?.outputFormat != analyzerFormat {
            converter = AVAudioConverter(from: buffer.format, to: analyzerFormat)
            converter?.primeMethod = .none
        }
        guard let converter else {
            throw TranscriptionError.audioConversionFailed
        }

        let ratio = analyzerFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up)) + 16
        guard let output = AVAudioPCMBuffer(
            pcmFormat: analyzerFormat,
            frameCapacity: capacity
        ) else {
            throw TranscriptionError.audioConversionFailed
        }

        let input = AudioConversionInput(buffer: buffer)
        var conversionError: NSError?
        let status = converter.convert(to: output, error: &conversionError) { _, inputStatus in
            input.next(status: inputStatus)
        }
        if let conversionError {
            throw conversionError
        }
        guard status != .error else {
            throw TranscriptionError.audioConversionFailed
        }
        return output
    }
}
#endif
