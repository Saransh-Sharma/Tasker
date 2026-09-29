import Foundation
import XCTest
@testable import LifeBoard

final class LoggingPrivacyTests: XCTestCase {
    func testPrivacySafePayloadDropsMessagesContentAndIdentifiers() {
        let payload = LoggingService.privacySafePayload(
            message: "My private journal entry",
            fields: [
                "raw_preview_128": "private transcript",
                "task_id": UUID().uuidString,
                "path": "/private/user/file",
                "status": "degraded",
                "failure_count": "3"
            ]
        )

        XCTAssertEqual(payload, "failure_count=3 status=degraded")
        XCTAssertFalse(payload.contains("private"))
        XCTAssertFalse(payload.contains("task_id"))
    }

    func testExpiredFileLogsArePrunedAfterSevenDays() throws {
        let fileManager = FileManager.default
        let directory = fileManager.temporaryDirectory
            .appendingPathComponent("LoggingPrivacyTests-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: directory) }

        let oldLog = directory.appendingPathComponent("old.log")
        let freshLog = directory.appendingPathComponent("fresh.log")
        try Data("old".utf8).write(to: oldLog)
        try Data("fresh".utf8).write(to: freshLog)

        let now = Date()
        try fileManager.setAttributes(
            [.modificationDate: now.addingTimeInterval(-(LoggingService.logRetentionInterval + 1))],
            ofItemAtPath: oldLog.path
        )
        try fileManager.setAttributes(
            [.modificationDate: now],
            ofItemAtPath: freshLog.path
        )

        LoggingService.pruneExpiredLogs(in: directory, now: now)

        XCTAssertFalse(fileManager.fileExists(atPath: oldLog.path))
        XCTAssertTrue(fileManager.fileExists(atPath: freshLog.path))
    }
}
