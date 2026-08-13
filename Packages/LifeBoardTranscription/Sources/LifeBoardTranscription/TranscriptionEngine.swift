//
//  TranscriptionEngine.swift
//  TranscriptionKit
//
//  Engine-neutral types for on-device speech-to-text transcription.
//
//  Privacy: host apps do not send audio or journal data to developer servers
//  or non-Apple AI services.
//

import Foundation

public enum TranscriptionEngineKind: String, Sendable {
    case speechTranscriber
    case dictationTranscriber
}

public struct TranscriptionSegment: Sendable, Equatable {
    public let text: String
    public let startTime: TimeInterval
    public let duration: TimeInterval

    public init(text: String, startTime: TimeInterval, duration: TimeInterval) {
        self.text = text
        self.startTime = startTime
        self.duration = duration
    }
}

public struct FileTranscriptionResult: Sendable {
    public let text: String
    public let engine: TranscriptionEngineKind
    public let locale: Locale
    public let processingDuration: TimeInterval
    public let segments: [TranscriptionSegment]

    public init(
        text: String,
        engine: TranscriptionEngineKind,
        locale: Locale,
        processingDuration: TimeInterval,
        segments: [TranscriptionSegment] = []
    ) {
        self.text = text
        self.engine = engine
        self.locale = locale
        self.processingDuration = processingDuration
        self.segments = segments
    }
}

public enum TranscriptionError: LocalizedError, Sendable {
    case recognizerUnavailable
    case noFinalResult
    case appleSpeechConsentRequired
    case modelNotInstalled
    case localeUnsupported
    case unsupportedOS
    case audioConversionFailed

    public var errorDescription: String? {
        switch self {
        case .recognizerUnavailable:
            return "On-device transcription is not available on this device."
        case .noFinalResult:
            return "No final transcription result."
        case .appleSpeechConsentRequired:
            return "On-device transcription needs your consent. Your recording is saved, and you can type manually."
        case .modelNotInstalled:
            return "The on-device speech model could not be installed. Your recording is saved—try transcription again later."
        case .localeUnsupported:
            return "Transcription isn't available for your language yet. Your recording is saved."
        case .unsupportedOS:
            return "On-device transcription requires iOS 26 or later."
        case .audioConversionFailed:
            return "The recording couldn't be converted for on-device transcription."
        }
    }
}

public protocol TranscriptionEngine: Sendable {
    var kind: TranscriptionEngineKind { get }
    func transcribeFile(at url: URL) async throws -> FileTranscriptionResult
}

public enum TranscriptionPostProcessing {
    /// Matches the historical behavior of ending a transcript with terminal punctuation.
    public static func appendingTerminalPunctuation(to text: String) -> String {
        var text = text
        if !text.isEmpty && !text.hasSuffix(".") && !text.hasSuffix("?") && !text.hasSuffix("!") {
            text += "."
        }
        return text
    }
}
