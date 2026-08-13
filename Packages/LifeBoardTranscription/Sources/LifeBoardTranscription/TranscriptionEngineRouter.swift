//
//  TranscriptionEngineRouter.swift
//  TranscriptionKit
//
//  Picks an on-device SpeechAnalyzer module. SpeechTranscriber is preferred;
//  DictationTranscriber extends locale coverage without leaving the analyzer
//  stack. Watch recordings are transferred to the iPhone for analysis.
//

#if os(iOS)
import Foundation
import Speech
import os.log

public enum TranscriptionEngineRouter {

    /// Synchronous OS check; module and locale support are evaluated when routing.
    public static var isAnalyzerOSAvailable: Bool {
        if #available(iOS 26.0, *) {
            return true
        }
        return false
    }

    public static func makeEngine(
        preferredLocale: Locale = .current
    ) async throws -> any TranscriptionEngine {
        guard #available(iOS 26.0, *) else {
            throw TranscriptionError.unsupportedOS
        }

        if SpeechTranscriber.isAvailable,
           let locale = await SpeechTranscriber.supportedLocale(equivalentTo: preferredLocale) {
            TranscriptionLog.speech.info("Transcription route engine=speechTranscriber locale=\(locale.identifier(.bcp47), privacy: .public)")
            return SpeechAnalyzerEngine(locale: locale)
        }

        if let locale = await DictationTranscriber.supportedLocale(equivalentTo: preferredLocale) {
            TranscriptionLog.speech.info("Transcription route engine=dictationTranscriber locale=\(locale.identifier(.bcp47), privacy: .public)")
            return DictationAnalyzerEngine(locale: locale)
        }

        TranscriptionLog.speech.error("Transcription route unavailable locale=\(preferredLocale.identifier(.bcp47), privacy: .public)")
        throw TranscriptionError.localeUnsupported
    }
}
#endif
