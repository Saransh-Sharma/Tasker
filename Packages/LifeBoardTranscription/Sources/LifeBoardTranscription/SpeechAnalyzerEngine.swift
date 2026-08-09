//
//  SpeechAnalyzerEngine.swift
//  TranscriptionKit
//
//  Saved-file transcription through SpeechAnalyzer. SpeechTranscriber is the
//  preferred accuracy path; DictationTranscriber is the analyzer-only locale
//  fallback.
//

#if os(iOS)
import AVFoundation
import CoreMedia
import Foundation
import Speech
import os.log

private struct CollectedTranscript: Sendable {
    var text = ""
    var segments: [TranscriptionSegment] = []
}

@available(iOS 26.0, *)
struct SpeechAnalyzerEngine: TranscriptionEngine {
    let kind: TranscriptionEngineKind = .speechTranscriber
    let locale: Locale

    func transcribeFile(at url: URL) async throws -> FileTranscriptionResult {
        let transcriber = SpeechTranscriber(
            locale: locale,
            transcriptionOptions: [],
            reportingOptions: [],
            attributeOptions: [.audioTimeRange, .transcriptionConfidence]
        )
        try await TranscriptionAssetManager.shared.ensureInstalled(
            for: [transcriber],
            locale: locale,
            kind: kind
        )
        return try await analyze(
            url: url,
            module: transcriber,
            kind: kind,
            locale: locale,
            collect: {
                var collected = CollectedTranscript()
                for try await result in transcriber.results where result.isFinal {
                    Self.append(
                        text: String(result.text.characters),
                        range: result.range,
                        to: &collected
                    )
                }
                return collected
            }
        )
    }

    fileprivate static func append(
        text: String,
        range: CMTimeRange,
        to collected: inout CollectedTranscript
    ) {
        collected.text += text
        collected.segments.append(
            TranscriptionSegment(
                text: text,
                startTime: Self.seconds(range.start),
                duration: Self.seconds(range.duration)
            )
        )
    }

    private static func seconds(_ time: CMTime) -> TimeInterval {
        let value = CMTimeGetSeconds(time)
        return value.isFinite ? max(0, value) : 0
    }
}

@available(iOS 26.0, *)
struct DictationAnalyzerEngine: TranscriptionEngine {
    let kind: TranscriptionEngineKind = .dictationTranscriber
    let locale: Locale

    func transcribeFile(at url: URL) async throws -> FileTranscriptionResult {
        let transcriber = DictationTranscriber(
            locale: locale,
            contentHints: [.farField],
            transcriptionOptions: [.punctuation],
            reportingOptions: [],
            attributeOptions: [.audioTimeRange, .transcriptionConfidence]
        )
        try await TranscriptionAssetManager.shared.ensureInstalled(
            for: [transcriber],
            locale: locale,
            kind: kind
        )
        return try await analyze(
            url: url,
            module: transcriber,
            kind: kind,
            locale: locale,
            collect: {
                var collected = CollectedTranscript()
                for try await result in transcriber.results where result.isFinal {
                    SpeechAnalyzerEngine.append(
                        text: String(result.text.characters),
                        range: result.range,
                        to: &collected
                    )
                }
                return collected
            }
        )
    }
}

@available(iOS 26.0, *)
private func analyze(
    url: URL,
    module: any SpeechModule,
    kind: TranscriptionEngineKind,
    locale: Locale,
    collect: @escaping @Sendable () async throws -> CollectedTranscript
) async throws -> FileTranscriptionResult {
    let startedAt = Date()
    let jobID = UUID()
    let audioFile: AVAudioFile
    do {
        audioFile = try AVAudioFile(forReading: url)
    } catch {
        throw TranscriptionError.noFinalResult
    }

    let analyzer = SpeechAnalyzer(
        modules: [module],
        options: .init(priority: .userInitiated, modelRetention: .lingering)
    )
    async let collected = collect()

    do {
        try await withTaskCancellationHandler {
            if let lastSample = try await analyzer.analyzeSequence(from: audioFile) {
                try await analyzer.finalizeAndFinish(through: lastSample)
            } else {
                await analyzer.cancelAndFinishNow()
            }
        } onCancel: {
            Task { await analyzer.cancelAndFinishNow() }
        }
    } catch {
        await analyzer.cancelAndFinishNow()
        let nsError = error as NSError
        TranscriptionLog.speech.error("Analyzer file job failed id=\(jobID.uuidString, privacy: .public) engine=\(kind.rawValue, privacy: .public) domain=\(nsError.domain, privacy: .public) code=\(nsError.code, privacy: .public)")
        throw error
    }

    let output = try await collected
    let text = TranscriptionPostProcessing.appendingTerminalPunctuation(
        to: output.text.trimmingCharacters(in: .whitespacesAndNewlines)
    )
    guard !text.isEmpty else {
        throw TranscriptionError.noFinalResult
    }

    TranscriptionLog.speech.info("Analyzer file job complete id=\(jobID.uuidString, privacy: .public) engine=\(kind.rawValue, privacy: .public) chars=\(text.count, privacy: .public)")
    return FileTranscriptionResult(
        text: text,
        engine: kind,
        locale: locale,
        processingDuration: Date().timeIntervalSince(startedAt),
        segments: output.segments
    )
}
#endif
