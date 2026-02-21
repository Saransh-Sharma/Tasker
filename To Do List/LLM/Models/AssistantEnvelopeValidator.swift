import Foundation

enum AssistantEnvelopeValidationError: LocalizedError {
    case parseFailure
    case unsupportedSchema(Int)
    case emptyCommands
    case invalidTaskReference(UUID)

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
        }
    }
}

struct AssistantEnvelopeValidator {
    private static let supportedSchemas = Set([1, 2])

    /// Executes parseAndValidate.
    static func parseAndValidate(
        rawOutput: String,
        knownTaskIDs: Set<UUID> = []
    ) -> Result<AssistantCommandEnvelope, Error> {
        guard let envelope = parse(rawOutput: rawOutput) ?? parse(rawOutput: repairedOutput(rawOutput)) else {
            return .failure(AssistantEnvelopeValidationError.parseFailure)
        }
        do {
            let validated = try validate(envelope: envelope, knownTaskIDs: knownTaskIDs)
            return .success(validated)
        } catch {
            return .failure(error)
        }
    }

    /// Executes parse.
    static func parse(rawOutput: String) -> AssistantCommandEnvelope? {
        guard let data = extractJSONData(from: rawOutput) else { return nil }
        return try? JSONDecoder().decode(AssistantCommandEnvelope.self, from: data)
    }

    /// Executes validate.
    static func validate(
        envelope: AssistantCommandEnvelope,
        knownTaskIDs: Set<UUID> = []
    ) throws -> AssistantCommandEnvelope {
        guard supportedSchemas.contains(envelope.schemaVersion) else {
            throw AssistantEnvelopeValidationError.unsupportedSchema(envelope.schemaVersion)
        }
        guard envelope.commands.isEmpty == false else {
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
        return envelope
    }

    /// Executes referencedTaskID.
    private static func referencedTaskID(for command: AssistantCommand) -> UUID? {
        switch command {
        case .createTask:
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
        if let firstBrace = trimmed.firstIndex(of: "{"),
           let lastBrace = trimmed.lastIndex(of: "}"),
           firstBrace <= lastBrace {
            let candidate = String(trimmed[firstBrace...lastBrace])
            if let data = candidate.data(using: .utf8) {
                return data
            }
        }
        if let data = trimmed.data(using: .utf8) {
            return data
        }
        return nil
    }
}
