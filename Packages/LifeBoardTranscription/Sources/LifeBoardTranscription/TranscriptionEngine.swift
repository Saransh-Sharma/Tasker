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
            return String(localized: "Transcription isn’t available on this device.")
        case .noFinalResult:
            return String(localized: "Couldn’t transcribe the recording.")
        case .appleSpeechConsentRequired:
            return String(localized: "Transcription needs permission. Your recording is saved.")
        case .modelNotInstalled:
            return String(localized: "Couldn’t download the speech model. Your recording is saved.")
        case .localeUnsupported:
            return String(localized: "Transcription doesn’t support your language. Your recording is saved.")
        case .unsupportedOS:
            return String(localized: "Transcription needs iOS 26 or later.")
        case .audioConversionFailed:
            return String(localized: "Couldn’t read the recording for transcription.")
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
