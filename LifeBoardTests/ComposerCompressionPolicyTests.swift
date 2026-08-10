import XCTest
@testable import LifeBoard

/// The composer's never-collapse rules, which are the part of the scroll→orb
/// morph that can actually lose someone's work.
///
/// `DESIGN.md:387` lists them: the composer "must never collapse while editing,
/// dictating, reviewing a proposal, waiting for a result, showing a receipt, or
/// holding a draft." Each of those is one test here, because the failure mode is
/// silent — a draft disappears behind an orb and the person has no idea it is
/// still there.
final class ComposerCompressionPolicyTests: XCTestCase {
    private func input(
        offset: CGFloat = 400,
        tracking: Bool = true,
        state: LifeThreadComposerState = .resting,
        hasDraft: Bool = false,
        hasPreview: Bool = false,
        hasReceipt: Bool = false,
        keyboard: Bool = false,
        voiceOver: Bool = false
    ) -> ComposerCompressionInput {
        ComposerCompressionInput(
            contentOffset: offset,
            isTrackingDownward: tracking,
            composerState: state,
            hasDraft: hasDraft,
            hasPreview: hasPreview,
            hasReceipt: hasReceipt,
            isKeyboardFocused: keyboard,
            voiceOverEnabled: voiceOver
        )
    }

    // MARK: The never-collapse list

    func testADraftNeverCompresses() {
        XCTAssertEqual(
            ComposerCompressionPolicy.presentation(input(hasDraft: true), current: .capsule),
            .capsule
        )
        // Also true from an already-compressed state: typing while compressed
        // must restore, not stay hidden.
        XCTAssertEqual(
            ComposerCompressionPolicy.presentation(input(hasDraft: true), current: .orb),
            .capsule
        )
    }

    func testEveryNonRestingStateSuppressesCompression() {
        let suppressing: [LifeThreadComposerState] = [
            .focused, .tools, .recording, .scanning, .working, .review, .dictating
        ]
        for state in suppressing {
            XCTAssertEqual(
                ComposerCompressionPolicy.presentation(input(state: state), current: .capsule),
                .capsule,
                "\(state) must not compress"
            )
        }
    }

    func testOnlyRestingAndSettlingAreCompressible() {
        // `.settling` is the tail of a committed capture — there is nothing left
        // to lose, so it compresses like `.resting`.
        for state in [LifeThreadComposerState.resting, .settling] {
            XCTAssertTrue(
                ComposerCompressionPolicy.isCompressible(input(state: state)),
                "\(state) should be compressible"
            )
        }
        XCTAssertEqual(LifeThreadComposerState.allCases.count, 9, "New states need a compression decision")
    }

    func testPreviewReceiptKeyboardAndVoiceOverEachSuppress() {
        XCTAssertFalse(ComposerCompressionPolicy.isCompressible(input(hasPreview: true)))
        XCTAssertFalse(ComposerCompressionPolicy.isCompressible(input(hasReceipt: true)))
        XCTAssertFalse(ComposerCompressionPolicy.isCompressible(input(keyboard: true)))
        // VoiceOver navigates by element, so a shape change under the cursor
        // moves focus for a reason the user never asked for.
        XCTAssertFalse(ComposerCompressionPolicy.isCompressible(input(voiceOver: true)))
    }

    // MARK: Purposeful scrolling

    func testCompressionRequiresAnActiveDownwardDrag() {
        // Momentum after the finger lifts is movement without intent.
        XCTAssertEqual(
            ComposerCompressionPolicy.presentation(input(tracking: false), current: .capsule),
            .capsule
        )
        XCTAssertEqual(
            ComposerCompressionPolicy.presentation(input(tracking: true), current: .capsule),
            .orb
        )
    }

    func testShallowScrollDoesNotCompress() {
        let justUnder = ComposerCompressionPolicy.compressThreshold - 1
        XCTAssertEqual(
            ComposerCompressionPolicy.presentation(input(offset: justUnder), current: .capsule),
            .capsule
        )
    }

    func testReturningToTopRestores() {
        XCTAssertEqual(
            ComposerCompressionPolicy.presentation(
                input(offset: ComposerCompressionPolicy.restoreThreshold, tracking: false),
                current: .orb
            ),
            .capsule
        )
    }

    /// The gap between the two thresholds is the whole reason there are two. With
    /// one value, content resting near it flutters between shapes on every pixel
    /// of scroll.
    func testHysteresisHoldsTheOrbBetweenThresholds() {
        let between = (ComposerCompressionPolicy.compressThreshold
            + ComposerCompressionPolicy.restoreThreshold) / 2
        XCTAssertEqual(
            ComposerCompressionPolicy.presentation(input(offset: between, tracking: false), current: .orb),
            .orb,
            "Already compressed: stays compressed between thresholds"
        )
        XCTAssertEqual(
            ComposerCompressionPolicy.presentation(input(offset: between, tracking: true), current: .capsule),
            .capsule,
            "Not yet compressed: does not compress until the far threshold"
        )
        XCTAssertGreaterThan(
            ComposerCompressionPolicy.compressThreshold,
            ComposerCompressionPolicy.restoreThreshold
        )
    }
}
