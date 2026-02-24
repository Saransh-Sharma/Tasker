import XCTest
@testable import To_Do_List

final class LLMProjectionTimeoutTests: XCTestCase {
    func testTimeoutReturnsFallbackPayload() async {
        let startedAt = Date()
        let result = await LLMProjectionTimeout.execute(timeoutMs: 25) {
            do {
                try await _Concurrency.Task.sleep(nanoseconds: 250_000_000)
                return #"{"late":true}"#
            } catch {
                return #"{"cancelled":true}"#
            }
        }

        let elapsedMs = Int(Date().timeIntervalSince(startedAt) * 1_000)
        XCTAssertEqual(result.payload, "{}")
        XCTAssertTrue(result.timedOut)
        XCTAssertLessThan(elapsedMs, 200)
    }

    func testFastProjectionReturnsPayloadWithoutTimeout() async {
        let result = await LLMProjectionTimeout.execute(timeoutMs: 250) {
            #"{"ok":true}"#
        }

        XCTAssertEqual(result.payload, #"{"ok":true}"#)
        XCTAssertFalse(result.timedOut)
    }
}
