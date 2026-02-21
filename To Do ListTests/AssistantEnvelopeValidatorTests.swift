import XCTest
@testable import To_Do_List

final class AssistantEnvelopeValidatorTests: XCTestCase {
    func testParseAndValidateAcceptsWrappedJSON() throws {
        let taskID = UUID()
        let envelope = AssistantCommandEnvelope(
            schemaVersion: 2,
            commands: [.updateTask(taskID: taskID, title: nil, dueDate: Date())],
            rationaleText: "Reschedule overdue work."
        )
        let json = try XCTUnwrap(String(data: JSONEncoder().encode(envelope), encoding: .utf8))
        let raw = "```json\n\(json)\n```"

        let result = AssistantEnvelopeValidator.parseAndValidate(
            rawOutput: raw,
            knownTaskIDs: [taskID]
        )

        switch result {
        case .failure(let error):
            XCTFail("Expected parse success, got \(error)")
        case .success(let parsed):
            XCTAssertEqual(parsed.schemaVersion, 2)
            XCTAssertEqual(parsed.commands.count, 1)
            XCTAssertEqual(parsed.rationaleText, "Reschedule overdue work.")
        }
    }

    func testValidateRejectsUnsupportedSchema() {
        let envelope = AssistantCommandEnvelope(
            schemaVersion: 99,
            commands: [.createTask(projectID: UUID(), title: "Draft plan")]
        )

        XCTAssertThrowsError(
            try AssistantEnvelopeValidator.validate(envelope: envelope)
        ) { error in
            guard case AssistantEnvelopeValidationError.unsupportedSchema(99) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testValidateRejectsEmptyCommandSet() {
        let envelope = AssistantCommandEnvelope(schemaVersion: 2, commands: [])

        XCTAssertThrowsError(
            try AssistantEnvelopeValidator.validate(envelope: envelope)
        ) { error in
            guard case AssistantEnvelopeValidationError.emptyCommands = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testValidateRejectsUnknownTaskReference() {
        let knownTaskID = UUID()
        let unknownTaskID = UUID()
        let envelope = AssistantCommandEnvelope(
            schemaVersion: 2,
            commands: [.deleteTask(taskID: unknownTaskID)]
        )

        XCTAssertThrowsError(
            try AssistantEnvelopeValidator.validate(envelope: envelope, knownTaskIDs: [knownTaskID])
        ) { error in
            guard case AssistantEnvelopeValidationError.invalidTaskReference(let taskID) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertEqual(taskID, unknownTaskID)
        }
    }

    func testParseAndValidateReturnsParseFailureForNonJSONOutput() {
        let result = AssistantEnvelopeValidator.parseAndValidate(rawOutput: "plan: move things around")

        switch result {
        case .success:
            XCTFail("Expected parse failure")
        case .failure(let error):
            guard case AssistantEnvelopeValidationError.parseFailure = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }
}
