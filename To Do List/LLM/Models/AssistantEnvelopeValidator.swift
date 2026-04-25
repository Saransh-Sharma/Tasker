import Foundation

enum AssistantEnvelopeValidationError: LocalizedError {
    case parseFailure
    case unsupportedSchema(Int)
    case emptyCommands
    case invalidTaskReference(UUID)
    case invalidSchedule(String)

    var errorDescription: String? {
        switch self {
        case .parseFailure:
            return "Could not parse plan output as a valid command envelope."
        case let .unsupportedSchema(version):
            return "Unsupported schema version \(version)."
        case .emptyCommands:
            return "No commands were generated."
        case let .invalidTaskReference(taskID):
            return "Command references missing task \(taskID.uuidString)."
        case let .invalidSchedule(message):
            return message
        }
    }
}

struct AssistantEnvelopeValidator {
    private static let supportedSchemas = Set([1, 2, 3])

    enum JSONShape: String {
        case envelope
        case bareCommand = "bare_command"
        case commandArray = "command_array"
        case commandsWithoutSchema = "commands_without_schema"
        case unknown
    }

    struct ParsedEnvelope {
        let envelope: AssistantCommandEnvelope
        let jsonShape: JSONShape
        let didNormalize: Bool
    }

    /// Executes parseAndValidate.
    static func parseAndValidate(
        rawOutput: String,
        knownTaskIDs: Set<UUID> = [],
        allowEmptyCommands: Bool = false
    ) -> Result<AssistantCommandEnvelope, Error> {
        switch parseAndValidateDetailed(
            rawOutput: rawOutput,
            knownTaskIDs: knownTaskIDs,
            allowEmptyCommands: allowEmptyCommands
        ) {
        case .success(let parsed):
            return .success(parsed.envelope)
        case .failure(let error):
            return .failure(error)
        }
    }

    static func parseAndValidateDetailed(
        rawOutput: String,
        knownTaskIDs: Set<UUID> = [],
        allowEmptyCommands: Bool = false
    ) -> Result<ParsedEnvelope, Error> {
        guard let parsed = parseDetailed(rawOutput: rawOutput) ?? parseDetailed(rawOutput: repairedOutput(rawOutput)) else {
            return .failure(AssistantEnvelopeValidationError.parseFailure)
        }
        do {
            let validated = try validate(
                envelope: parsed.envelope,
                knownTaskIDs: knownTaskIDs,
                allowEmptyCommands: allowEmptyCommands
            )
            return .success(ParsedEnvelope(
                envelope: validated,
                jsonShape: parsed.jsonShape,
                didNormalize: parsed.didNormalize
            ))
        } catch {
            return .failure(error)
        }
    }

    /// Executes parse.
    static func parse(rawOutput: String) -> AssistantCommandEnvelope? {
        parseDetailed(rawOutput: rawOutput)?.envelope
    }

    static func parseDetailed(rawOutput: String) -> ParsedEnvelope? {
        guard let data = extractJSONData(from: rawOutput) else { return nil }
        let shape = jsonShape(from: data)
        if let envelope = decodeEnvelope(from: data) {
            return ParsedEnvelope(envelope: envelope, jsonShape: shape, didNormalize: false)
        }
        guard let normalizedData = normalizedEnvelopeData(from: data) else {
            return nil
        }
        guard let envelope = decodeEnvelope(from: normalizedData) else {
            return nil
        }
        return ParsedEnvelope(envelope: envelope, jsonShape: shape, didNormalize: true)
    }

    static func jsonShape(rawOutput: String) -> JSONShape {
        guard let data = extractJSONData(from: rawOutput) else { return .unknown }
        return jsonShape(from: data)
    }

    static func topLevelKeys(rawOutput: String) -> [String] {
        guard let data = extractJSONData(from: rawOutput),
              let object = try? JSONSerialization.jsonObject(with: data) else {
            return []
        }
        guard let dict = object as? [String: Any] else {
            return []
        }
        return dict.keys.sorted()
    }

    private static func decodeEnvelope(from data: Data) -> AssistantCommandEnvelope? {
        if let envelope = try? JSONDecoder().decode(AssistantCommandEnvelope.self, from: data) {
            return envelope
        }
        let isoDecoder = JSONDecoder()
        isoDecoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            if let timestamp = try? container.decode(Double.self) {
                return Date(timeIntervalSince1970: timestamp)
            }
            let value = try container.decode(String.self)
            if let date = ISO8601DateFormatter.taskerAssistantWithFraction.date(from: value)
                ?? ISO8601DateFormatter.taskerAssistant.date(from: value) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Expected ISO-8601 date string."
            )
        }
        return try? isoDecoder.decode(AssistantCommandEnvelope.self, from: data)
    }

    private static func normalizedEnvelopeData(from data: Data) -> Data? {
        guard let object = try? JSONSerialization.jsonObject(with: data) else {
            return nil
        }
        let normalized: Any?
        if var dict = object as? [String: Any] {
            if dict["type"] != nil {
                normalized = envelopeObject(commands: [dict])
            } else if dict["commands"] != nil, dict["schemaVersion"] == nil {
                dict["schemaVersion"] = 3
                if dict["rationaleText"] == nil {
                    dict["rationaleText"] = "Here's how your day is planned:"
                }
                normalized = dict
            } else {
                normalized = nil
            }
        } else if let array = object as? [[String: Any]], array.isEmpty == false {
            normalized = envelopeObject(commands: array)
        } else {
            normalized = nil
        }
        guard let normalized, JSONSerialization.isValidJSONObject(normalized) else {
            return nil
        }
        return try? JSONSerialization.data(withJSONObject: normalized)
    }

    private static func envelopeObject(commands: [[String: Any]]) -> [String: Any] {
        [
            "schemaVersion": 3,
            "commands": commands,
            "rationaleText": "Here's how your day is planned:"
        ]
    }

    private static func jsonShape(from data: Data) -> JSONShape {
        guard let object = try? JSONSerialization.jsonObject(with: data) else {
            return .unknown
        }
        if let dict = object as? [String: Any] {
            if dict["schemaVersion"] != nil, dict["commands"] != nil {
                return .envelope
            }
            if dict["commands"] != nil {
                return .commandsWithoutSchema
            }
            if dict["type"] != nil {
                return .bareCommand
            }
            return .unknown
        }
        if let array = object as? [[String: Any]], array.contains(where: { $0["type"] != nil }) {
            return .commandArray
        }
        return .unknown
    }

    /// Executes validate.
    static func validate(
        envelope: AssistantCommandEnvelope,
        knownTaskIDs: Set<UUID> = [],
        allowEmptyCommands: Bool = false
    ) throws -> AssistantCommandEnvelope {
        guard supportedSchemas.contains(envelope.schemaVersion) else {
            throw AssistantEnvelopeValidationError.unsupportedSchema(envelope.schemaVersion)
        }
        guard envelope.commands.isEmpty == false || allowEmptyCommands else {
            throw AssistantEnvelopeValidationError.emptyCommands
        }

        if knownTaskIDs.isEmpty == false {
            for command in envelope.commands {
                if let referencedTaskID = referencedTaskID(for: command),
                   knownTaskIDs.contains(referencedTaskID) == false {
                    throw AssistantEnvelopeValidationError.invalidTaskReference(referencedTaskID)
                }
            }
        }
        for command in envelope.commands {
            try validateSchedule(command)
        }
        return envelope
    }

    /// Executes referencedTaskID.
    private static func referencedTaskID(for command: AssistantCommand) -> UUID? {
        switch command {
        case .createTask, .createScheduledTask, .createInboxTask:
            return nil
        case let .restoreTask(taskID, _, _, _, _, _):
            return taskID
        case let .restoreTaskSnapshot(snapshot):
            return snapshot.id
        case let .deleteTask(taskID):
            return taskID
        case let .updateTask(taskID, _, _):
            return taskID
        case let .setTaskCompletion(taskID, _, _):
            return taskID
        case let .completeTask(taskID):
            return taskID
        case let .moveTask(taskID, _):
            return taskID
        case let .updateTaskSchedule(taskID, _, _, _, _):
            return taskID
        case let .updateTaskFields(taskID, _, _, _, _, _, _, _, _):
            return taskID
        case let .deferTask(taskID, _, _):
            return taskID
        case let .dropTaskFromToday(taskID, _, _):
            return taskID
        }
    }

    private static func validateSchedule(_ command: AssistantCommand) throws {
        switch command {
        case .createScheduledTask(_, _, let start, let end, let estimatedDuration, _, _, _, _, _, _, _):
            guard end > start else {
                throw AssistantEnvelopeValidationError.invalidSchedule("Scheduled task end must be after start.")
            }
            if let estimatedDuration, estimatedDuration <= 0 {
                throw AssistantEnvelopeValidationError.invalidSchedule("Estimated duration must be greater than zero.")
            }
        case .updateTaskSchedule(_, let start, let end, let estimatedDuration, _):
            if let start, let end, end <= start {
                throw AssistantEnvelopeValidationError.invalidSchedule("Scheduled task end must be after start.")
            }
            if let estimatedDuration, estimatedDuration <= 0 {
                throw AssistantEnvelopeValidationError.invalidSchedule("Estimated duration must be greater than zero.")
            }
        case .createInboxTask(_, _, let estimatedDuration, _, _, _, _, _):
            if let estimatedDuration, estimatedDuration <= 0 {
                throw AssistantEnvelopeValidationError.invalidSchedule("Estimated duration must be greater than zero.")
            }
        default:
            break
        }
    }

    /// Executes repairedOutput.
    private static func repairedOutput(_ rawOutput: String) -> String {
        rawOutput
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Executes extractJSONData.
    private static func extractJSONData(from rawOutput: String) -> Data? {
        let trimmed = rawOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        if let data = validJSONData(from: trimmed) {
            return data
        }

        let repaired = repairedOutput(trimmed)
        if repaired != trimmed, let data = validJSONData(from: repaired) {
            return data
        }

        if let objectData = extractedJSONData(from: repaired, opening: "{", closing: "}"),
           (try? JSONSerialization.jsonObject(with: objectData)) != nil {
            return objectData
        }
        if let arrayData = extractedJSONData(from: repaired, opening: "[", closing: "]"),
           (try? JSONSerialization.jsonObject(with: arrayData)) != nil {
            return arrayData
        }
        return repaired.data(using: .utf8)
    }

    private static func validJSONData(from string: String) -> Data? {
        guard let data = string.data(using: .utf8),
              (try? JSONSerialization.jsonObject(with: data)) != nil else {
            return nil
        }
        return data
    }

    private static func extractedJSONData(
        from string: String,
        opening: Character,
        closing: Character
    ) -> Data? {
        guard let start = string.firstIndex(of: opening),
              let end = string.lastIndex(of: closing),
              start <= end else {
            return nil
        }
        return String(string[start...end]).data(using: .utf8)
    }
}

private extension ISO8601DateFormatter {
    static let taskerAssistant: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static let taskerAssistantWithFraction: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
