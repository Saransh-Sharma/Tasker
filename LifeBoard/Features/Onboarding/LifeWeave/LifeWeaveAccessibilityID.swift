import Foundation

/// Every identifier the v6 flow publishes.
///
/// Centralised because `scripts/check_accessibility_identifiers.rb` hashes each
/// published string into `scripts/accessibility-identifiers.sha256`. A literal
/// scattered through a view is a string nobody can find when that snapshot
/// changes and nobody can explain when a UI test stops matching.
enum LifeWeaveAccessibilityID {
    static let flow = "onboarding.lifeweave.flow"
    static let canvas = "onboarding.lifeweave.canvas"
    static let progress = "onboarding.lifeweave.progress"
    static let backButton = "onboarding.lifeweave.back"
    static let errorBanner = "onboarding.lifeweave.error"

    static let primaryAction = "onboarding.lifeweave.primary"
    static let secondaryAction = "onboarding.lifeweave.secondary"

    static let captureField = "onboarding.lifeweave.capture.field"
    static let captureInterpret = "onboarding.lifeweave.capture.interpret"
    static let captureKeep = "onboarding.lifeweave.capture.keep"
    static let captureChange = "onboarding.lifeweave.capture.change"
    static let captureSkip = "onboarding.lifeweave.capture.skip"

    static let dayShapeEdit = "onboarding.lifeweave.dayshape.edit"
    static let weekStartChange = "onboarding.lifeweave.dayshape.weekstart"

    static let revealReceipt = "onboarding.lifeweave.reveal.receipt"

    /// Derived from the step's hand-written suffix, never from the case name, so
    /// renaming a case cannot silently rename a published identifier.
    static func step(_ step: LifeWeaveStep) -> String {
        "onboarding.lifeweave.step.\(step.identifierSuffix)"
    }

    static func intent(_ id: String) -> String { "onboarding.lifeweave.intent.\(id)" }
    static func blocker(_ id: String) -> String { "onboarding.lifeweave.blocker.\(id)" }
    static func lifeArea(_ id: String) -> String { "onboarding.lifeweave.area.\(id)" }
    static func primaryArea(_ id: String) -> String { "onboarding.lifeweave.primaryArea.\(id)" }
    static func dayShapePreset(_ id: String) -> String { "onboarding.lifeweave.preset.\(id)" }
    static func captureKind(_ id: String) -> String { "onboarding.lifeweave.capture.kind.\(id)" }
    static func permission(_ id: String) -> String { "onboarding.lifeweave.permission.\(id)" }
    static func calendarRow(_ id: String) -> String { "onboarding.lifeweave.calendar.\(id)" }
    static func healthWriteBack(_ id: String) -> String { "onboarding.lifeweave.health.writeback.\(id)" }
}
