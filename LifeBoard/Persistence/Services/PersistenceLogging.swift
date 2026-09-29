import Foundation
import OSLog

private let persistenceLogger = Logger(
    subsystem: "com.saransh1337.LifeBoard",
    category: "Persistence"
)

private func persistenceLogMessage(
    event: String,
    message: String,
    component: String?,
    fields: [String: String]
) -> String {
    let fieldText = fields.keys.sorted().map { "\($0)=\(fields[$0] ?? "")" }.joined(separator: " ")
    return [component, event, message, fieldText]
        .compactMap { value in value.flatMap { $0.isEmpty ? nil : $0 } }
        .joined(separator: " | ")
}

func logDebug(_ message: String) {
    persistenceLogger.debug("\(message, privacy: .private(mask: .hash))")
}

func logWarning(_ message: String) {
    persistenceLogger.warning("\(message, privacy: .private(mask: .hash))")
}

func logError(_ message: String) {
    persistenceLogger.error("\(message, privacy: .private(mask: .hash))")
}

func logDebug(
    event: String,
    message: String,
    component: String? = nil,
    fields: [String: String] = [:]
) {
    let rendered = persistenceLogMessage(event: event, message: message, component: component, fields: fields)
    persistenceLogger.debug("\(rendered, privacy: .private(mask: .hash))")
}

func logInfo(
    event: String,
    message: String,
    component: String? = nil,
    fields: [String: String] = [:]
) {
    let rendered = persistenceLogMessage(event: event, message: message, component: component, fields: fields)
    persistenceLogger.info("\(rendered, privacy: .private(mask: .hash))")
}

func logWarning(
    event: String,
    message: String,
    component: String? = nil,
    fields: [String: String] = [:]
) {
    let rendered = persistenceLogMessage(event: event, message: message, component: component, fields: fields)
    persistenceLogger.warning("\(rendered, privacy: .private(mask: .hash))")
}

func logError(
    event: String,
    message: String,
    component: String? = nil,
    fields: [String: String] = [:]
) {
    let rendered = persistenceLogMessage(event: event, message: message, component: component, fields: fields)
    persistenceLogger.error("\(rendered, privacy: .private(mask: .hash))")
}
