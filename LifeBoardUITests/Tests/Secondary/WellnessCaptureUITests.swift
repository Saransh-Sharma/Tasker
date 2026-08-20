import XCTest

/// Smoke coverage for the Body capture composer, which had none.
///
/// It was reported opening as a blank yellow panel with a red circle-slash on
/// device — the signature of an offscreen rasterisation the system could not
/// perform, requested by two content-distorting effects that were attached to
/// the sheet root (see `LifeBoardSignatureEffects`).
///
/// This test does **not** reproduce that failure: verified 2026-08-19, the
/// composer rasterises fine in the simulator with the offending modifiers still
/// in place, so the divergence is device-only. The invariant itself is pinned by
/// `LifeOSFoundationContractTests.testNoComposerRootIsWrappedInAContentDistortingSignatureEffect`.
/// What this asserts is narrower and still worth having: the composer presents
/// and exposes its controls, twice in a row, with signature shaders enabled.
final class WellnessCaptureUITests: BaseUITest {
    override var additionalLaunchArguments: [String] {
        [
            XCUIApplication.LaunchArgumentKey.disableCloudSync.rawValue,
            XCUIApplication.LaunchArgumentKey.enableSignatureShaders.rawValue,
            // The injected deep link is only consumed from inside the seeding
            // harness, which `SceneDelegate` runs only when some
            // `-LIFEBOARD_TEST_SEED_*` argument is present. Without a seed
            // argument the app just launches to Home.
            XCUIApplication.LaunchArgumentKey.testSeedEstablishedWorkspace.rawValue,
            "\(XCUIApplication.LaunchArgumentKey.testDeepLink.rawValue):lifeboard://wellness/body"
        ]
    }

    func testBodyCaptureComposerRendersItsControlsOnEveryPresentation() {
        let workspace = app.descendants(matching: .any)["wellness.workspace"]
        XCTAssertTrue(
            workspace.waitForExistence(timeout: 20),
            "The wellness workspace did not open from the deep link"
        )

        // Twice, because `SignatureShaders.warmUp()` publishes asynchronously:
        // a composer presented before it lands takes the fallback branch and
        // would pass by accident.
        for attempt in 1...2 {
            let action = app.buttons["wellness.hero.action"]
            XCTAssertTrue(
                action.waitForExistence(timeout: 10),
                "The Body hero action was missing on attempt \(attempt)"
            )
            waitForElementToBeHittable(action, timeout: 5)
            action.tap()

            // A sheet drawn as the unrenderable-content placeholder exposes no
            // descendants at all, so this is the assertion that catches it.
            let valueField = app.descendants(matching: .any)["wellness.capture.value"]
            XCTAssertTrue(
                valueField.waitForExistence(timeout: 10),
                "The Body capture composer rendered no value control on attempt \(attempt)"
            )

            let cancel = app.buttons["Cancel"]
            XCTAssertTrue(
                cancel.waitForExistence(timeout: 5),
                "The Body capture composer lost its Cancel control on attempt \(attempt)"
            )
            cancel.tap()
            waitForElementToDisappear(valueField, timeout: 8)
        }
    }
}
