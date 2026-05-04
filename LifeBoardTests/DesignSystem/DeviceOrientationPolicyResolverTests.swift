import XCTest
import UIKit
@testable import LifeBoard

final class DeviceOrientationPolicyResolverTests: XCTestCase {
    func testPhoneUsesPortraitAndUpsideDownOnly() {
        let resolver = DeviceOrientationPolicyResolver()
        let mask = resolver.supportedOrientations(for: .phone)

        XCTAssertEqual(mask, [.portrait, .portraitUpsideDown])
    }

    func testPadUsesAllOrientations() {
        let resolver = DeviceOrientationPolicyResolver()
        let mask = resolver.supportedOrientations(for: .pad)

        XCTAssertEqual(mask, .all)
    }
}
