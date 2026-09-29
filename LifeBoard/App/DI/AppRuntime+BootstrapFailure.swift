import Foundation

enum BootstrapProgress: String, Equatable, Sendable {
    case starting
    case openingPersistentStores
    case composingDependencies
    case startingPlatformServices
}

enum BootstrapRecoveryAction: String, CaseIterable, Equatable, Sendable {
    case retry
    case recoverFromICloud
}

enum BootstrapFailureCode: String, Equatable, Sendable {
    case coordinatorUnavailable
    case persistenceUnavailable
    case dependencyGraphInvalid
    case recoveryFailed
}

struct BootstrapFailure: Error, Equatable, Sendable {
    let code: BootstrapFailureCode
    let userFacingMessage: String
    let diagnosticID: String
    let recoveryActions: [BootstrapRecoveryAction]

    init(
        code: BootstrapFailureCode,
        userFacingMessage: String,
        diagnosticID: String = UUID().uuidString,
        recoveryActions: [BootstrapRecoveryAction] = [.retry]
    ) {
        self.code = code
        self.userFacingMessage = userFacingMessage
        self.diagnosticID = diagnosticID
        self.recoveryActions = recoveryActions
    }

    static func persistence(message: String) -> Self {
        Self(
            code: .persistenceUnavailable,
            userFacingMessage: message,
            recoveryActions: [.retry, .recoverFromICloud]
        )
    }

    static func dependencyGraph(diagnosticID: String = UUID().uuidString) -> Self {
        Self(
            code: .dependencyGraphInvalid,
            userFacingMessage: "LifeBoard could not finish preparing its services.",
            diagnosticID: diagnosticID,
            recoveryActions: [.retry]
        )
    }
}
