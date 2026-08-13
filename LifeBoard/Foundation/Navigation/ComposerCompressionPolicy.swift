import Foundation

/// Which shape the capture composer is wearing.
public enum ComposerPresentation: String, Equatable, Sendable {
    /// The full 52pt capsule: placeholder, tools, send.
    case capsule
    /// The 48pt orb. Capture is still one tap away; the draft surface is not.
    case orb
}

/// Everything the compression decision is allowed to depend on.
///
/// A struct rather than a pile of parameters so the decision is a pure function
/// of observable state, and so the suppression rules below can be unit-tested
/// without a view, a scroll view, or a running composer.
public struct ComposerCompressionInput: Equatable, Sendable {
    public var contentOffset: CGFloat
    /// True only while the finger is down and moving the content up the screen.
    /// Deceleration is not intent.
    public var isTrackingDownward: Bool
    public var composerState: LifeThreadComposerState
    public var hasDraft: Bool
    public var hasPreview: Bool
    public var hasReceipt: Bool
    public var isKeyboardFocused: Bool
    public var voiceOverEnabled: Bool

    public init(
        contentOffset: CGFloat,
        isTrackingDownward: Bool,
        composerState: LifeThreadComposerState,
        hasDraft: Bool,
        hasPreview: Bool,
        hasReceipt: Bool,
        isKeyboardFocused: Bool,
        voiceOverEnabled: Bool
    ) {
        self.contentOffset = contentOffset
        self.isTrackingDownward = isTrackingDownward
        self.composerState = composerState
        self.hasDraft = hasDraft
        self.hasPreview = hasPreview
        self.hasReceipt = hasReceipt
        self.isKeyboardFocused = isKeyboardFocused
        self.voiceOverEnabled = voiceOverEnabled
    }
}

/// When the composer may compress into the capture orb.
///
/// `DESIGN.md:387` specifies this precisely, and every clause of it is a rule
/// somebody would otherwise discover as a bug: the composer "may compress into a
/// 48-point orb" after *purposeful downward scrolling*, "must restore at the top
/// or on tap", and "must never collapse while editing, dictating, reviewing a
/// proposal, waiting for a result, showing a receipt, or holding a draft."
///
/// The suppression check runs first and returns `.capsule` unconditionally, so
/// no scroll threshold can override it. Losing a half-typed capture to a scroll
/// gesture is the single worst thing this feature could do.
public enum ComposerCompressionPolicy {
    /// Far enough that the person is reading, not nudging.
    public static let compressThreshold: CGFloat = 96
    /// Deliberately *not* the same number. With one threshold, content resting
    /// near it makes the composer flutter between shapes on every pixel of
    /// scroll; the gap is what makes the transition feel decided.
    public static let restoreThreshold: CGFloat = 24

    public static func presentation(
        _ input: ComposerCompressionInput,
        current: ComposerPresentation
    ) -> ComposerPresentation {
        guard isCompressible(input) else { return .capsule }
        if input.contentOffset <= restoreThreshold { return .capsule }
        if current == .capsule {
            // Only an active downward drag compresses. Momentum after the finger
            // lifts, a programmatic scroll, or a keyboard-driven jump are all
            // movement without intent.
            return input.isTrackingDownward && input.contentOffset >= compressThreshold
                ? .orb
                : .capsule
        }
        return .orb
    }

    /// The never-collapse list, as a predicate.
    ///
    /// Only `.resting` and `.settling` survive. `.settling` is included because
    /// it is the tail of a completed capture — the work is already committed, so
    /// compressing during it cannot lose anything.
    public static func isCompressible(_ input: ComposerCompressionInput) -> Bool {
        if input.hasDraft || input.hasPreview || input.hasReceipt { return false }
        if input.isKeyboardFocused { return false }
        // VoiceOver navigates by element, not by scroll offset, so a shape that
        // changes underneath the cursor moves focus for no reason the user asked
        // for. The composer simply never compresses under VoiceOver.
        if input.voiceOverEnabled { return false }
        switch input.composerState {
        case .resting, .settling:
            return true
        case .focused, .tools, .recording, .scanning, .working, .review, .dictating:
            return false
        }
    }
}
