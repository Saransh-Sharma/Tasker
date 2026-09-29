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

/// Whether Journal content is on screen, for the app-switcher privacy shield.
///
/// The shield used to cover the whole app whenever the scene resigned active,
/// whatever was showing — on the Mac that is every click into another app, so
/// a plan left open beside a document went blank. It now covers only when
/// Journal content is actually visible. Screens that show it mark themselves
/// with `marksJournalContentVisible()`.
@MainActor
enum JournalContentVisibility {
    private(set) static var visibleCount = 0

    static var isVisible: Bool { visibleCount > 0 }

    static func begin() { visibleCount += 1 }

    static func end() { visibleCount = max(0, visibleCount - 1) }
}

extension View {
    /// See `JournalContentVisibility`.
    func marksJournalContentVisible() -> some View {
        onAppear { JournalContentVisibility.begin() }
            .onDisappear { JournalContentVisibility.end() }
    }
}

@MainActor
protocol JournalLockAuthenticating {
    func authenticate(reason: String) async throws
}

@MainActor
struct SystemJournalLockAuthenticator: JournalLockAuthenticating {
    func authenticate(reason: String) async throws {
        guard await BiometricAppLock().authenticate(reason: reason) else {
            throw LAError(.authenticationFailed)
        }
    }
}

@MainActor
@Observable
final class JournalPrivacyController {
    private(set) var state: JournalPrivacyGateState
    var policy: JournalPrivacyPolicy {
        didSet {
            do { try JournalPrivacyPolicyPersistence.save(policy, to: defaults) }
            catch { state = .recoveryRequired(String(localized: "Couldn’t save privacy settings.")) }
        }
    }

    private let defaults: UserDefaults
    private let authenticator: any JournalLockAuthenticating

    init(
        defaults: UserDefaults = UserDefaults(suiteName: AppGroupConstants.suiteName) ?? .standard,
        authenticator: any JournalLockAuthenticating = SystemJournalLockAuthenticator(),
        initiallyUnlocked: Bool = false
    ) {
        self.defaults = defaults
        self.authenticator = authenticator
        let policy = JournalPrivacyPolicyPersistence.load(from: defaults)
        self.policy = policy
        state = policy.requiresAuthentication && initiallyUnlocked == false ? .locked : .unlocked
    }

    func authenticateIfNeeded() async {
        guard policy.requiresAuthentication, state != .unlocked, state != .authenticating else {
            if policy.requiresAuthentication == false { state = .unlocked }
            return
        }
        state = .authenticating
        do {
            try await authenticator.authenticate(reason: String(localized: "Unlock your journal"))
            state = .unlocked
        } catch is CancellationError {
            state = .locked
        } catch {
            let message = (error as? LocalizedError)?.errorDescription
                ?? String(localized: "Couldn’t unlock Journal.")
            state = .recoveryRequired(message)
        }
    }

    func updateAuthenticationRequirement(_ isRequired: Bool) {
        policy.requiresAuthentication = isRequired
        state = isRequired ? .locked : .unlocked
    }

    func lock() {
        if policy.requiresAuthentication { state = .locked }
    }
}

struct JournalPrivacySettingsView: View {
    @Bindable var controller: JournalPrivacyController
    let onCreateBackup: () -> Void
    let onImportBackup: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ComposerScaffold(
            title: String(localized: "Journal privacy"),
            cancelTitle: String(localized: "Done"),
            titleDisplayMode: .inline,
            isPrivacySensitive: true,
            identifier: "journal.privacy"
        ) {
            JournalAccessSection(controller: controller)
            JournalSharingSection(controller: controller)
            JournalRecoverySection(onCreateBackup: onCreateBackup, onImportBackup: onImportBackup)
        } commit: {
            EmptyView()
        }
    }
}

private struct JournalAccessSection: View {
    @Bindable var controller: JournalPrivacyController

    var body: some View {
        ComposerSection(
            String(localized: "Access"),
            footer: String(localized: "Uses Face ID, Touch ID, or your passcode.")
        ) {
            Toggle("Lock Journal", isOn: Binding(
                get: { controller.policy.requiresAuthentication },
                set: { controller.updateAuthenticationRequirement($0) }
            ))
            .toggleStyle(.lifeBoardClay)
            .accessibilityIdentifier("journal.privacy.lock")
            Toggle("Hide in app switcher", isOn: $controller.policy.shieldsAppSwitcher)
                .toggleStyle(.lifeBoardClay)
        }
    }
}

private struct JournalSharingSection: View {
    @Bindable var controller: JournalPrivacyController

    var body: some View {
        ComposerSection(
            String(localized: "Sharing"),
            footer: String(localized: "Eva is off by default. Excluded entries stay private.")
        ) {
            Toggle("Redact sensitive entries", isOn: $controller.policy.excludesSensitiveEntriesFromExport)
                .toggleStyle(.lifeBoardClay)
            Toggle("Let Eva read your journal", isOn: $controller.policy.permitsJournalEvidenceForEva)
                .toggleStyle(.lifeBoardClay)
            // The Home journal card was hard-coded to a degraded state with no
            // way to grant consent anywhere in the app. This is that switch.
            Toggle("Show Journal on Home", isOn: Binding(
                get: { JournalHomeConsentStore.isGranted },
                set: { JournalHomeConsentStore.isGranted = $0 }
            ))
            .toggleStyle(.lifeBoardClay)
            .accessibilityIdentifier("journal.privacy.homeConsent")
        }
    }
}

private struct JournalRecoverySection: View {
    let onCreateBackup: () -> Void
    let onImportBackup: () -> Void

    var body: some View {
        ComposerSection(String(localized: "Encrypted backup")) {
            Button("Create backup", systemImage: "lock.doc", action: onCreateBackup)
                .buttonStyle(.lifeBoardPrimary)
            Button("Import backup", systemImage: "square.and.arrow.down", action: onImportBackup)
                .buttonStyle(.lifeBoardClay(.well, cornerRadius: Radius.pill))
        }
    }
}
