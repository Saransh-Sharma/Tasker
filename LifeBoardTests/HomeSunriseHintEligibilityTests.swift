import XCTest
@testable import LifeBoard

final class HomeSunriseHintEligibilityTests: XCTestCase {

    func testCanTriggerWhenHomeVisibleCollapsedAndRuntimeAllowsMotion() {
        let now = Date(timeIntervalSince1970: 1_000)

        XCTAssertTrue(
            HomeSunriseHintEligibility.canTrigger(
                isHomeVisible: true,
                sunriseAnchor: .collapsed,
                reduceMotionEnabled: false,
                isUITesting: false,
                hasRunningAnimation: false,
                lastTriggerDate: nil,
                now: now
            )
        )
    }

    func testCannotTriggerWhenSunriseIsMidReveal() {
        XCTAssertFalse(
            HomeSunriseHintEligibility.canTrigger(
                isHomeVisible: true,
                sunriseAnchor: .midReveal,
                reduceMotionEnabled: false,
                isUITesting: false,
                hasRunningAnimation: false,
                lastTriggerDate: nil
            )
        )
    }

    func testCannotTriggerWhenSunriseIsFullReveal() {
        XCTAssertFalse(
            HomeSunriseHintEligibility.canTrigger(
                isHomeVisible: true,
                sunriseAnchor: .fullReveal,
                reduceMotionEnabled: false,
                isUITesting: false,
                hasRunningAnimation: false,
                lastTriggerDate: nil
            )
        )
    }

    func testCannotTriggerWhenReduceMotionIsEnabled() {
        XCTAssertFalse(
            HomeSunriseHintEligibility.canTrigger(
                isHomeVisible: true,
                sunriseAnchor: .collapsed,
                reduceMotionEnabled: true,
                isUITesting: false,
                hasRunningAnimation: false,
                lastTriggerDate: nil
            )
        )
    }

    func testCannotTriggerDuringUITesting() {
        XCTAssertFalse(
            HomeSunriseHintEligibility.canTrigger(
                isHomeVisible: true,
                sunriseAnchor: .collapsed,
                reduceMotionEnabled: false,
                isUITesting: true,
                hasRunningAnimation: false,
                lastTriggerDate: nil
            )
        )
    }

    func testCannotTriggerWhileAnimationIsRunning() {
        XCTAssertFalse(
            HomeSunriseHintEligibility.canTrigger(
                isHomeVisible: true,
                sunriseAnchor: .collapsed,
                reduceMotionEnabled: false,
                isUITesting: false,
                hasRunningAnimation: true,
                lastTriggerDate: nil
            )
        )
    }

    func testCannotTriggerDuringCooldownWindow() {
        let now = Date(timeIntervalSince1970: 1_000)
        let recentTrigger = now.addingTimeInterval(-(HomeSunriseHintEligibility.triggerCooldown - 0.01))

        XCTAssertFalse(
            HomeSunriseHintEligibility.canTrigger(
                isHomeVisible: true,
                sunriseAnchor: .collapsed,
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
        let oldTrigger = now.addingTimeInterval(-(HomeSunriseHintEligibility.triggerCooldown + 0.01))

        XCTAssertTrue(
            HomeSunriseHintEligibility.canTrigger(
                isHomeVisible: true,
                sunriseAnchor: .collapsed,
                reduceMotionEnabled: false,
                isUITesting: false,
                hasRunningAnimation: false,
                lastTriggerDate: oldTrigger,
                now: now
            )
        )
    }
}
