import XCTest
@testable import LifeBoard

@MainActor
final class AppRuntimeTests: XCTestCase {
    func testRuntimeStartsInOneExplicitBootstrappingState() {
        let runtime = AppRuntime()

        guard case .bootstrapping(.starting) = runtime.state else {
            return XCTFail("Expected the runtime to begin in the starting state.")
        }
    }

    func testMissingBootstrapCoordinatorProducesRecoverableTypedFailure() {
        let runtime = AppRuntime()

        runtime.bootstrap()

        guard case .failed(let failure) = runtime.state else {
            return XCTFail("Expected a typed bootstrap failure.")
        }
        XCTAssertEqual(failure.code, .coordinatorUnavailable)
        XCTAssertEqual(failure.recoveryActions, [.retry])
        XCTAssertFalse(failure.diagnosticID.isEmpty)
    }

    func testPersistenceFailureOffersRetryAndCloudRecoveryWithoutRawDiagnostics() {
        let runtime = AppRuntime()
        let failure = BootstrapFailure.persistence(
            message: "LifeBoard storage is temporarily unavailable."
        )

        runtime.publishFailure(failure)

        guard case .failed(let published) = runtime.state else {
            return XCTFail("Expected the failure state.")
        }
        XCTAssertEqual(published.code, .persistenceUnavailable)
        XCTAssertEqual(published.recoveryActions, [.retry, .recoverFromICloud])
        XCTAssertEqual(published.userFacingMessage, "LifeBoard storage is temporarily unavailable.")
    }
}
