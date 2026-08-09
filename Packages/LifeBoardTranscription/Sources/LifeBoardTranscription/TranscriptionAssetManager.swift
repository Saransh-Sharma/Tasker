//
//  TranscriptionAssetManager.swift
//  TranscriptionKit
//
//  Single-flight model installation and reservation for SpeechAnalyzer.
//

#if os(iOS)
import Foundation
import Speech
import os.log

@available(iOS 26.0, *)
public actor TranscriptionAssetManager {
    public static let shared = TranscriptionAssetManager()

    public enum ModelStatus: String, Sendable {
        case installed
        case downloadable
        case downloading
        case unsupported
    }

    public typealias ProgressHandler = @Sendable (Double) -> Void

    private var installations: [String: Task<Void, Error>] = [:]

    public func status(
        for kind: TranscriptionEngineKind,
        locale: Locale
    ) async -> ModelStatus {
        guard let module = await Self.makeModule(kind: kind, locale: locale) else {
            return .unsupported
        }
        switch await AssetInventory.status(forModules: [module]) {
        case .installed:
            return .installed
        case .downloading:
            return .downloading
        case .supported:
            return .downloadable
        case .unsupported:
            return .unsupported
        @unknown default:
            return .unsupported
        }
    }

    public func ensureInstalled(
        for modules: [any SpeechModule],
        locale: Locale,
        kind: TranscriptionEngineKind,
        progressHandler: ProgressHandler? = nil
    ) async throws {
        let key = "\(kind.rawValue):\(locale.identifier(.bcp47))"
        if let installation = installations[key] {
            try await installation.value
            progressHandler?(1)
            return
        }

        if await AssetInventory.status(forModules: modules) == .installed {
            _ = try? await AssetInventory.reserve(locale: locale)
            progressHandler?(1)
            return
        }

        let installation = Task {
            try await Self.install(
                modules: modules,
                locale: locale,
                progressHandler: progressHandler
            )
        }
        installations[key] = installation

        do {
            try await installation.value
            installations[key] = nil
        } catch {
            installations[key] = nil
            throw error
        }
    }

    public func prewarmPreferredModel(
        locale preferredLocale: Locale = .current,
        progressHandler: ProgressHandler? = nil
    ) async {
        do {
            let engine = try await TranscriptionEngineRouter.makeEngine(preferredLocale: preferredLocale)
            switch engine.kind {
            case .speechTranscriber:
                guard let locale = await SpeechTranscriber.supportedLocale(equivalentTo: preferredLocale) else {
                    return
                }
                let module = SpeechTranscriber(locale: locale, preset: .transcription)
                try await ensureInstalled(
                    for: [module],
                    locale: locale,
                    kind: .speechTranscriber,
                    progressHandler: progressHandler
                )
            case .dictationTranscriber:
                guard let locale = await DictationTranscriber.supportedLocale(equivalentTo: preferredLocale) else {
                    return
                }
                let module = DictationTranscriber(locale: locale, preset: .longDictation)
                try await ensureInstalled(
                    for: [module],
                    locale: locale,
                    kind: .dictationTranscriber,
                    progressHandler: progressHandler
                )
            }
        } catch {
            let nsError = error as NSError
            TranscriptionLog.speech.error("Speech model prewarm failed domain=\(nsError.domain, privacy: .public) code=\(nsError.code, privacy: .public)")
        }
    }

    public func releaseReservedModels() async {
        for locale in await AssetInventory.reservedLocales {
            _ = await AssetInventory.release(reservedLocale: locale)
        }
    }

    private static func install(
        modules: [any SpeechModule],
        locale: Locale,
        progressHandler: ProgressHandler?
    ) async throws {
        TranscriptionLog.speech.info("Speech model installation starting locale=\(locale.identifier(.bcp47), privacy: .public)")
        do {
            if let request = try await AssetInventory.assetInstallationRequest(supporting: modules) {
                progressHandler?(request.progress.fractionCompleted)
                let monitor = Task {
                    while !Task.isCancelled {
                        progressHandler?(request.progress.fractionCompleted)
                        try? await Task.sleep(for: .milliseconds(150))
                    }
                }
                defer { monitor.cancel() }
                try await request.downloadAndInstall()
            }

            guard await AssetInventory.status(forModules: modules) == .installed else {
                throw TranscriptionError.modelNotInstalled
            }
            _ = try? await AssetInventory.reserve(locale: locale)
            progressHandler?(1)
            TranscriptionLog.speech.info("Speech model installation complete locale=\(locale.identifier(.bcp47), privacy: .public)")
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            let nsError = error as NSError
            TranscriptionLog.speech.error("Speech model installation failed locale=\(locale.identifier(.bcp47), privacy: .public) domain=\(nsError.domain, privacy: .public) code=\(nsError.code, privacy: .public)")
            throw TranscriptionError.modelNotInstalled
        }
    }

    private static func makeModule(
        kind: TranscriptionEngineKind,
        locale: Locale
    ) async -> (any SpeechModule)? {
        switch kind {
        case .speechTranscriber:
            guard SpeechTranscriber.isAvailable,
                  let resolved = await SpeechTranscriber.supportedLocale(equivalentTo: locale) else {
                return nil
            }
            return SpeechTranscriber(locale: resolved, preset: .transcription)
        case .dictationTranscriber:
            guard let resolved = await DictationTranscriber.supportedLocale(equivalentTo: locale) else {
                return nil
            }
            return DictationTranscriber(locale: resolved, preset: .longDictation)
        }
    }
}
#endif
