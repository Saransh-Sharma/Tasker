import AVFAudio
import CoreSpotlight
import Foundation
import LifeBoardDomain
import LocalAuthentication
import LifeBoardPersistence
import Observation
import PhotosUI
import LifeBoardDomain
import Speech
import SwiftUI
import LifeBoardTranscription
import UIKit
import UniformTypeIdentifiers
import LifeBoardContracts

@MainActor
@Observable
final class JournalAudioPlaybackController: NSObject, AVAudioPlayerDelegate {
    private var player: AVAudioPlayer?
    private(set) var playingMediaID: UUID?

    func toggle(_ media: JournalMediaValue) {
        if playingMediaID == media.id {
            stop()
            return
        }
        do {
            stop()
            guard let relativePath = media.relativePath else { return }
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true)
            let player = try AVAudioPlayer(contentsOf: JournalAudioFiles.url(relativePath: relativePath))
            player.delegate = self
            player.prepareToPlay()
            guard player.play() else { return }
            self.player = player
            playingMediaID = media.id
        } catch {
            stop()
        }
    }

    func stop() {
        player?.stop()
        player = nil
        playingMediaID = nil
        try? AVAudioSession.sharedInstance().setActive(false)
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in self?.stop() }
    }
}

enum JournalAudioFiles {
    static func newRecordingURL() throws -> URL {
        let root = try directory()
        return root.appendingPathComponent(UUID().uuidString).appendingPathExtension("m4a")
    }

    static func relativePath(for url: URL) -> String { url.lastPathComponent }

    static func url(relativePath: String) throws -> URL {
        guard relativePath == URL(fileURLWithPath: relativePath).lastPathComponent,
              relativePath.contains("/") == false,
              relativePath.contains("\\") == false else {
            throw CocoaError(.fileReadInvalidFileName)
        }
        return try directory().appendingPathComponent(relativePath)
    }

    static func delete(relativePath: String) throws { try FileManager.default.removeItem(at: url(relativePath: relativePath)) }

    static func deleteOrphans(retaining relativePaths: Set<String>) throws {
        let root = try directory()
        let contents = try FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        for file in contents where file.pathExtension.lowercased() == "m4a" {
            guard relativePaths.contains(file.lastPathComponent) == false else { continue }
            try? FileManager.default.removeItem(at: file)
        }
    }

    private static func directory() throws -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let root = base.appendingPathComponent("LifeBoardJournalAudio", isDirectory: true)
        if !FileManager.default.fileExists(atPath: root.path) {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true, attributes: [.protectionKey: FileProtectionType.complete])
        }
        return root
    }
}

@MainActor
/// Journal transcription backed by the shared TranscriptionKit service:
/// on-device SpeechAnalyzer with bounded concurrency and an overall timeout
/// (OffRecord parity).
// Internal, not private: the audio composer that drives it now lives in
// `JournalCaptureComposers.swift`.
final class JournalSpeechTranscriber {
    /// One shared service so the two-job concurrency limiter spans every
    /// journal transcription in the process.
    private static let service = TranscriptionService(
        consentProvider: { UserDefaults.standard.bool(forKey: "lifeboard.journal.speech_consent.v1") }
    )

    func transcribe(_ url: URL) async -> String? {
        do {
            return try await Self.service.transcribe(from: url).text
        } catch {
            return nil
        }
    }
}
