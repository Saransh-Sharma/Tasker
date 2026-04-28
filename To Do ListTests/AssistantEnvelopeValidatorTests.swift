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

    func testValidateAllowsEmptyCommandSetOnlyWhenRequested() throws {
        let envelope = AssistantCommandEnvelope(
            schemaVersion: 3,
            commands: [],
            rationaleText: "Review only."
        )

        XCTAssertThrowsError(try AssistantEnvelopeValidator.validate(envelope: envelope))
        let validated = try AssistantEnvelopeValidator.validate(envelope: envelope, allowEmptyCommands: true)
        XCTAssertEqual(validated.commands.count, 0)

        let raw = """
        {
          "schemaVersion": 3,
          "commands": [],
          "rationaleText": "Review only."
        }
        """
        guard case .success(let parsed) = AssistantEnvelopeValidator.parseAndValidateDetailed(
            rawOutput: raw,
            allowEmptyCommands: true
        ) else {
            return XCTFail("Expected empty planner envelope to parse when explicitly allowed")
        }
        XCTAssertEqual(parsed.envelope.commands.count, 0)
    }

    func testValidateRejectsExcessiveCommandCount() {
        let envelope = AssistantCommandEnvelope(
            schemaVersion: 3,
            commands: (0..<9).map {
                .createInboxTask(
                    projectID: ProjectConstants.inboxProjectID,
                    title: "Task \($0)",
                    estimatedDuration: nil,
                    lifeAreaID: nil,
                    priority: nil,
                    category: nil,
                    details: nil,
                    tagIDs: []
                )
            }
        )

        XCTAssertThrowsError(try AssistantEnvelopeValidator.validate(envelope: envelope)) { error in
            guard case AssistantEnvelopeValidationError.tooManyCommands(9) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testValidateRejectsEmptyAndOverlongTitles() {
        let emptyTitle = AssistantCommandEnvelope(
            schemaVersion: 3,
            commands: [.createTask(projectID: ProjectConstants.inboxProjectID, title: "   ")]
        )
        XCTAssertThrowsError(try AssistantEnvelopeValidator.validate(envelope: emptyTitle))

        let longTitle = AssistantCommandEnvelope(
            schemaVersion: 3,
            commands: [.createTask(projectID: ProjectConstants.inboxProjectID, title: String(repeating: "x", count: 121))]
        )
        XCTAssertThrowsError(try AssistantEnvelopeValidator.validate(envelope: longTitle))
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

    func testUpdateTaskFieldsDistinguishesAbsentSetAndExplicitNull() throws {
        let taskID = UUID()
        let raw = """
        {
          "type": "updateTaskFields",
          "taskID": "\(taskID.uuidString)",
          "title": "Renamed",
          "details": null,
          "tagIDs": null
        }
        """

        let command = try JSONDecoder().decode(AssistantCommand.self, from: Data(raw.utf8))
        guard case let .updateTaskFields(_, title, details, priority, _, _, _, lifeAreaID, tagIDs) = command else {
            return XCTFail("Expected updateTaskFields")
        }
        XCTAssertEqual(title, .set("Renamed"))
        XCTAssertEqual(details, .clear)
        XCTAssertEqual(priority, .absent)
        XCTAssertEqual(lifeAreaID, .absent)
        XCTAssertEqual(tagIDs, .clear)

        let encoded = try JSONEncoder().encode(command)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        XCTAssertEqual(object["title"] as? String, "Renamed")
        XCTAssertTrue(object.keys.contains("details"))
        XCTAssertTrue(object["details"] is NSNull)
        XCTAssertFalse(object.keys.contains("priority"))
        XCTAssertFalse(object.keys.contains("lifeAreaID"))
        XCTAssertTrue(object["tagIDs"] is NSNull)
    }

    func testValidateRejectsClearingNonClearableTaskFields() {
        let taskID = UUID()
        let envelope = AssistantCommandEnvelope(
            schemaVersion: 3,
            commands: [
                .updateTaskFields(
                    taskID: taskID,
                    title: .clear,
                    details: .clear,
                    priority: .absent,
                    energy: .absent,
                    category: .absent,
                    context: .absent,
                    lifeAreaID: .absent,
                    tagIDs: .absent
                )
            ]
        )

        XCTAssertThrowsError(
            try AssistantEnvelopeValidator.validate(envelope: envelope, knownTaskIDs: [taskID])
        ) { error in
            guard case AssistantEnvelopeValidationError.invalidFieldUpdate(let field) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertTrue(field.contains("title"))
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

    func testParseAndValidateWrapsBareScheduledCommandFromDeviceLog() {
        let raw = """
        {
          "type": "createScheduledTask",
          "projectID": "\(ProjectConstants.inboxProjectID.uuidString)",
          "title": "Design review",
          "scheduledStartAt": "2026-04-24T10:00:00Z",
          "scheduledEndAt": "2026-04-24T10:45:00Z",
          "estimatedDuration": 2700,
          "tagIDs": []
        }
        """

        let result = AssistantEnvelopeValidator.parseAndValidateDetailed(rawOutput: raw)

        guard case .success(let parsed) = result else {
            return XCTFail("Expected bare createScheduledTask to normalize")
        }
        XCTAssertEqual(parsed.jsonShape, .bareCommand)
        XCTAssertTrue(parsed.didNormalize)
        XCTAssertEqual(parsed.envelope.schemaVersion, 3)
        XCTAssertEqual(parsed.envelope.commands.count, 1)
        guard case .createScheduledTask(_, let title, _, _, let duration, _, _, _, _, _, _, _) = parsed.envelope.commands.first else {
            return XCTFail("Expected createScheduledTask")
        }
        XCTAssertEqual(title, "Design review")
        XCTAssertEqual(duration, 2700)
    }

    func testParseAndValidateWrapsBareInboxCommand() {
        let raw = """
        {
          "type": "createInboxTask",
          "projectID": "\(ProjectConstants.inboxProjectID.uuidString)",
          "title": "Call dentist",
          "estimatedDuration": null,
          "tagIDs": []
        }
        """

        let result = AssistantEnvelopeValidator.parseAndValidateDetailed(rawOutput: raw)

        guard case .success(let parsed) = result else {
            return XCTFail("Expected bare createInboxTask to normalize")
        }
        XCTAssertEqual(parsed.jsonShape, .bareCommand)
        XCTAssertTrue(parsed.didNormalize)
        guard case .createInboxTask(_, let title, _, _, _, _, _, _) = parsed.envelope.commands.first else {
            return XCTFail("Expected createInboxTask")
        }
        XCTAssertEqual(title, "Call dentist")
    }

    func testParseAndValidateWrapsCommandArray() {
        let raw = """
        [
          {
            "type": "createInboxTask",
            "projectID": "\(ProjectConstants.inboxProjectID.uuidString)",
            "title": "Call dentist",
            "tagIDs": []
          },
          {
            "type": "createInboxTask",
            "projectID": "\(ProjectConstants.inboxProjectID.uuidString)",
            "title": "Buy groceries",
            "tagIDs": []
          }
        ]
        """

        let result = AssistantEnvelopeValidator.parseAndValidateDetailed(rawOutput: raw)

        guard case .success(let parsed) = result else {
            return XCTFail("Expected command array to normalize")
        }
        XCTAssertEqual(parsed.jsonShape, .commandArray)
        XCTAssertTrue(parsed.didNormalize)
        XCTAssertEqual(parsed.envelope.commands.count, 2)
    }

    func testParseAndValidateDefaultsMissingSchemaVersion() {
        let raw = """
        {
          "commands": [
            {
              "type": "createInboxTask",
              "projectID": "\(ProjectConstants.inboxProjectID.uuidString)",
              "title": "Call dentist",
              "tagIDs": []
            }
          ],
          "rationaleText": "Inbox capture."
        }
        """

        let result = AssistantEnvelopeValidator.parseAndValidateDetailed(rawOutput: raw)

        guard case .success(let parsed) = result else {
            return XCTFail("Expected commands without schema to normalize")
        }
        XCTAssertEqual(parsed.jsonShape, .commandsWithoutSchema)
        XCTAssertTrue(parsed.didNormalize)
        XCTAssertEqual(parsed.envelope.schemaVersion, 3)
        XCTAssertEqual(parsed.envelope.rationaleText, "Inbox capture.")
    }
}
