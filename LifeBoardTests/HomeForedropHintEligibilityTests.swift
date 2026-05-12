import XCTest
@testable import LifeBoard

final class HomeForedropHintEligibilityTests: XCTestCase {

    func testCanTriggerWhenHomeVisibleCollapsedAndRuntimeAllowsMotion() {
        let now = Date(timeIntervalSince1970: 1_000)

        XCTAssertTrue(
            HomeForedropHintEligibility.canTrigger(
                isHomeVisible: true,
                foredropAnchor: .collapsed,
                reduceMotionEnabled: false,
                isUITesting: false,
                hasRunningAnimation: false,
                lastTriggerDate: nil,
                now: now
            )
        )
    }

    func testCannotTriggerWhenForedropIsMidReveal() {
        XCTAssertFalse(
            HomeForedropHintEligibility.canTrigger(
                isHomeVisible: true,
                foredropAnchor: .midReveal,
                reduceMotionEnabled: false,
                isUITesting: false,
                hasRunningAnimation: false,
                lastTriggerDate: nil
            )
        )
    }

    func testCannotTriggerWhenForedropIsFullReveal() {
        XCTAssertFalse(
            HomeForedropHintEligibility.canTrigger(
                isHomeVisible: true,
                foredropAnchor: .fullReveal,
                reduceMotionEnabled: false,
                isUITesting: false,
                hasRunningAnimation: false,
                lastTriggerDate: nil
            )
        )
    }

    func testCannotTriggerWhenReduceMotionIsEnabled() {
        XCTAssertFalse(
            HomeForedropHintEligibility.canTrigger(
                isHomeVisible: true,
                foredropAnchor: .collapsed,
                reduceMotionEnabled: true,
                isUITesting: false,
                hasRunningAnimation: false,
                lastTriggerDate: nil
            )
        )
    }

    func testCannotTriggerDuringUITesting() {
        XCTAssertFalse(
            HomeForedropHintEligibility.canTrigger(
                isHomeVisible: true,
                foredropAnchor: .collapsed,
                reduceMotionEnabled: false,
                isUITesting: true,
                hasRunningAnimation: false,
                lastTriggerDate: nil
            )
        )
    }

    func testCannotTriggerWhileAnimationIsRunning() {
        XCTAssertFalse(
            HomeForedropHintEligibility.canTrigger(
                isHomeVisible: true,
                foredropAnchor: .collapsed,
                reduceMotionEnabled: false,
                isUITesting: false,
                hasRunningAnimation: true,
                lastTriggerDate: nil
            )
        )
    }

    func testCannotTriggerDuringCooldownWindow() {
        let now = Date(timeIntervalSince1970: 1_000)
        let recentTrigger = now.addingTimeInterval(-(HomeForedropHintEligibility.triggerCooldown - 0.01))

        XCTAssertFalse(
            HomeForedropHintEligibility.canTrigger(
                isHomeVisible: true,
                foredropAnchor: .collapsed,
                reduceMotionEnabled: false,
                isUITesting: false,
                hasRunningAnimation: false,
                lastTriggerDate: recentTrigger,
                now: now
            )
        )
    }

    func testCanTriggerAfterCooldownWindowExpires() {
        let now = Date(timeIntervalSince1970: 1_000)
        let oldTrigger = now.addingTimeInterval(-(HomeForedropHintEligibility.triggerCooldown + 0.01))

        XCTAssertTrue(
            HomeForedropHintEligibility.canTrigger(
                isHomeVisible: true,
                foredropAnchor: .collapsed,
                reduceMotionEnabled: false,
                isUITesting: false,
                hasRunningAnimation: false,
                lastTriggerDate: oldTrigger,
                now: now
            )
        )
    }
}
