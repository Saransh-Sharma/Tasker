import XCTest
import SwiftUI
@testable import LifeBoard

/// The pure pieces behind `DESIGN.md`'s keyboard contract.
///
/// The Return key is where the Home composer's keyboard first became a dead
/// end: a vertical-axis field spends Return on a newline and never fires
/// `onSubmit`, so the field has to recognise the keystroke in the text. Each
/// case here is one way a person's Return (or paste) arrives.
final class KeyboardExitsTests: XCTestCase {

    // MARK: Return key

    func testReturnTypedAtTheEndIsTheReturnKey() {
        XCTAssertEqual(ReturnKeyPolicy.classify(old: "Buy milk", new: "Buy milk\n"), .returnKey("Buy milk"))
    }

    func testReturnTypedMidTextIsTheReturnKeyAndLeavesNoNewline() {
        // A trailing-newline check missed this and left the line break in the draft.
        XCTAssertEqual(ReturnKeyPolicy.classify(old: "Buy milk", new: "Buy\n milk"), .returnKey("Buy milk"))
    }

    func testAutocorrectCommittedWithReturnIsStillTheReturnKey() {
        // "dont" → "don't\n" arrives as one update, two characters longer, so a
        // "one character was added" rule would have broken Return here.
        XCTAssertEqual(ReturnKeyPolicy.classify(old: "I dont", new: "I don't\n"), .returnKey("I don't"))
    }

    func testReturnOnAnEmptyDraftIsTheReturnKey() {
        XCTAssertEqual(ReturnKeyPolicy.classify(old: "", new: "\n"), .returnKey(""))
    }

    func testAPastedLineDoesNotSendItself() {
        XCTAssertEqual(ReturnKeyPolicy.classify(old: "", new: "Buy milk\n"), .trimmed("Buy milk"))
        XCTAssertEqual(
            ReturnKeyPolicy.classify(old: "Call ", new: "Call Maya about the launch\n"),
            .trimmed("Call Maya about the launch")
        )
    }

    func testAMultiLinePasteKeepsItsLines() {
        XCTAssertEqual(ReturnKeyPolicy.classify(old: "", new: "one\ntwo"), .edit)
        XCTAssertEqual(ReturnKeyPolicy.classify(old: "", new: "one\ntwo\n"), .trimmed("one\ntwo"))
    }

    func testOrdinaryEditsAndDeletionsAreEdits() {
        XCTAssertEqual(ReturnKeyPolicy.classify(old: "Buy", new: "Buy milk"), .edit)
        XCTAssertEqual(ReturnKeyPolicy.classify(old: "one\ntwo", new: "one\ntw"), .edit)
        XCTAssertEqual(ReturnKeyPolicy.classify(old: "one\ntwo", new: "onetwo"), .edit)
        XCTAssertEqual(ReturnKeyPolicy.classify(old: "same", new: "same"), .edit)
    }

    // MARK: Token keys

    func testSigilLandsWhereTheCompletionRowReadsIt() {
        XCTAssertEqual(CaptureTokenCompletion.insertingSigil(.tag, into: ""), "#")
        XCTAssertEqual(CaptureTokenCompletion.insertingSigil(.tag, into: "Buy milk"), "Buy milk #")
        XCTAssertEqual(CaptureTokenCompletion.insertingSigil(.project, into: "Buy milk "), "Buy milk +")
        let draft = CaptureTokenCompletion.insertingSigil(.context, into: "Call bank")
        XCTAssertEqual(
            CaptureTokenCompletion.activeToken(in: draft)?.kind,
            .context,
            "The suggestion row must open on the sigil the key inserted."
        )
    }

    // MARK: Receipts

    func testReceiptAnnouncementSaysWhatChangedAndWhetherItCanBeUndone() {
        XCTAssertEqual(
            ActionReceiptPresentation.announcement(message: "Added “Buy milk” · Tomorrow", canUndo: true),
            "Added “Buy milk” · Tomorrow. Undo available."
        )
        XCTAssertEqual(ActionReceiptPresentation.announcement(message: "Saved", canUndo: false), "Saved")
    }

    /// The Quick Capture card raises the composer and stays on Home. Its
    /// focus request used to aim at an embedded composer Home never mounted.
    @MainActor
    func testQuickCaptureCardFocusesTheComposerAndStaysHome() throws {
        let suite = "KeyboardExitsTests.QuickCapture.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let router = AppRouter(defaults: defaults)
        let destination = router.selectedDestination

        var focusRequests = 0
        HomeWidgetRouteResolver.open(.quickCapture, router: router) { focusRequests += 1 }

        XCTAssertEqual(focusRequests, 1)
        XCTAssertEqual(router.selectedDestination, destination)
        XCTAssertTrue(router.path(for: destination).isEmpty)
    }
}
