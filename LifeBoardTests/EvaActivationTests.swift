import CryptoKit
import MLXLMCommon
import XCTest
@testable import LifeBoard

final class EvaPlaybackCompletionTrackerTests: XCTestCase {
    func testFinishesImmediatelyWhenStreamContainsNoPlayableFrames() {
        var tracker = EvaPlaybackCompletionTracker()

        XCTAssertTrue(tracker.finishedScheduling())
        XCTAssertEqual(tracker.pendingBufferCount, 0)
        XCTAssertTrue(tracker.streamFinished)
    }

    func testFinishesOnlyAfterTheLastScheduledBufferCompletes() {
        var tracker = EvaPlaybackCompletionTracker()
        tracker.scheduledBuffer()
        tracker.scheduledBuffer()

        XCTAssertFalse(tracker.finishedScheduling())
        XCTAssertFalse(tracker.completedBuffer())
        XCTAssertTrue(tracker.completedBuffer())
        XCTAssertEqual(tracker.pendingBufferCount, 0)
    }

    func testEarlyBufferCompletionWaitsForTheStreamToEndAndResetClearsState() {
        var tracker = EvaPlaybackCompletionTracker()
        tracker.scheduledBuffer()

        XCTAssertFalse(tracker.completedBuffer())
        XCTAssertTrue(tracker.finishedScheduling())
        tracker.reset()
        XCTAssertEqual(tracker, EvaPlaybackCompletionTracker())
    }
}

final class EvaSignedConfigurationVerifierTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testAcceptsAValidPinnedConfiguration() throws {
        let key = Curve25519.Signing.PrivateKey()
        let configuration = makeConfiguration()
        let signed = try sign(configuration, using: key)

        let verified = try verifier(key: key).verify(signed)

        XCTAssertEqual(verified.version, configuration.version)
        XCTAssertEqual(verified.cloudState, .disabled)
    }

    func testRuntimeRoutesUseTheServerObjectShape() throws {
        let configuration = makeConfiguration()
        let encoded = try JSONEncoder.evaCloud.encode(configuration)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        let routes = try XCTUnwrap(object["routes"] as? [String: Any])

        XCTAssertNotNil(routes[EvaCloudRoute.chat.rawValue])

        let decoded = try JSONDecoder.evaCloud.decode(EvaCloudRuntimeConfiguration.self, from: encoded)
        XCTAssertEqual(decoded.routes[.chat]?.enabled, true)
    }

    func testRejectsTamperingAndUnapprovedProtectedHeaders() throws {
        let key = Curve25519.Signing.PrivateKey()
        let signed = try sign(makeConfiguration(), using: key)
        let segments = signed.split(separator: ".", omittingEmptySubsequences: false)
        let tamperedPayload = Data("{}".utf8).evaTestBase64URL
        let tampered = "\(segments[0]).\(tamperedPayload).\(segments[2])"

        assertConfigurationError(.invalidSignature) { try verifier(key: key).verify(tampered) }
        assertConfigurationError(.invalidSignature) {
            try verifier(key: key).verify(try sign(makeConfiguration(), using: key, keyIdentifier: "attacker"))
        }
    }

    func testRejectsMissingOrDifferentPinnedKeys() throws {
        let signingKey = Curve25519.Signing.PrivateKey()
        let signed = try sign(makeConfiguration(), using: signingKey)

        assertConfigurationError(.missingPinnedKey) {
            try EvaSignedConfigurationVerifier(
                pinnedPublicKey: nil,
                expectedEnvironment: "staging",
                acceptedVersion: 0,
                now: now
            ).verify(signed)
        }
        assertConfigurationError(.invalidSignature) {
            try verifier(key: Curve25519.Signing.PrivateKey()).verify(signed)
        }
    }

    func testRejectsStaleAndFutureDocuments() throws {
        let key = Curve25519.Signing.PrivateKey()
        let stale = makeConfiguration(issuedAt: now.addingTimeInterval(-7 * 24 * 60 * 60 - 1))
        let future = makeConfiguration(issuedAt: now.addingTimeInterval(5 * 60 + 1))

        assertConfigurationError(.stale) { try verifier(key: key).verify(try sign(stale, using: key)) }
        assertConfigurationError(.stale) { try verifier(key: key).verify(try sign(future, using: key)) }
    }

    func testRejectsRollbackAndEnvironmentMismatch() throws {
        let key = Curve25519.Signing.PrivateKey()
        let rollback = makeConfiguration(version: 9)
        let production = makeConfiguration(environment: "production")

        assertConfigurationError(.rollback) {
            try verifier(key: key, acceptedVersion: 10).verify(try sign(rollback, using: key))
        }
        assertConfigurationError(.unsupported) {
            try verifier(key: key).verify(try sign(production, using: key))
        }
    }

    func testRejectsUnsupportedContractAndProviderIdentity() throws {
        let key = Curve25519.Signing.PrivateKey()
        let wrongContract = makeConfiguration(contractVersions: [2])
        let wrongModel = makeConfiguration(textModel: "gpt-5.6-not-luna")

        assertConfigurationError(.unsupported) {
            try verifier(key: key).verify(try sign(wrongContract, using: key))
        }
        assertConfigurationError(.unsupported) {
            try verifier(key: key).verify(try sign(wrongModel, using: key))
        }
    }

    private func verifier(
        key: Curve25519.Signing.PrivateKey,
        acceptedVersion: Int = 0
    ) -> EvaSignedConfigurationVerifier {
        EvaSignedConfigurationVerifier(
            pinnedPublicKey: key.publicKey.rawRepresentation,
            expectedEnvironment: "staging",
            acceptedVersion: acceptedVersion,
            now: now
        )
    }

    private func makeConfiguration(
        version: Int = 10,
        issuedAt: Date? = nil,
        environment: String = "staging",
        contractVersions: [Int] = [1],
        textModel: String = "gpt-5.6-luna"
    ) -> EvaCloudRuntimeConfiguration {
        EvaCloudRuntimeConfiguration(
            schemaVersion: 2,
            version: version,
            issuedAt: issuedAt ?? now,
            environment: environment,
            cloudState: .disabled,
            ttsEnabled: false,
            maintenanceMessage: "Cloud EVA is disabled during qualification.",
            offlineRecoveryPolicy: "offerTryOffline",
            textModel: textModel,
            speechModel: "tts-1",
            speechVoice: "nova",
            minimumClientVersion: "2.1.0",
            contractVersions: contractVersions,
            routes: [
                .chat: .init(
                    enabled: true,
                    inputTokenCap: 16_000,
                    outputTokenCap: 2_048,
                    reasoning: "low",
                    billable: true,
                    structured: false
                )
            ]
        )
    }

    private func sign(
        _ configuration: EvaCloudRuntimeConfiguration,
        using key: Curve25519.Signing.PrivateKey,
        keyIdentifier: String = "eva-config-v2"
    ) throws -> String {
        let header = try JSONSerialization.data(withJSONObject: ["alg": "EdDSA", "kid": keyIdentifier])
        let encodedHeader = header.evaTestBase64URL
        let encodedPayload = try JSONEncoder.evaCloud.encode(configuration).evaTestBase64URL
        let signingInput = Data("\(encodedHeader).\(encodedPayload)".utf8)
        let signature = try key.signature(for: signingInput).evaTestBase64URL
        return "\(encodedHeader).\(encodedPayload).\(signature)"
    }

    private func assertConfigurationError(
        _ expected: EvaConfigurationError,
        operation: () throws -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(try operation(), file: file, line: line) { error in
            XCTAssertEqual(error as? EvaConfigurationError, expected, file: file, line: line)
        }
    }
}

private extension Data {
    var evaTestBase64URL: String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class EvaActivationTests: XCTestCase {
    private let defaultAssistantIdentity = AssistantIdentitySnapshot(mascotID: .eva)

    func testCloudReadinessPreservesDisabledConfigurationMaintenanceReason() {
        let configuration = EvaCloudRuntimeConfiguration(
            schemaVersion: 2,
            version: 2,
            issuedAt: Date(),
            environment: "staging",
            cloudState: .disabled,
            ttsEnabled: false,
            maintenanceMessage: "Staging text inference is paused for maintenance.",
            offlineRecoveryPolicy: "offerTryOffline",
            textModel: "gpt-5.6-luna",
            speechModel: "tts-1",
            speechVoice: "nova",
            minimumClientVersion: "1.0.0",
            contractVersions: [1],
            routes: [.chat: .init(
                enabled: false,
                inputTokenCap: 16_000,
                outputTokenCap: 2_048,
                reasoning: "low",
                billable: true,
                structured: false
            )]
        )

        let error = EvaCloudAccountState.readinessError(
            configuration: configuration,
            isAuthenticated: true,
            isAdultEligible: true,
            hasConsent: true,
            creditBalance: 100,
            route: .chat,
            lastError: nil
        )

        XCTAssertEqual(error?.localizedDescription, "Staging text inference is paused for maintenance.")
    }

    // MARK: - Readiness ordering

    /// `lastError` holds the text of the most recent transient failure and is
    /// cleared only by a fully successful refresh. Checking it first would hide
    /// the one state the user can actually act on behind a network string.
    func testReadinessReportsMissingAgeVerificationRatherThanAStaleTransientError() {
        let error = EvaCloudAccountState.readinessError(
            configuration: nil,
            isAuthenticated: true,
            isAdultEligible: false,
            hasConsent: false,
            creditBalance: nil,
            route: .chat,
            lastError: "The request timed out."
        )

        guard case .adultEligibilityRequired = error else {
            return XCTFail("Expected .adultEligibilityRequired, got \(String(describing: error))")
        }
    }

    func testReadinessReportsSignInRequiredRatherThanAStaleTransientError() {
        let error = EvaCloudAccountState.readinessError(
            configuration: nil,
            isAuthenticated: false,
            isAdultEligible: false,
            hasConsent: false,
            creditBalance: nil,
            route: .chat,
            lastError: "The request timed out."
        )

        guard case .authenticationRequired = error else {
            return XCTFail("Expected .authenticationRequired, got \(String(describing: error))")
        }
    }

    /// Once the structural gates pass, a transient error is the only thing left
    /// standing between the user and Cloud EVA, so it must still be reported.
    func testReadinessSurfacesTransientErrorOnceStructuralGatesPass() {
        let error = EvaCloudAccountState.readinessError(
            configuration: Self.enabledConfiguration(),
            isAuthenticated: true,
            isAdultEligible: true,
            hasConsent: true,
            creditBalance: 100,
            route: .chat,
            lastError: "The request timed out."
        )

        XCTAssertEqual(error?.localizedDescription, "The request timed out.")
    }

    func testReadinessIsClearWhenEveryGatePasses() {
        XCTAssertNil(EvaCloudAccountState.readinessError(
            configuration: Self.enabledConfiguration(),
            isAuthenticated: true,
            isAdultEligible: true,
            hasConsent: true,
            creditBalance: 100,
            route: .chat,
            lastError: nil
        ))
    }

    private static func enabledConfiguration() -> EvaCloudRuntimeConfiguration {
        EvaCloudRuntimeConfiguration(
            schemaVersion: 2,
            version: 2,
            issuedAt: Date(),
            environment: "staging",
            cloudState: .enabled,
            ttsEnabled: false,
            maintenanceMessage: nil,
            offlineRecoveryPolicy: "offerTryOffline",
            textModel: "gpt-5.6-luna",
            speechModel: "tts-1",
            speechVoice: "nova",
            minimumClientVersion: "1.0.0",
            contractVersions: [1],
            routes: [.chat: .init(
                enabled: true,
                inputTokenCap: 16_000,
                outputTokenCap: 2_048,
                reasoning: "low",
                billable: true,
                structured: false
            )]
        )
    }

    // MARK: - Transport budget and retry policy

    func testDefaultTransportSessionBoundsEveryControlPlaneRequest() {
        let configuration = EvaCloudTransport.makeSession().configuration

        XCTAssertEqual(configuration.timeoutIntervalForRequest, 15)
        XCTAssertEqual(configuration.timeoutIntervalForResource, 30)
        XCTAssertFalse(configuration.waitsForConnectivity)
    }

    /// Issuing a challenge spends nothing, so one retry costs only a stray
    /// Durable Object entry and saves the user a tap.
    func testChallengeRequestRetriesOnceAfterATimeout() async {
        EvaStubURLProtocol.reset()
        EvaStubURLProtocol.respond { _ in .failure(URLError(.timedOut)) }
        let transport = EvaCloudTransport(session: EvaStubURLProtocol.makeSession())

        do {
            _ = try await transport.signInChallenge()
            XCTFail("Expected the stubbed timeout to propagate.")
        } catch {
            XCTAssertTrue(error is URLError)
        }

        XCTAssertEqual(EvaStubURLProtocol.recordedPaths, ["/v1/auth/challenge", "/v1/auth/challenge"])
    }

    func testChallengeRequestSucceedsOnTheRetryAfterATransientTimeout() async throws {
        EvaStubURLProtocol.reset()
        let payload = try JSONSerialization.data(withJSONObject: [
            "challengeId": UUID().uuidString,
            "nonce": String(repeating: "n", count: 24),
        ])
        EvaStubURLProtocol.respond { attempt in
            attempt == 1 ? .failure(URLError(.networkConnectionLost)) : .success((200, payload))
        }
        let transport = EvaCloudTransport(session: EvaStubURLProtocol.makeSession())

        let challenge = try await transport.signInChallenge()

        XCTAssertEqual(challenge.nonce.count, 24)
        XCTAssertEqual(EvaStubURLProtocol.recordedPaths.count, 2)
    }

    /// The exchange consumes a single-use challenge and Apple's single-use
    /// authorization code. Replaying it after a lost response cannot succeed —
    /// it only spends another of the five exchanges allowed per minute.
    func testAppleExchangeIsNeverRetried() async {
        EvaStubURLProtocol.reset()
        EvaStubURLProtocol.respond { _ in .failure(URLError(.timedOut)) }
        let transport = EvaCloudTransport(session: EvaStubURLProtocol.makeSession())

        do {
            _ = try await transport.exchangeAppleCredential(
                challengeId: UUID(),
                nonce: String(repeating: "n", count: 24),
                identityToken: "header.payload.signature",
                authorizationCode: "apple-authorization-code",
                appleUserIdentifier: "000123.abc.456",
                signedAppTransaction: nil
            )
            XCTFail("Expected the stubbed timeout to propagate.")
        } catch {
            XCTAssertTrue(error is URLError)
        }

        XCTAssertEqual(EvaStubURLProtocol.recordedPaths, ["/v1/auth/apple/exchange"])
    }

    // MARK: - Dead sessions must never be a dead end

    /// The failure the user hit: a stored session the server no longer honours.
    /// Leaving it in the Keychain made every later attempt take the same doomed
    /// path and report "Your EVA session has expired" with no route back.
    func testServerRefusalOfRefreshClearsTheStoredSession() async throws {
        try await seedStoredSession(accessTokenExpired: true, refreshTokenExpired: false)
        EvaStubURLProtocol.reset()
        let refusal = Self.sessionExpiredEnvelope
        EvaStubURLProtocol.respond { _ in .success((401, refusal)) }
        let transport = EvaCloudTransport(session: EvaStubURLProtocol.makeSession())

        do {
            _ = try await transport.credits()
            XCTFail("Expected the refused refresh to surface as an authentication requirement.")
        } catch {
            XCTAssertTrue(error.evaRequiresReauthentication)
        }

        let remaining = try await EvaCloudSessionStore.shared.load()
        XCTAssertNil(remaining, "A refused session must not survive to poison the next attempt.")
    }

    /// The mirror image: a timeout says nothing about whether the session is
    /// still good, so discarding it would force a needless Apple sheet.
    func testTransportFailureDuringRefreshKeepsTheStoredSession() async throws {
        try await seedStoredSession(accessTokenExpired: true, refreshTokenExpired: false)
        EvaStubURLProtocol.reset()
        EvaStubURLProtocol.respond { _ in .failure(URLError(.timedOut)) }
        let transport = EvaCloudTransport(session: EvaStubURLProtocol.makeSession())

        _ = try? await transport.credits()

        let remaining = try await EvaCloudSessionStore.shared.load()
        XCTAssertNotNil(remaining, "A network timeout must not destroy a valid session.")
    }

    func testExpiredRefreshTokenClearsTheStoredSessionWithoutACall() async throws {
        try await seedStoredSession(accessTokenExpired: true, refreshTokenExpired: true)
        EvaStubURLProtocol.reset()
        let transport = EvaCloudTransport(session: EvaStubURLProtocol.makeSession())

        do {
            _ = try await transport.credits()
            XCTFail("Expected an authentication requirement.")
        } catch {
            XCTAssertTrue(error.evaRequiresReauthentication)
        }

        let remaining = try await EvaCloudSessionStore.shared.load()
        XCTAssertNil(remaining)
        XCTAssertTrue(EvaStubURLProtocol.recordedPaths.isEmpty, "A dead refresh token needs no round trip.")
    }

    func testOnlyServerAuthenticationVerdictsRequestReauthentication() {
        XCTAssertTrue(EvaProviderError.authenticationRequired.evaRequiresReauthentication)
        XCTAssertTrue(Self.envelope(code: "session_expired").evaRequiresReauthentication)
        XCTAssertTrue(Self.envelope(code: "unauthenticated").evaRequiresReauthentication)

        XCTAssertFalse(URLError(.timedOut).evaRequiresReauthentication)
        XCTAssertFalse(Self.envelope(code: "provider_unavailable").evaRequiresReauthentication)
        XCTAssertFalse(Self.envelope(code: "adult_eligibility_required").evaRequiresReauthentication)
        XCTAssertFalse(EvaProviderError.adultEligibilityRequired.evaRequiresReauthentication)
    }

    private static func envelope(code: String) -> EvaErrorEnvelope {
        EvaErrorEnvelope(
            code: code,
            message: "Your EVA session has expired.",
            requestId: UUID().uuidString,
            retryable: false,
            retryAfter: nil,
            credits: nil,
            recoveryAction: "signIn"
        )
    }

    private static var sessionExpiredEnvelope: Data {
        (try? JSONEncoder.evaCloud.encode(envelope(code: "session_expired"))) ?? Data()
    }

    private func seedStoredSession(accessTokenExpired: Bool, refreshTokenExpired: Bool) async throws {
        try await EvaCloudSessionStore.shared.save(EvaSessionCredentials(
            accountId: "test-account",
            familyId: UUID(),
            accessToken: "stale-access-token",
            accessTokenExpiresAt: Date().addingTimeInterval(accessTokenExpired ? -60 : 900),
            refreshToken: "stale-refresh-token",
            refreshTokenExpiresAt: Date().addingTimeInterval(refreshTokenExpired ? -60 : 86_400),
            installationId: UUID(),
            platform: "ios",
            appleUserIdentifier: "000123.abc.456"
        ))
        addTeardownBlock {
            try? await EvaCloudSessionStore.shared.clear()
        }
    }

    func testRetryIsSkippedForErrorsARetryCannotFix() async {
        EvaStubURLProtocol.reset()
        EvaStubURLProtocol.respond { _ in .failure(URLError(.userAuthenticationRequired)) }
        let transport = EvaCloudTransport(session: EvaStubURLProtocol.makeSession())

        _ = try? await transport.signInChallenge()

        XCTAssertEqual(EvaStubURLProtocol.recordedPaths, ["/v1/auth/challenge"])
    }

    func testAssistantIdentityTextFormatsDefaultAndSelectedPersona() {
        let eva = AssistantIdentitySnapshot(mascotID: .eva)
        let sato = AssistantIdentitySnapshot(mascotID: .sato)

        XCTAssertEqual(AssistantIdentityText.displayName(for: eva), "Eva")
        XCTAssertEqual(AssistantIdentityText.uppercaseName(for: eva), "EVA")
        XCTAssertEqual(AssistantIdentityText.askAction(for: sato), "Ask Sato")
        XCTAssertEqual(AssistantIdentityText.openAction(for: sato), "Open Sato")
        XCTAssertEqual(AssistantIdentityText.readyStatus(for: sato), "Sato is ready")
    }

    func testActivationStarterPromptsLeadWithDayOverview() {
        XCTAssertEqual(EvaStarterPrompt.activationDefaults.first, EvaStarterPrompt.dayOverviewPrompt)
        XCTAssertEqual(EvaStarterPrompt.dayOverviewPrompt.submissionText, "How is my day looking today?")
    }

    func testChiefOfStaffGuideIncludesReschedulePromptSection() throws {
        let section = try XCTUnwrap(EvaChiefOfStaffGuideContent.sections(for: defaultAssistantIdentity).first { $0.id == "reschedule_open_tasks" })

        XCTAssertEqual(section.title, "Reschedule open tasks")
        XCTAssertEqual(section.icon, "calendar.badge.clock")
        XCTAssertTrue(section.body.contains("review cards"))
        XCTAssertEqual(section.prompts.map(\.style), Array(repeating: .naturalLanguage, count: 5))
        XCTAssertEqual(section.prompts.map(\.title), [
            "Reschedule unfinished tasks",
            "Carry today to tomorrow",
            "Push by 20 minutes",
            "Start tomorrow morning",
            "Overdue to today"
        ])
        XCTAssertEqual(section.prompts.map(\.submissionText), [
            "Reschedule my unfinished tasks",
            "Move all my unfinished tasks from today to tomorrow",
            "Move all my unfinished tasks from today forward by 20 minutes",
            "Move my open tasks to tomorrow morning",
            "Move overdue tasks to today"
        ])
    }

    func testHomePromptChipsLeadWithCuratedOrderThenRemainingGuidePrompts() {
        let chips = EvaChiefOfStaffGuideContent.homePromptChips(for: defaultAssistantIdentity)

        XCTAssertEqual(chips.prefix(5).map(\.prompt.title), [
            "How is my day?",
            "Plan today",
            "Recover overdue",
            "Carry today's overdues to tomorrow",
            "Overdue today first and then the rest"
        ])
        XCTAssertEqual(chips.prefix(5).map(\.prompt.submissionText), [
            "How is my day looking today?",
            "Help me plan today around my existing tasks and habits.",
            "Show me what is overdue and what I should recover first.",
            "Move today's overdue tasks to tomorrow.",
            "Plan today with overdue tasks first, then the rest."
        ])

        XCTAssertEqual(chips[5].prompt.title, "Focus first")
        XCTAssertEqual(chips[6].prompt.title, "Reschedule unfinished tasks")
    }

    func testHomePromptChipsAppendGuidePromptsWithoutDuplicateIDsOrSubmissions() {
        let chips = EvaChiefOfStaffGuideContent.homePromptChips(for: defaultAssistantIdentity)
        let ids = chips.map(\.prompt.id)
        let submissionTexts = chips.map(\.prompt.submissionText)
        let guidePromptCount = EvaChiefOfStaffGuideContent.sections(for: defaultAssistantIdentity).flatMap(\.prompts).count
        let skippedGuideDuplicateSubmissionCount = 4
        let curatedPromptCount = 5

        XCTAssertEqual(Set(ids).count, ids.count)
        XCTAssertEqual(Set(submissionTexts).count, submissionTexts.count)
        XCTAssertEqual(chips.count, guidePromptCount - skippedGuideDuplicateSubmissionCount + curatedPromptCount)
    }

    func testHomePromptChipsUseCuratedAndInheritedGuideIcons() throws {
        let chips = EvaChiefOfStaffGuideContent.homePromptChips(for: defaultAssistantIdentity)

        XCTAssertEqual(chips[0].icon, "sparkles")
        XCTAssertEqual(chips[1].icon, "arrow.triangle.2.circlepath")
        XCTAssertEqual(chips[2].icon, "sun.max")
        XCTAssertEqual(chips[3].icon, "calendar.badge.clock")
        XCTAssertEqual(chips[4].icon, "calendar.badge.clock")

        let guideSection = try XCTUnwrap(EvaChiefOfStaffGuideContent.sections(for: defaultAssistantIdentity).first { $0.id == "break_work_down" })
        let guidePrompt = try XCTUnwrap(guideSection.prompts.first)
        let homeChip = try XCTUnwrap(chips.first { $0.prompt.id == guidePrompt.id })
        XCTAssertEqual(homeChip.icon, guideSection.icon)
    }

    func testChiefOfStaffGuideUsesSelectedPersonaCopy() throws {
        let satoIdentity = AssistantIdentitySnapshot(mascotID: .sato)
        let sections = EvaChiefOfStaffGuideContent.sections(for: satoIdentity)
        let visibleCopy = sections.flatMap { [$0.title, $0.body] }.joined(separator: "\n")

        XCTAssertTrue(visibleCopy.contains("Sato"))
        XCTAssertFalse(visibleCopy.contains("Bring Eva"))
        XCTAssertFalse(visibleCopy.contains("Eva should"))
        XCTAssertFalse(visibleCopy.contains("when you want Eva"))
    }

    func testEvaMascotPlacementResolverMapsCoreProductStates() {
        XCTAssertEqual(EvaMascotPlacementResolver.asset(for: .chatEmptyHeader), .neutral)
        XCTAssertEqual(EvaMascotPlacementResolver.asset(for: .chatHelp), .peek)
        XCTAssertEqual(EvaMascotPlacementResolver.asset(for: .chatThinking), .thinking)
        XCTAssertEqual(EvaMascotPlacementResolver.asset(for: .dayOverview), .idea)
        XCTAssertEqual(EvaMascotPlacementResolver.asset(for: .proposalReview), .clipboard)
        XCTAssertEqual(EvaMascotPlacementResolver.asset(for: .proposalApplied), .celebration)
        XCTAssertEqual(EvaMascotPlacementResolver.asset(for: .calendarPlanning), .calendar)
        XCTAssertEqual(EvaMascotPlacementResolver.asset(for: .calendarConflict), .surprised)
        XCTAssertEqual(EvaMascotPlacementResolver.asset(for: .taskCapture), .pencil)
        XCTAssertEqual(EvaMascotPlacementResolver.asset(for: .habitEmpty), .sitting)
        XCTAssertEqual(EvaMascotPlacementResolver.asset(for: .restReminder), .sleepy)
        XCTAssertEqual(EvaMascotPlacementResolver.asset(for: .weeklyReflection), .meditate)
        XCTAssertEqual(EvaMascotPlacementResolver.asset(for: .focusStart), .running)
        XCTAssertEqual(EvaMascotPlacementResolver.asset(for: .settingsIdentity), .neutral)
    }

    func testEvaMascotPlacementResolverMapsOnboardingAndCoachingStates() {
        XCTAssertEqual(EvaMascotPlacementResolver.asset(for: .onboardingWelcome), .sitting)
        XCTAssertEqual(EvaMascotPlacementResolver.asset(for: .onboardingNextStep), .pointRight)
        XCTAssertEqual(EvaMascotPlacementResolver.asset(for: .onboardingEvaValue), .clipboard)
        XCTAssertEqual(EvaMascotPlacementResolver.asset(for: .onboardingCaptureSetup), .pencil)
        XCTAssertEqual(EvaMascotPlacementResolver.asset(for: .onboardingProcessing), .thinking)
        XCTAssertEqual(EvaMascotPlacementResolver.asset(for: .onboardingCalendarPermission), .calendar)
        XCTAssertEqual(EvaMascotPlacementResolver.asset(for: .onboardingNotificationPermission), .peek)
        XCTAssertEqual(EvaMascotPlacementResolver.asset(for: .onboardingSuccess), .excited)
        XCTAssertEqual(EvaMascotPlacementResolver.asset(for: .featureDiscovery), .pointLeft)
    }

    func testEvaMascotPlacementResolverMapsRiskTimelineAndMilestoneStates() {
        XCTAssertEqual(EvaMascotPlacementResolver.asset(for: .timelineEmptySchedule), .calendar)
        XCTAssertEqual(EvaMascotPlacementResolver.asset(for: .timelineConflict), .surprised)
        XCTAssertEqual(EvaMascotPlacementResolver.asset(for: .timelineFreeSlot), .surprised)
        XCTAssertEqual(EvaMascotPlacementResolver.asset(for: .timelineStartPlan), .running)
        XCTAssertEqual(EvaMascotPlacementResolver.asset(for: .taskDeadlineRisk), .worried)
        XCTAssertEqual(EvaMascotPlacementResolver.asset(for: .habitStreakWin), .celebration)
        XCTAssertEqual(EvaMascotPlacementResolver.asset(for: .habitMilestone), .excited)
        XCTAssertEqual(EvaMascotPlacementResolver.asset(for: .calendarRescheduleThinking), .thinking)
    }

    func testMascotPlacementResolverMapsSpriteAnimations() {
        XCTAssertEqual(EvaMascotPlacementResolver.animation(for: .settingsIdentity), .idle)
        XCTAssertEqual(EvaMascotPlacementResolver.animation(for: .onboardingNextStep), .runRight)
        XCTAssertEqual(EvaMascotPlacementResolver.animation(for: .featureDiscovery), .runLeft)
        XCTAssertEqual(EvaMascotPlacementResolver.animation(for: .chatHelp), .waving)
        XCTAssertEqual(EvaMascotPlacementResolver.animation(for: .onboardingSuccess), .jumping)
        XCTAssertEqual(EvaMascotPlacementResolver.animation(for: .taskDeadlineRisk), .failed)
        XCTAssertEqual(EvaMascotPlacementResolver.animation(for: .chatThinking), .waiting)
        XCTAssertEqual(EvaMascotPlacementResolver.animation(for: .focusStart), .running)
        XCTAssertEqual(EvaMascotPlacementResolver.animation(for: .proposalReview), .review)
    }

    func testEvaMascotSizeTiersStayInExpectedRanges() {
        XCTAssertEqual(EvaMascotSize.avatar.points, 40)
        XCTAssertEqual(EvaMascotSize.chip.points, 32)
        XCTAssertEqual(EvaMascotSize.inline.points, 56)
        XCTAssertEqual(EvaMascotSize.card.points, 104)
        XCTAssertEqual(EvaMascotSize.hero.points, 184)
        XCTAssertEqual(EvaMascotSize.custom(46).points, 46)
    }

    func testMascotPersonaCatalogContainsEvaAndSpritePersonas() {
        XCTAssertEqual(AssistantMascotPersona.all.map(\.id), AssistantMascotID.allCases)
        XCTAssertFalse(AssistantMascotPersona.persona(for: .eva).usesSprites)

        let spritePersonas = AssistantMascotPersona.all.filter(\.usesSprites)
        XCTAssertEqual(spritePersonas.map(\.id), [.cloudlet, .dude, .elon, .friday, .johnny, .maddie, .paperclip, .punch, .retriever, .sato, .steve, .theo, .yesman])
        XCTAssertTrue(spritePersonas.allSatisfy { $0.resourceFolderName?.isEmpty == false })
    }

    func testMascotSpriteSheetContract() {
        XCTAssertEqual(MascotSpriteFrameSource.sheetPixelWidth, 1536)
        XCTAssertEqual(MascotSpriteFrameSource.sheetPixelHeight, 1872)
        XCTAssertEqual(MascotSpriteFrameSource.columns, 8)
        XCTAssertEqual(MascotSpriteFrameSource.rows, 9)
        XCTAssertEqual(MascotSpriteFrameSource.cellWidth, 192)
        XCTAssertEqual(MascotSpriteFrameSource.cellHeight, 208)

        XCTAssertEqual(MascotAnimation.idle.frameCount, 6)
        XCTAssertEqual(MascotAnimation.runRight.frameCount, 8)
        XCTAssertEqual(MascotAnimation.runLeft.frameCount, 8)
        XCTAssertEqual(MascotAnimation.waving.frameCount, 4)
        XCTAssertEqual(MascotAnimation.jumping.frameCount, 5)
        XCTAssertEqual(MascotAnimation.failed.frameCount, 8)
        XCTAssertEqual(MascotAnimation.waiting.frameCount, 6)
        XCTAssertEqual(MascotAnimation.running.frameCount, 6)
        XCTAssertEqual(MascotAnimation.review.frameCount, 6)
    }

    #if canImport(UIKit)
    func testEvaMascotAssetsAreBundled() throws {
        let appBundle = Bundle(for: AppDelegate.self)

        for asset in EvaMascotAsset.allCases {
            XCTAssertNotNil(
                UIImage(named: asset.rawValue, in: appBundle, compatibleWith: nil),
                "Missing Eva mascot asset named \(asset.rawValue)"
            )
        }
    }

    func testMascotSpriteAssetsAreBundled() async throws {
        let spritePersonas = AssistantMascotPersona.all.filter(\.usesSprites)

        for persona in spritePersonas {
            XCTAssertNotNil(
                MascotSpriteFrameSource.shared.metadataURL(for: persona),
                "Missing mascot metadata for \(persona.displayName)"
            )
            XCTAssertNotNil(
                MascotSpriteFrameSource.shared.spritesheetURL(for: persona),
                "Missing mascot spritesheet for \(persona.displayName)"
            )
            let frame = await MascotSpriteFrameSource.shared.frame(persona: persona, animation: .idle, index: 0)
            XCTAssertNotNil(
                frame,
                "Could not crop idle frame for \(persona.displayName)"
            )
        }
    }

    func testMascotSpriteProviderClearsDecodedCaches() async throws {
        let provider = MascotSpriteFrameSource.shared
        await provider.clearCaches(reason: "test_setup")

        let persona = try XCTUnwrap(AssistantMascotPersona.all.first { $0.id == .cloudlet })
        let firstFrame = await provider.frame(persona: persona, animation: .idle, index: 0)
        let secondFrame = await provider.frame(persona: persona, animation: .idle, index: 1)
        XCTAssertNotNil(firstFrame)
        XCTAssertNotNil(secondFrame)

        let populatedCounts = await provider.cacheCounts()
        XCTAssertEqual(populatedCounts.sheets, 1)
        XCTAssertEqual(populatedCounts.frames, 2)

        await provider.clearCaches(reason: "test")

        let clearedCounts = await provider.cacheCounts()
        XCTAssertEqual(clearedCounts, MascotSpriteFrameSource.CacheCounts(sheets: 0, frames: 0))
    }
    #endif

    func testMemoryMapperPrependsNewUniqueEntriesAndRespectsLimits() {
        let existing = LLMPersonalMemoryStoreV1(
            preferences: [
                LLMPersonalMemoryEntry(text: "Keep plans realistic and scoped."),
                LLMPersonalMemoryEntry(text: "Prefer concise, direct help.")
            ],
            routines: [
                LLMPersonalMemoryEntry(text: "I lose momentum when context switching piles up.")
            ],
            currentGoals: [
                LLMPersonalMemoryEntry(text: "Ship onboarding redesign"),
                LLMPersonalMemoryEntry(text: "Prepare interview loop"),
                LLMPersonalMemoryEntry(text: "Rebuild workout consistency"),
                LLMPersonalMemoryEntry(text: "Protect focus time")
            ]
        )

        let draft = EvaProfileDraft(
            selectedWorkingStyleIDs: [
                EvaWorkingStyleID.prioritizeForMe.rawValue,
                EvaWorkingStyleID.concise.rawValue
            ],
            selectedMomentumBlockerIDs: [
                EvaMomentumBlockerID.contextSwitching.rawValue,
                EvaMomentumBlockerID.tooManyOpenTasks.rawValue
            ],
            customWorkingStyleNote: "  Keep plans realistic and scoped.  ",
            customMomentumNote: "I often avoid the hardest task until late",
            goals: [
                "Ship EVA activation",
                "Prepare interview loop",
                "Tighten weekly planning"
            ]
        )

        let merged = EvaMemoryMapper.mergeIntoLocalStore(draft: draft, existing: existing)

        XCTAssertEqual(
            merged.preferences.map(\.text),
            [
                "Help me choose what matters most.",
                "Prefer concise, direct help.",
                "Keep plans realistic and scoped."
            ]
        )
        XCTAssertEqual(
            merged.routines.map(\.text),
            [
                "I lose momentum when context switching piles up.",
                "I lose momentum when too many tasks stay open.",
                "I often avoid the hardest task until late"
            ]
        )
        XCTAssertEqual(
            merged.currentGoals.map(\.text),
            [
                "Ship EVA activation",
                "Prepare interview loop",
                "Tighten weekly planning",
                "Ship onboarding redesign"
            ]
        )
    }

    func testActivationDefaultsStoreRoundTripsState() throws {
        let suiteName = "EvaActivationTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        var state = EvaActivationState()
        state.stage = .modelChoice
        state.selectedWorkingStyleIDs = [EvaWorkingStyleID.focus.rawValue]
        state.goals = ["Ship EVA onboarding"]
        state.chosenModelName = ModelConfiguration.qwen_3_5_0_8b_optiq_4bit.name
        state.hasTriggeredInstall = true
        state.apply(profileDraft: EvaProfileDraft(
            selectedWorkingStyleIDs: [EvaWorkingStyleID.focus.rawValue],
            goals: ["Ship EVA onboarding"]
        ))

        EvaActivationDefaultsStore.save(state, defaults: defaults)

        let loaded = EvaActivationDefaultsStore.load(defaults: defaults)
        XCTAssertEqual(loaded, state)

        EvaActivationDefaultsStore.markCompleted(defaults: defaults)
        XCTAssertTrue(EvaActivationDefaultsStore.load(defaults: defaults).isComplete)

        // Cloud-setup staging is gone: the screen it staged is retired, and
        // `bootstrap()` would normalise the stage straight back to `.completed`.
        EvaActivationDefaultsStore.stageForUITesting(
            arguments: ["-LIFEBOARD_TEST_EVA_CLOUD_SETUP"],
            defaults: defaults
        )
        XCTAssertEqual(EvaActivationDefaultsStore.load(defaults: defaults).stage, .completed)
    }

    /// A fresh install never meets EVA's own first-run flow any more.
    ///
    /// App onboarding asks the working-style, goals, and cloud questions, then
    /// marks activation completed on its way out, so opening the EVA tab lands
    /// directly in chat. This is the whole point of the merge: the coordinator
    /// used to start every new user at `.intro`.
    func testFreshCoordinatorSkipsTheRetiredFirstRunFlow() throws {
        let defaults = try makeDefaults()
        let coordinator = makeCoordinator(defaults: defaults)

        XCTAssertEqual(coordinator.state.stage, .completed)
        XCTAssertTrue(coordinator.state.isComplete)
    }

    /// Someone mid-flight when they updated must not be stranded.
    ///
    /// Each retired stage is a screen that no longer leads anywhere, so the
    /// honest resolution is to let them into EVA rather than leave them on it.
    func testEveryRetiredFirstRunStageNormalizesToCompleted() throws {
        for stage in EvaActivationCoordinator.retiredFirstRunStages {
            let defaults = try makeDefaults()
            var state = EvaActivationState()
            state.stage = stage
            state.isComplete = false
            EvaActivationDefaultsStore.save(state, defaults: defaults)

            let coordinator = makeCoordinator(defaults: defaults)
            XCTAssertEqual(coordinator.state.stage, .completed, "stage \(stage) should retire")
            XCTAssertTrue(coordinator.state.isComplete, "stage \(stage) should retire")
        }
    }

    /// An already-completed user keeps their thread through the retirement.
    ///
    /// Normalising a retired stage must not look like a fresh account: the
    /// first thread is the user's real conversation history.
    func testRetirementPreservesAnExistingActivationThread() throws {
        let defaults = try makeDefaults()
        let threadID = UUID()
        var state = EvaActivationState()
        state.stage = .firstChat
        state.firstThreadID = threadID
        state.hasPersistedUserMessage = true
        EvaActivationDefaultsStore.save(state, defaults: defaults)

        let coordinator = makeCoordinator(defaults: defaults)

        XCTAssertEqual(coordinator.state.stage, .completed)
        XCTAssertEqual(coordinator.state.firstThreadID, threadID)
        XCTAssertTrue(coordinator.state.hasPersistedUserMessage)
    }

    func testCoordinatorMigratesExistingInstalledModels() throws {
        let defaults = try makeDefaults()
        let appManager = AppManager()
        appManager.installedModels = [ModelConfiguration.qwen_3_0_6b_4bit.name]

        let coordinator = EvaActivationCoordinator(
            appManager: appManager,
            defaults: defaults,
            deviceSupportsLocalEvaProvider: { true }
        )

        XCTAssertTrue(coordinator.state.isComplete)
        XCTAssertEqual(coordinator.state.stage, .completed)
    }

    func testCoordinatorMovesIntoRecoveryAfterInstallFailure() throws {
        let defaults = try makeDefaults()
        let coordinator = makeCoordinator(defaults: defaults)

        coordinator.selectModel(ModelConfiguration.qwen_3_5_0_8b_optiq_4bit.name)
        coordinator.continueFromModelChoice()
        coordinator.completeInstall(
            .failed(
                failedModelName: ModelConfiguration.qwen_3_0_6b_4bit.name,
                selectedModelRetryCount: 1,
                attemptedFastFallback: true
            )
        )

        XCTAssertEqual(coordinator.state.stage, .installRecovery)
        XCTAssertEqual(coordinator.state.failedModelName, ModelConfiguration.qwen_3_0_6b_4bit.name)
        XCTAssertEqual(coordinator.state.selectedModelRetryCount, 1)
        XCTAssertTrue(coordinator.state.hasAttemptedFastFallback)
        XCTAssertTrue(coordinator.state.recoveryPresented)
    }

    func testCoordinatorSwitchRecoveryToFastUpdatesChosenModelAndReentersInstall() throws {
        let defaults = try makeDefaults()
        let coordinator = makeCoordinator(defaults: defaults)

        coordinator.selectModel(ModelConfiguration.qwen_3_5_0_8b_optiq_4bit.name)
        coordinator.completeInstall(
            .failed(
                failedModelName: ModelConfiguration.qwen_3_0_6b_4bit.name,
                selectedModelRetryCount: 1,
                attemptedFastFallback: true
            )
        )

        coordinator.switchRecoveryToFast()

        XCTAssertEqual(coordinator.state.stage, .modelDownload)
        XCTAssertEqual(coordinator.state.chosenModelName, ModelConfiguration.qwen_3_0_6b_4bit.name)
        XCTAssertEqual(coordinator.state.preparedModelName, ModelConfiguration.qwen_3_0_6b_4bit.name)
        XCTAssertNil(coordinator.state.failedModelName)
    }

    func testCoordinatorSuccessfulInstallPersistsPreparedModelAndOpensFirstWin() throws {
        let defaults = try makeDefaults()
        let coordinator = makeCoordinator(defaults: defaults)

        coordinator.selectModel(ModelConfiguration.qwen_3_5_0_8b_optiq_4bit.name)
        coordinator.completeInstall(
            .success(
                preparedModelName: ModelConfiguration.qwen_3_0_6b_4bit.name,
                selectedModelRetryCount: 1,
                attemptedFastFallback: true
            )
        )

        XCTAssertEqual(coordinator.state.stage, .firstChat)
        XCTAssertTrue(coordinator.state.installedChosenModel)
        XCTAssertEqual(coordinator.state.chosenModelName, ModelConfiguration.qwen_3_0_6b_4bit.name)
        XCTAssertEqual(coordinator.state.preparedModelName, ModelConfiguration.qwen_3_0_6b_4bit.name)
        XCTAssertTrue(coordinator.state.hasAttemptedFastFallback)
    }

    func testCoordinatorMapsModelSelectionToDisplayTitles() throws {
        let defaults = try makeDefaults()
        let coordinator = makeCoordinator(defaults: defaults)

        XCTAssertEqual(coordinator.selectedModelDisplayTitle, "Fast")

        coordinator.selectModel(ModelConfiguration.qwen_3_5_0_8b_optiq_4bit.name)
        XCTAssertEqual(coordinator.selectedModelDisplayTitle, "Smarter")

        coordinator.completeInstall(
            .failed(
                failedModelName: ModelConfiguration.qwen_3_0_6b_4bit.name,
                selectedModelRetryCount: 1,
                attemptedFastFallback: true
            )
        )
        XCTAssertEqual(coordinator.failedModelDisplayTitle, "Fast")
    }

    /// The tab is a chat screen now, not a wizard.
    ///
    /// No step counter, no progress bar, no close button — those belonged to a
    /// five-stage flow that no longer runs. Back and history do belong here.
    func testNavigationChromeIsTheCompletedChatChrome() throws {
        let defaults = try makeDefaults()
        let coordinator = makeCoordinator(defaults: defaults)

        XCTAssertEqual(
            coordinator.navigationChrome,
            EvaActivationNavigationChrome(
                screenTitle: "Eva",
                stepIndex: 0,
                stepCount: 5,
                showsProgress: false,
                showsTrailingHistoryButton: true,
                leadingActionStyle: .back
            )
        )
        XCTAssertEqual(coordinator.navigationChrome.progressFraction, 0)
        XCTAssertNil(coordinator.navigationChrome.progressAccessibilityValue)
    }

    func testNavigationChromeUsesSelectedMascotTitle() throws {
        let defaults = try makeDefaults()
        let workspaceStore = WorkspacePreferencesStore(defaults: defaults)
        workspaceStore.update { preferences in
            preferences.chiefOfStaffMascotID = .sato
        }
        let coordinator = makeCoordinator(defaults: defaults)

        // The mascot still names the screen; only the wizard framing is gone.
        XCTAssertEqual(coordinator.navigationChrome.screenTitle, "Sato")
    }

    func testLeadingNavigationRoutesBackThroughActivationStages() throws {
        let defaults = try makeDefaults()
        let coordinator = makeCoordinator(defaults: defaults)
        var dismissed = false

        coordinator.handleLeadingNavigation {
            dismissed = true
        }
        XCTAssertTrue(dismissed)

        dismissed = false
        coordinator.continueFromIntro()
        coordinator.handleLeadingNavigation {
            dismissed = true
        }
        XCTAssertFalse(dismissed)
        XCTAssertEqual(coordinator.state.stage, .intro)

        coordinator.continueFromIntro()
        coordinator.continueFromAboutYou()
        coordinator.handleLeadingNavigation {
            dismissed = true
        }
        XCTAssertEqual(coordinator.state.stage, .aboutYou)

        coordinator.continueFromAboutYou()
        coordinator.continueFromGoals()
        coordinator.handleLeadingNavigation {
            dismissed = true
        }
        XCTAssertEqual(coordinator.state.stage, .goals)
    }

    func testCloudSetupIsPrimaryAndOfflineSetupRemainsAvailable() throws {
        let defaults = try makeDefaults()
        let coordinator = makeCoordinator(defaults: defaults)

        coordinator.continueFromIntro()
        coordinator.continueFromAboutYou()
        coordinator.continueFromGoals()
        XCTAssertEqual(coordinator.state.stage, .cloudSetup)

        coordinator.chooseOfflineSetup()
        XCTAssertEqual(coordinator.state.stage, .modelChoice)

        coordinator.backToGoals()
        coordinator.continueFromGoals()
        coordinator.completeCloudSetup()
        XCTAssertEqual(coordinator.state.stage, .firstChat)
    }

    func testLeadingNavigationRoutesRecoveryToModelChoice() throws {
        let defaults = try makeDefaults()
        let coordinator = makeCoordinator(defaults: defaults)

        coordinator.selectModel(ModelConfiguration.qwen_3_5_0_8b_optiq_4bit.name)
        coordinator.completeInstall(
            .failed(
                failedModelName: ModelConfiguration.qwen_3_0_6b_4bit.name,
                selectedModelRetryCount: 1,
                attemptedFastFallback: true
            )
        )

        coordinator.handleLeadingNavigation {}

        XCTAssertEqual(coordinator.state.stage, .modelChoice)
        XCTAssertNil(coordinator.state.failedModelName)
    }

    func testInstallEstimatorKeepsEtaCalculatingUntilProgressStabilizes() {
        let samples = [
            EvaActivationInstallSample(timestamp: 0, progress: 0.03),
            EvaActivationInstallSample(timestamp: 0.7, progress: 0.06)
        ]

        let eta = EvaActivationInstallEstimator.etaState(
            for: samples,
            latestProgress: 0.06
        )

        XCTAssertEqual(eta, .calculating)
    }

    func testInstallEstimatorProducesStableEtaWhenProgressSamplesAdvance() {
        let samples = [
            EvaActivationInstallSample(timestamp: 0, progress: 0.10),
            EvaActivationInstallSample(timestamp: 3, progress: 0.28)
        ]

        let eta = EvaActivationInstallEstimator.etaState(
            for: samples,
            latestProgress: 0.28
        )

        XCTAssertEqual(eta, .ready(secondsRemaining: 12))
    }

    func testInstallEstimatorFormatsTransferProgressFromModelSize() {
        let transferText = EvaActivationInstallEstimator.transferText(
            for: Decimal(string: "0.41"),
            progress: 0.25
        )

        XCTAssertEqual(transferText, "105 MB of 420 MB")
    }

    func testChatRenderModelHidesVisibleThinkingButKeepsAnswer() {
        let renderModel = ChatMessageRenderModel(
            role: .assistant,
            originalContent: "<think>Reviewing tradeoffs</think>\nFinal answer: Focus on the highest-leverage task first.",
            displayContent: "<think>Reviewing tradeoffs</think>\nFinal answer: Focus on the highest-leverage task first.",
            sourceModelName: ModelConfiguration.qwen_3_0_6b_4bit.name
        )

        XCTAssertNil(renderModel.thinkingText)
        XCTAssertEqual(renderModel.answerText, "Final answer: Focus on the highest-leverage task first.")
    }

    private func makeCoordinator(defaults: UserDefaults) -> EvaActivationCoordinator {
        let appManager = AppManager()
        appManager.installedModels = []
        return EvaActivationCoordinator(
            appManager: appManager,
            defaults: defaults,
            workspacePreferencesStore: WorkspacePreferencesStore(defaults: defaults),
            deviceSupportsLocalEvaProvider: { true }
        )
    }

    private func makeDefaults() throws -> UserDefaults {
        let suiteName = "EvaActivationCoordinatorTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        addTeardownBlock {
            defaults.removePersistentDomain(forName: suiteName)
        }
        return defaults
    }
}

/// Intercepts every request made through its session so transport policy — how
/// many attempts a route gets, and for which failures — can be asserted without
/// a network.
final class EvaMemoryStoreV2Tests: XCTestCase {
    /// The provenance rule is the point of the type. A confident wrong guess
    /// must never silently replace something the person actually said, because
    /// then a fact they never agreed to becomes permanent and unfindable.
    func testAnInferenceCannotOverwriteAStatedPreference() {
        var store = EvaMemoryStoreV2()
        let stated = EvaMemoryStatement(
            section: .preferences, text: "I plan on Sunday evenings.", provenance: .userStated
        )
        store.upsert(stated)

        var guess = stated
        guess.text = "I plan on Monday mornings."
        guess.provenance = .inferred
        guess.confidence = 0.9
        store.upsert(guess)

        XCTAssertEqual(store.statements.count, 1)
        XCTAssertEqual(store.statements.first?.text, "I plan on Sunday evenings.")
        XCTAssertEqual(store.statements.first?.provenance, .userStated)
    }

    /// The person correcting EVA is exactly how an inference should end.
    func testAStatedPreferenceRevisesAnInferenceAndBumpsTheRevision() {
        var store = EvaMemoryStoreV2()
        let inferred = EvaMemoryStatement(
            section: .capacity, text: "Prefers short afternoons.", provenance: .inferred, confidence: 0.6
        )
        store.upsert(inferred)

        var corrected = inferred
        corrected.text = "Afternoons are for deep work."
        corrected.provenance = .userStated
        store.upsert(corrected)

        XCTAssertEqual(store.statements.count, 1)
        XCTAssertEqual(store.statements.first?.provenance, .userStated)
        XCTAssertEqual(store.statements.first?.revision, 2)
        XCTAssertNil(store.statements.first?.confidence, "A stated preference is not a guess")
    }

    func testMigrationFromV1TreatsOnboardingAnswersAsStated() {
        let v1 = LLMPersonalMemoryStoreV1(
            preferences: [.init(text: "Mornings are best")],
            routines: [.init(text: "Context switching breaks me")],
            currentGoals: [.init(text: "Ship the beta")]
        )
        let migrated = EvaMemoryStoreV2.migrating(from: v1)

        XCTAssertEqual(migrated.statements.count, 3)
        XCTAssertTrue(migrated.statements.allSatisfy { $0.provenance == .userStated })
        XCTAssertEqual(migrated.statements(in: .currentGoals).first?.text, "Ship the beta")
    }

    func testStatementTextIsCappedAndPayloadMirrorsTheContract() {
        var store = EvaMemoryStoreV2()
        store.upsert(EvaMemoryStatement(
            section: .boundaries,
            text: String(repeating: "x", count: EvaMemoryStoreV2.maxStatementCharacters + 200),
            provenance: .userStated
        ))
        XCTAssertEqual(store.statements.first?.text.count, EvaMemoryStoreV2.maxStatementCharacters)

        let payload = store.contextPayload()
        XCTAssertEqual(payload.first?.section, "boundaries")
        XCTAssertEqual(payload.first?.provenance, "userStated")
    }
}

final class EvaConversationSummaryTests: XCTestCase {
    private func thread(messageCount: Int) -> [LifeBoard.Message] {
        let thread = LifeBoard.Thread()
        for index in 0 ..< messageCount {
            thread.messages.append(LifeBoard.Message(
                role: index.isMultiple(of: 2) ? .user : .assistant,
                content: "turn \(index)",
                thread: thread
            ))
        }
        return thread.sortedMessages
    }

    func testShortThreadsAreNotSummarized() {
        // Nothing to compress while the turns still fit; summarizing early would
        // replace verbatim text with a lossy paraphrase for no benefit.
        XCTAssertTrue(EvaConversationSummary.overflow(thread(messageCount: 6), liveWindow: 4).isEmpty)
    }

    func testOverflowIsTheOldestTurnsOutsideTheLiveWindow() {
        let messages = thread(messageCount: 20)
        let overflow = EvaConversationSummary.overflow(messages, liveWindow: 8)

        XCTAssertEqual(overflow.count, 12)
        XCTAssertEqual(overflow.first?.content, "turn 0")
        XCTAssertEqual(overflow.last?.content, "turn 11")
    }

    func testSummaryRejectsEmptyContentAndCapsLength() {
        XCTAssertNil(EvaConversationSummary(summarizedTurnCount: 4, summary: "   "))
        XCTAssertNil(EvaConversationSummary(summarizedTurnCount: 0, summary: "something"))

        let long = EvaConversationSummary(
            summarizedTurnCount: 12,
            summary: String(repeating: "s", count: EvaConversationSummary.maxSummaryCharacters + 500)
        )
        XCTAssertEqual(long?.summary.count, EvaConversationSummary.maxSummaryCharacters)
        XCTAssertEqual(long?.section().category, .conversationSummary)
    }
}

final class EvaContextEnvelopeTests: XCTestCase {
    private func record(
        title: String,
        bucket: EvaTaskRecord.Bucket,
        priority: String = "none",
        deferredCount: Int = 0,
        replanCount: Int = 0,
        due: Date? = nil
    ) -> EvaTaskRecord {
        EvaTaskRecord(
            id: UUID(), title: title, project: nil, projectID: nil, lifeArea: nil,
            priority: priority, energy: nil, estimatedMinutes: nil, actualMinutes: nil,
            due: due, scheduledStart: nil, scheduledEnd: nil, bucket: bucket,
            deferredCount: deferredCount, replanCount: replanCount, ageDays: 0,
            notesExcerpt: nil, blockedBy: [], rankReasons: []
        )
    }

    private let emptyEvidence = EvaAuthorizedEvidenceContext.notProvided
    private let consent = EvaConsentPolicy(schemaVersion: 2, revision: 1, grants: [], updatedAt: Date())

    /// The gate for this whole change: the offline envelope is the v1 envelope.
    func testCompactModeProducesExactlyTheLegacySections() {
        let projection = "Planning context:\nSummary: 1 overdue, 2 today"
        let builder = EvaContextEnvelopeBuilder(budget: .offline(model: .qwen_3_0_6b_4bit))
        XCTAssertEqual(builder.mode, .compact)

        let built = builder.build(
            compactProjection: projection,
            tasks: [record(title: "Should not appear", bucket: .overdue)],
            summary: EvaPlanningSummary(overdue: 1, today: 2, tomorrow: 0, thisWeek: 0, unscheduled: 0, completedToday: 0),
            projects: [], lifeAreas: [],
            habits: [], partialSections: [],
            personalMemory: "User memory: prefers mornings",
            evidence: emptyEvidence, consent: consent
        )
        let legacy = EvaCloudContextProjection.sections(
            taskProjection: projection,
            executiveState: nil, slashCommandState: nil,
            personalMemory: "User memory: prefers mornings",
            evidence: emptyEvidence, consent: consent
        )

        XCTAssertEqual(built.sections.map(\.category), legacy.map(\.category))
        // No typed record may reach an on-device model, whatever it was handed.
        let encoded = String(decoding: (try? JSONEncoder.evaCloud.encode(built.sections.map(\.payload))) ?? Data(), as: UTF8.self)
        XCTAssertFalse(encoded.contains("Should not appear"))
        XCTAssertFalse(encoded.contains("deferredCount"))
    }

    func testRichModeEmitsTypedRecords() {
        let builder = EvaContextEnvelopeBuilder(budget: .cloud(inputTokenCap: 16_000, outputTokenCap: 2_048))
        XCTAssertEqual(builder.mode, .rich)

        let built = builder.build(
            compactProjection: "Planning context:",
            tasks: [record(title: "Write the launch note", bucket: .overdue, priority: "high", deferredCount: 4)],
            summary: EvaPlanningSummary(overdue: 1, today: 0, tomorrow: 0, thisWeek: 0, unscheduled: 0, completedToday: 0),
            projects: [], lifeAreas: [], habits: [], partialSections: [],
            personalMemory: nil, evidence: emptyEvidence, consent: consent
        )
        let encoded = String(decoding: (try? JSONEncoder.evaCloud.encode(built.sections.map(\.payload))) ?? Data(), as: UTF8.self)

        XCTAssertTrue(encoded.contains("Write the launch note"))
        // The field that changes the character of an answer.
        XCTAssertTrue(encoded.contains("\"deferredCount\":4"))
        XCTAssertTrue(encoded.contains("\"priority\":\"high\""))
    }

    /// Overflow drops whole records. A truncated object is invalid against the
    /// server schema, and a half-written identifier is worse than an absent one.
    func testOverflowDropsWholeRecordsLowestValueFirst() {
        let builder = EvaContextEnvelopeBuilder(budget: .cloud(inputTokenCap: 1_024, outputTokenCap: 256))
        let tasks = (0 ..< 300).map { index in
            record(title: "Backlog item \(index)", bucket: .unscheduled)
        } + [record(title: "Overdue and deferred", bucket: .overdue, priority: "max", deferredCount: 6)]

        let built = builder.build(
            compactProjection: "",
            tasks: tasks,
            summary: EvaPlanningSummary(overdue: 1, today: 0, tomorrow: 0, thisWeek: 0, unscheduled: 300, completedToday: 0),
            projects: [], lifeAreas: [], habits: [], partialSections: [],
            personalMemory: nil, evidence: emptyEvidence, consent: consent
        )
        let data = (try? JSONEncoder.evaCloud.encode(built.sections.map(\.payload))) ?? Data()
        let encoded = String(decoding: data, as: UTF8.self)

        XCTAssertTrue(encoded.contains("Overdue and deferred"), "The most valuable record must survive")
        XCTAssertLessThan(data.count, 4_096 * 2)
        // Still parseable: nothing was cut mid-object.
        XCTAssertNoThrow(try JSONSerialization.jsonObject(with: data))
    }

    func testCacheFriendlyOrderPutsSlowMovingSectionsFirst() {
        let envelope = EvaContextEnvelope(sections: [
            .init(category: .planning, payload: .string("a")),
            .init(category: .goals, payload: .string("b")),
            .init(category: .personalMemory, payload: .string("c")),
        ])
        XCTAssertEqual(envelope.ordered().map(\.category), [.personalMemory, .goals, .planning])
    }
}

final class EvaContextBudgetTests: XCTestCase {
    private func configuration(
        cloudState: EvaCloudRuntimeConfiguration.CloudState = .enabled,
        chatEnabled: Bool = true,
        inputTokenCap: Int = 16_000
    ) -> EvaCloudRuntimeConfiguration {
        EvaCloudRuntimeConfiguration(
            schemaVersion: 2,
            version: 10,
            issuedAt: Date(),
            environment: "staging",
            cloudState: cloudState,
            ttsEnabled: false,
            maintenanceMessage: nil,
            offlineRecoveryPolicy: "offerTryOffline",
            textModel: "gpt-5.6-luna",
            speechModel: "tts-1",
            speechVoice: "nova",
            minimumClientVersion: "2.1.0",
            contractVersions: [1, 2],
            routes: [
                .chat: .init(
                    enabled: chatEnabled,
                    inputTokenCap: inputTokenCap,
                    outputTokenCap: 2_048,
                    reasoning: "low",
                    billable: true,
                    structured: false
                ),
            ]
        )
    }

    /// The offline ceiling is correct for a 0.6B model on a phone. Nothing in
    /// this work is allowed to move it.
    func testOfflineBudgetReproducesThePerModelTable() {
        let model = ModelConfiguration.qwen_3_0_6b_4bit
        let budget = EvaContextBudget.offline(model: model)

        XCTAssertEqual(budget.provider, .offline)
        XCTAssertEqual(budget.inputTokens, 1_536)
        XCTAssertEqual(budget.taskContextTokens, 360)
        XCTAssertEqual(budget.personalMemoryTokens, 120)
        XCTAssertEqual(budget.executiveContextTokens, 160)
        XCTAssertEqual(budget.slashContextTokens, 180)
        XCTAssertEqual(budget.historyMessageLimit, 8)
    }

    func testCloudBudgetReadsThePublishedRouteCap() {
        let budget = EvaContextBudget.resolve(
            route: .chat,
            modelName: EvaModelSelection.cloudSentinel,
            offlineModel: .qwen_3_0_6b_4bit,
            runtimeConfiguration: configuration(),
            cloudIsReady: true
        )

        XCTAssertEqual(budget.provider, .cloud)
        XCTAssertEqual(budget.inputTokens, 16_000)
        XCTAssertEqual(budget.taskContextTokens, 8_000)
        XCTAssertGreaterThan(budget.historyMessageLimit, 8)
        // The whole point: an order of magnitude more room than the phone budget.
        XCTAssertGreaterThan(budget.taskContextTokens, EvaContextBudget.offline(model: .qwen_3_0_6b_4bit).taskContextTokens * 10)
    }

    /// Every way of failing to confirm a cloud turn must yield the small budget.
    /// Handing a cloud-sized envelope to an on-device model is the one outcome
    /// that would exhaust memory on a phone, so ambiguity resolves downward.
    func testBudgetFailsClosedToOfflineOnEveryUnconfirmedPath() {
        let offline = EvaContextBudget.offline(model: .qwen_3_0_6b_4bit)
        let cases: [(String, EvaContextBudget)] = [
            ("an installed local model", EvaContextBudget.resolve(
                route: .chat, modelName: ModelConfiguration.qwen_3_0_6b_4bit.name,
                offlineModel: .qwen_3_0_6b_4bit, runtimeConfiguration: configuration(), cloudIsReady: true)),
            ("no resolved model", EvaContextBudget.resolve(
                route: .chat, modelName: nil,
                offlineModel: .qwen_3_0_6b_4bit, runtimeConfiguration: configuration(), cloudIsReady: true)),
            ("no verified configuration", EvaContextBudget.resolve(
                route: .chat, modelName: EvaModelSelection.cloudSentinel,
                offlineModel: .qwen_3_0_6b_4bit, runtimeConfiguration: nil, cloudIsReady: true)),
            ("cloud not ready", EvaContextBudget.resolve(
                route: .chat, modelName: EvaModelSelection.cloudSentinel,
                offlineModel: .qwen_3_0_6b_4bit, runtimeConfiguration: configuration(), cloudIsReady: false)),
            ("cloud disabled", EvaContextBudget.resolve(
                route: .chat, modelName: EvaModelSelection.cloudSentinel,
                offlineModel: .qwen_3_0_6b_4bit, runtimeConfiguration: configuration(cloudState: .disabled), cloudIsReady: true)),
            ("route disabled", EvaContextBudget.resolve(
                route: .chat, modelName: EvaModelSelection.cloudSentinel,
                offlineModel: .qwen_3_0_6b_4bit, runtimeConfiguration: configuration(chatEnabled: false), cloudIsReady: true)),
            ("route absent from policy", EvaContextBudget.resolve(
                route: .plan, modelName: EvaModelSelection.cloudSentinel,
                offlineModel: .qwen_3_0_6b_4bit, runtimeConfiguration: configuration(), cloudIsReady: true)),
        ]

        for (reason, budget) in cases {
            XCTAssertEqual(budget, offline, "Expected the offline budget for: \(reason)")
        }
    }

    func testCloudHistoryClipsByTokensAndKeepsChronologicalOrder() {
        let thread = LifeBoard.Thread()
        for index in 0 ..< 40 {
            thread.messages.append(Message(
                role: index.isMultiple(of: 2) ? .user : .assistant,
                content: String(repeating: "w", count: 400),
                thread: thread
            ))
        }
        let sorted = thread.sortedMessages

        // 100 tokens per message at the 4-chars-per-token estimate, so a 1,000
        // token allowance keeps ten of them — a count limit alone would not.
        let clipped = EvaCloudHistoryClipper.clip(sorted, maxMessages: 64, maxTokens: 1_000)
        XCTAssertEqual(clipped.count, 10)
        XCTAssertEqual(clipped.last?.content, sorted.last?.content, "Newest turn must survive")

        XCTAssertEqual(EvaCloudHistoryClipper.clip(sorted, maxMessages: 3, maxTokens: 100_000).count, 3)
        XCTAssertTrue(EvaCloudHistoryClipper.clip(sorted, maxMessages: 0, maxTokens: 1_000).isEmpty)
        XCTAssertTrue(EvaCloudHistoryClipper.clip(sorted, maxMessages: 64, maxTokens: 0).isEmpty)
    }
}

final class EvaRouteContextSectionsTests: XCTestCase {
    /// The Worker authorizes a structured result's identifiers by scanning
    /// `request.context` only. These assertions pin the payload shape that the
    /// TypeScript side reads back in
    /// `Shared/EVACloudContracts/src/contracts.test.ts`; if this shape changes
    /// without that test changing, plan and top-three results start failing
    /// semantic validation in production instead of in CI.
    func testPlanningSectionCarriesProjectionUnderPlanningCategory() throws {
        let taskID = UUID()
        let projection = #"{"task_id":"\#(taskID.uuidString)","title":"Ship the beta"}"#

        let sections = EvaRouteContextSections.planning(
            projection: projection,
            kind: .topThree,
            modelName: EvaModelSelection.cloudSentinel
        )

        XCTAssertEqual(sections.count, 1)
        let section = try XCTUnwrap(sections.first)
        XCTAssertEqual(section.category, .planning)
        guard case .object(let payload) = section.payload else {
            return XCTFail("Expected an object payload")
        }
        XCTAssertEqual(payload["kind"], .string("topThree"))
        guard case .string(let carried)? = payload["taskProjection"] else {
            return XCTFail("Expected the projection to be carried as a string")
        }
        XCTAssertTrue(carried.contains(taskID.uuidString))
    }

    func testPlanningSectionIsOmittedWhenProjectionIsBlank() {
        let cloud = EvaModelSelection.cloudSentinel
        XCTAssertTrue(EvaRouteContextSections.planning(projection: "", kind: .plan, modelName: cloud).isEmpty)
        XCTAssertTrue(EvaRouteContextSections.planning(projection: "   \n  ", kind: .plan, modelName: cloud).isEmpty)
    }

    /// The projection travels in exactly one place. Offline keeps it in the
    /// prompt and sends no envelope; cloud does the reverse. Both carrying it and
    /// inlining it would pay for the payload twice.
    func testProjectionTravelsInExactlyOnePlacePerProvider() {
        let offline = ModelConfiguration.qwen_3_0_6b_4bit.name
        let cloud = EvaModelSelection.cloudSentinel
        let projection = "Projects:\n- Launch"

        XCTAssertTrue(EvaRouteContextSections.planning(projection: projection, kind: .plan, modelName: offline).isEmpty)
        XCTAssertEqual(
            EvaRouteContextSections.inlining(projection, into: "header", modelName: offline),
            "header\n\nProjects:\n- Launch"
        )

        XCTAssertFalse(EvaRouteContextSections.planning(projection: projection, kind: .plan, modelName: cloud).isEmpty)
        XCTAssertEqual(EvaRouteContextSections.inlining(projection, into: "header", modelName: cloud), "header")
    }

    func testInliningLeavesHeaderUntouchedForABlankProjection() {
        let offline = ModelConfiguration.qwen_3_0_6b_4bit.name
        XCTAssertEqual(EvaRouteContextSections.inlining("  \n ", into: "header", modelName: offline), "header")
    }

    func testCloudSentinelIsNotAnInstallableModel() {
        // The sentinel deliberately does not resolve, which is why anything that
        // treats a model name as proof of a local runtime has to test for it.
        XCTAssertNil(ModelConfiguration.getModelByName(EvaModelSelection.cloudSentinel))
        XCTAssertTrue(EvaModelSelection.isCloud(EvaModelSelection.cloudSentinel))
        XCTAssertFalse(EvaModelSelection.isCloud(ModelConfiguration.qwen_3_0_6b_4bit.name))
        XCTAssertFalse(EvaModelSelection.isCloud(nil))
    }
}

final class EvaStubURLProtocol: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var responder: (@Sendable (Int) -> Result<(status: Int, body: Data), Error>)?
    nonisolated(unsafe) private static var paths: [String] = []

    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [EvaStubURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    static func reset() {
        lock.lock()
        defer { lock.unlock() }
        responder = nil
        paths = []
    }

    /// The closure receives the 1-based attempt number so a test can fail the
    /// first call and satisfy the second.
    static func respond(_ handler: @escaping @Sendable (Int) -> Result<(status: Int, body: Data), Error>) {
        lock.lock()
        defer { lock.unlock() }
        responder = handler
    }

    static var recordedPaths: [String] {
        lock.lock()
        defer { lock.unlock() }
        return paths
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lock.lock()
        Self.paths.append(request.url?.path ?? "")
        let outcome = Self.responder?(Self.paths.count) ?? .success((200, Data("{}".utf8)))
        Self.lock.unlock()

        switch outcome {
        case .success(let stubbed):
            let response = HTTPURLResponse(
                url: request.url ?? URL(string: "https://eva.invalid")!,
                statusCode: stubbed.status,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: stubbed.body)
            client?.urlProtocolDidFinishLoading(self)
        case .failure(let error):
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
