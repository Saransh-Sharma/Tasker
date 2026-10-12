import XCTest
@testable import LifeBoard

/// The server validates a product-event batch as a whole: one unknown name,
/// one out-of-contract value or one event over its `maxItems` rejects every
/// event in the request. Failed batches stay queued, so any drift between
/// `ProductTelemetry` and `Services/EVACloud/src/routes/product-events.ts`
/// jammed the queue for good. These tests read the server's route file so the
/// two cannot drift silently in either direction.
final class ProductTelemetryContractTests: XCTestCase {
    private let serverRoute = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Services/EVACloud/src/routes/product-events.ts")

    func testEveryQueuedEventNameIsInTheServerAllowList() throws {
        let accepted = try serverEventNames()
        for name in ProductEventV1.Name.allCases where name.isAcceptedByServer {
            XCTAssertTrue(
                accepted.contains(name.rawValue),
                "The server rejects '\(name.rawValue)'; add it to the Worker's eventNames or to awaitingServerSupport."
            )
        }
    }

    func testHeldBackEventNamesAreStillMissingFromTheServer() throws {
        let accepted = try serverEventNames()
        for name in ProductEventV1.Name.awaitingServerSupport {
            XCTAssertFalse(
                accepted.contains(name.rawValue),
                "The server now accepts '\(name.rawValue)'; remove it from awaitingServerSupport so it is sent again."
            )
        }
    }

    func testBatchSizeMatchesTheServerLimit() throws {
        let source = try String(contentsOf: serverRoute, encoding: .utf8)
        let line = try XCTUnwrap(
            source.split(separator: "\n").first { $0.contains("Type.Array(ProductEventSchema") },
            "The batch schema line moved; update this test."
        )
        let limit = try XCTUnwrap(firstCapture(#"maxItems:\s*(\d+)"#, in: String(line)).flatMap(Int.init))
        XCTAssertEqual(ProductTelemetry.maximumBatchEvents, limit)
    }

    func testDurationBucketsMatchTheServerSchema() throws {
        let source = try String(contentsOf: serverRoute, encoding: .utf8)
        let start = try XCTUnwrap(source.range(of: "durationBucket:"))
        let end = try XCTUnwrap(source.range(of: "]))", range: start.upperBound..<source.endIndex))
        let block = String(source[start.upperBound..<end.lowerBound])
        XCTAssertEqual(ProductEventV1.durationBuckets, Set(captures(#"Type\.Literal\('([^']+)'\)"#, in: block)))
    }

    func testNextBatchTakesTheOldestEventsWithinTheServerLimit() {
        let events = (0..<70).map { event(count: $0) }

        let batch = ProductTelemetry.nextBatch(from: events)

        XCTAssertEqual(batch?.count, ProductTelemetry.maximumBatchEvents)
        XCTAssertEqual(batch?.map(\.count), Array(0..<ProductTelemetry.maximumBatchEvents))
        XCTAssertEqual(ProductTelemetry.nextBatch(from: Array(events.suffix(6)))?.count, 6)
        XCTAssertNil(ProductTelemetry.nextBatch(from: []))
    }

    func testSendableDropsHeldBackNamesAndValuesOutsideTheServerRules() throws {
        let heldBack = try XCTUnwrap(ProductEventV1.Name.awaitingServerSupport.first)
        let events = [
            event(name: heldBack),
            ProductEventV1(
                name: .onboardingStepViewed,
                timestamp: Date(),
                flowVersion: 0,
                audience: "returning_user",
                outcome: "has a space",
                errorCode: String(repeating: "e", count: 81),
                count: -5,
                durationBucket: "forever"
            ),
            ProductEventV1(
                name: .onboardingStepCompleted,
                timestamp: Date(),
                flowVersion: 6,
                audience: nil,
                outcome: "saved-task",
                errorCode: "eva.quota_exhausted",
                count: 250_000,
                durationBucket: "3_10s"
            ),
        ]

        let sendable = ProductTelemetry.sendable(events)

        XCTAssertEqual(sendable.map(\.name), [.onboardingStepViewed, .onboardingStepCompleted])
        let invalid = sendable[0]
        XCTAssertNil(invalid.flowVersion)
        XCTAssertEqual(invalid.audience, "returning_user")
        XCTAssertNil(invalid.outcome)
        XCTAssertNil(invalid.errorCode)
        XCTAssertEqual(invalid.count, 0)
        XCTAssertNil(invalid.durationBucket)
        let valid = sendable[1]
        XCTAssertEqual(valid.flowVersion, 6)
        XCTAssertEqual(valid.outcome, "saved-task")
        XCTAssertEqual(valid.errorCode, "eva.quota_exhausted")
        XCTAssertEqual(valid.count, 100_000)
        XCTAssertEqual(valid.durationBucket, "3_10s")
    }

    // MARK: - Helpers

    private func serverEventNames() throws -> Set<String> {
        let source = try String(contentsOf: serverRoute, encoding: .utf8)
        let start = try XCTUnwrap(source.range(of: "const eventNames = ["), "The server's allow-list moved; update this test.")
        let end = try XCTUnwrap(source.range(of: "] as const", range: start.upperBound..<source.endIndex))
        let names = Set(captures(#"'([A-Za-z0-9_]+)'"#, in: String(source[start.upperBound..<end.lowerBound])))
        XCTAssertFalse(names.isEmpty)
        return names
    }

    private func event(name: ProductEventV1.Name = .onboardingPresented, count: Int? = nil) -> ProductEventV1 {
        ProductEventV1(
            name: name,
            timestamp: Date(),
            flowVersion: nil,
            audience: nil,
            outcome: nil,
            errorCode: nil,
            count: count,
            durationBucket: nil
        )
    }

    private func captures(_ pattern: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            Range(match.range(at: 1), in: text).map { String(text[$0]) }
        }
    }

    private func firstCapture(_ pattern: String, in text: String) -> String? {
        captures(pattern, in: text).first
    }
}
