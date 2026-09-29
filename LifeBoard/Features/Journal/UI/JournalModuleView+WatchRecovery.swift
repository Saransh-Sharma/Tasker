import LifeBoardContracts

extension JournalModuleView {
    func watchRecoveryTitle(_ reason: WatchCaptureRecoveryReason) -> String {
        switch reason {
        case .awaitingAudio: String(localized: "Waiting for recording")
        case .protectedDataUnavailable: String(localized: "Waiting for unlock")
        case .persistenceUnavailable: String(localized: "Couldn’t save entry")
        case .unsupportedSchema: String(localized: "Update needed")
        case .malformedPayload: String(localized: "Couldn’t read entry")
        }
    }

    func watchRecoveryMessage(_ reason: WatchCaptureRecoveryReason) -> String {
        switch reason {
        case .awaitingAudio: String(localized: "Keep both devices nearby, then try again.")
        case .protectedDataUnavailable: String(localized: "Unlock your iPhone, then try again.")
        case .persistenceUnavailable: String(localized: "Nothing was lost. Try again.")
        case .unsupportedSchema: String(localized: "Update LifeBoard on iPhone and Apple Watch.")
        case .malformedPayload: String(localized: "The transfer was incomplete.")
        }
    }

    func watchRecoverySymbol(_ reason: WatchCaptureRecoveryReason) -> String {
        switch reason {
        case .awaitingAudio: "waveform.badge.exclamationmark"
        case .protectedDataUnavailable: "lock.fill"
        case .persistenceUnavailable: "arrow.clockwise.circle"
        case .unsupportedSchema: "applewatch.and.arrow.forward"
        case .malformedPayload: "exclamationmark.triangle"
        }
    }
}
