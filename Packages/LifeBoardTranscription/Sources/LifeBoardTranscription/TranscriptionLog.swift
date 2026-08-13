//
//  TranscriptionLog.swift
//  TranscriptionKit
//
//  Shared logger for the transcription stack. The subsystem resolves to the
//  host app's bundle identifier so OffRecord and LifeBoard logs stay
//  separately filterable in Console.
//

import Foundation
import os.log

enum TranscriptionLog {
    static let subsystem = Bundle.main.bundleIdentifier ?? "TranscriptionKit"

    static let speech = Logger(subsystem: subsystem, category: "SpeechTranscription")
}
