import XCTest
@testable import LifeBoard

/// Milestone 1: the shared evidence contract. Verifies the deterministic authorization,
/// redaction, and freshness rules plus additive Codable round-tripping of NormalizedLifeEvent.
final class LifeBoardEvidenceContractTests: XCTestCase {
    private let policy = EvidenceAuthorizationPolicy()

    func testJournalIsNeverAllowedIntoEvaOrInsightsByDefault() {
        let destinations = policy.allowedDestinations(domain: "journal", sensitivity: .privateSensitive)
        XCTAssertFalse(destinations.contains(.eva))
        XCTAssertFalse(destinations.contains(.insights))
        XCTAssertTrue(destinations.contains(.track))
    }

    func testRestrictedSensitiveDomainsStayOffInsights() {
        for domain in ["mood", "medication", "care"] {
            let destinations = policy.allowedDestinations(domain: domain, sensitivity: .privateSensitive)
            XCTAssertFalse(destinations.contains(.insights), "\(domain) should not reach Insights by default")
        }
        XCTAssertTrue(policy.allowedDestinations(domain: "hydration", sensitivity: .privateStandard).contains(.insights))
    }

    func testEvaReceivesActionEvidenceButNotSensitiveHealthDomainsByDefault() {
        for domain in ["task", "plan", "focus", "habit", "routine", "goal"] {
            XCTAssertTrue(
                policy.allowedDestinations(domain: domain, sensitivity: .privateStandard).contains(.eva),
                "\(domain) should be available to Eva as normalized action evidence"
            )
        }
        for domain in ["journal", "mood", "sleep", "medication", "care", "hydration"] {
            XCTAssertFalse(
                policy.allowedDestinations(domain: domain, sensitivity: .privateSensitive).contains(.eva),
                "\(domain) requires a separate consent path"
            )
        }
    }

    func testJournalEvidenceRequiresConsentForEva() {
        XCTAssertEqual(
            policy.authorization(domain: "journal", destination: .eva, sensitivity: .privateSensitive, journalConsentGranted: false),
            .requiresConsent
        )
        XCTAssertEqual(
            policy.authorization(domain: "journal", destination: .eva, sensitivity: .privateSensitive, journalConsentGranted: true),
            .authorized
        )
    }

    func testRedactionSummarizesSensitiveDataOnExternalSurfaces() {
        XCTAssertEqual(policy.redaction(sensitivity: .privateSensitive, destination: .insights), .sensitiveSummary)
        XCTAssertEqual(policy.redaction(sensitivity: .privateSensitive, destination: .eva), .sensitiveSummary)
        XCTAssertEqual(policy.redaction(sensitivity: .privateSensitive, destination: .home), .none)
        XCTAssertEqual(policy.redaction(sensitivity: .privateStandard, destination: .eva), .none)
    }

    func testFreshnessGoesStalePastThreshold() {
        let now = Date(timeIntervalSince1970: 1_762_041_600)
        let recent = now.addingTimeInterval(-60 * 60)
        let old = now.addingTimeInterval(-EvidenceAuthorizationPolicy.freshnessThreshold(domain: "mood") - 60)
        XCTAssertEqual(policy.freshness(domain: "mood", occurredAt: recent, now: now), .complete)
        XCTAssertEqual(policy.freshness(domain: "mood", occurredAt: old, now: now), .stale)
    }

    func testNormalizedLifeEventRoundTripsNewEvidenceFields() throws {
        let day = PlanningDay(date: Date(timeIntervalSince1970: 1_762_041_600), timeZone: TimeZone(identifier: "UTC")!)
        let receiptID = UUID()
        let event = NormalizedLifeEvent(
            id: "goal:test", sourceID: UUID(), domain: "goal", kind: "progress",
            occurredAt: Date(timeIntervalSince1970: 1_762_041_600), localDay: day,
            numericValue: 0.5, completeness: .complete, sensitivity: .privateStandard,
            allowedDestinations: [.home, .insights], provenance: "test",
            evidence: [EvidenceReference(sourceID: UUID(), kind: "goal", display: "Goal")],
            freshness: .stale, authorization: .authorized, redaction: .sensitiveSummary,
            receipt: MutationReceiptReference(receiptID: receiptID, summary: "linked"),
            reversal: .reversible(receiptID: receiptID)
        )
        let data = try JSONEncoder().encode(event)
        let decoded = try JSONDecoder().decode(NormalizedLifeEvent.self, from: data)
        XCTAssertEqual(decoded, event)
        XCTAssertEqual(decoded.freshness, .stale)
        XCTAssertEqual(decoded.reversal, .reversible(receiptID: receiptID))
        XCTAssertEqual(decoded.evidence.first?.kind, "goal")
    }

    func testSharedEventProjectorProducesStableEvidenceAuthorizationFreshnessAndReceipts() throws {
        let sourceID = UUID()
        let receiptID = UUID()
        let occurredAt = Date(timeIntervalSince1970: 1_000)
        let projector = NormalizedLifeEventProjector(timeZone: try XCTUnwrap(TimeZone(identifier: "Asia/Kolkata")))
        let event = projector.event(
            sourceID: sourceID,
            domain: "plan",
            kind: "scheduled",
            occurredAt: occurredAt,
            numericValue: 1_800,
            provenance: "Planning receipt",
            evidenceDisplay: "Deep work",
            receipt: .init(receiptID: receiptID, summary: "Schedule Deep work"),
            reversal: .reversible(receiptID: receiptID),
            now: occurredAt.addingTimeInterval(90_000)
        )

        XCTAssertEqual(event.sourceID, sourceID)
        XCTAssertEqual(event.evidence, [.init(sourceID: sourceID, kind: "plan", display: "Deep work")])
        XCTAssertEqual(event.allowedDestinations, [.home, .plan, .insights, .eva])
        XCTAssertEqual(event.freshness, .stale)
        XCTAssertEqual(event.receipt?.receiptID, receiptID)
        XCTAssertEqual(event.reversal, .reversible(receiptID: receiptID))
        XCTAssertEqual(event.localDay.timeZoneIdentifier, "Asia/Kolkata")
    }

    func testTypedSourceKindMapsToStableSlugs() {
        XCTAssertEqual(TypedSourceKind.trackerMeasure.title, "Tracker")
        XCTAssertEqual(TypedSourceKind.allCases.count, 5)
    }

    private func event(domain: String, sensitivity: DataSensitivity, destinations: Set<Destination>) -> NormalizedLifeEvent {
        let day = PlanningDay(date: Date(timeIntervalSince1970: 1_762_041_600), timeZone: TimeZone(identifier: "UTC")!)
        return NormalizedLifeEvent(
            id: "\(domain):x", sourceID: UUID(), domain: domain, kind: "k",
            occurredAt: Date(timeIntervalSince1970: 1_762_041_600), localDay: day,
            numericValue: nil, completeness: .complete, sensitivity: sensitivity,
            allowedDestinations: destinations, provenance: "test"
        )
    }

    func testProjectionRepositoryFiltersByDestinationAuthorization() {
        let events = [
            event(domain: "hydration", sensitivity: .privateStandard, destinations: [.home, .track, .insights]),
            event(domain: "mood", sensitivity: .privateSensitive, destinations: [.home, .track]),
            event(domain: "goal", sensitivity: .privateStandard, destinations: [.home, .track, .insights, .eva])
        ]
        let repo = SnapshotLifeEventProjectionRepository(events: events)
        let insights = repo.authorizedEvents(for: .insights, journalConsentGranted: false)
        XCTAssertEqual(Set(insights.map(\.domain)), ["hydration", "goal"])
        XCTAssertFalse(insights.contains { $0.domain == "mood" }, "Sensitive mood must not reach Insights")
        XCTAssertEqual(repo.authorizedEvents(for: .eva, journalConsentGranted: false).map(\.domain), ["goal"])
    }

    func testProjectionRepositoryGatesJournalOnConsentAndRedactsForEva() {
        // Journal's stored event remains Track-only. Explicit consent creates a redacted Eva
        // projection without mutating the source event or its default authorization set.
        let events = [event(domain: "journal", sensitivity: .privateSensitive, destinations: [.track])]
        let repo = SnapshotLifeEventProjectionRepository(events: events)
        XCTAssertTrue(repo.authorizedEvents(for: .eva, journalConsentGranted: false).isEmpty)
        let consented = repo.authorizedEvents(for: .eva, journalConsentGranted: true)
        XCTAssertEqual(consented.count, 1)
        XCTAssertEqual(consented.first?.redaction, .sensitiveSummary)
    }

    func testEvaSensitiveEvidenceRequiresPerDomainOptIn() {
        let events = [
            event(domain: "hydration", sensitivity: .privateStandard, destinations: [.home, .track, .insights]),
            event(domain: "mood", sensitivity: .privateSensitive, destinations: [.home, .track]),
            event(domain: "medication", sensitivity: .privateSensitive, destinations: [.home, .track])
        ]
        let repo = SnapshotLifeEventProjectionRepository(events: events)
        XCTAssertTrue(repo.authorizedEvents(for: .eva, sharingPolicy: EvaEvidenceSharingPolicy()).isEmpty)

        let bodyOnly = repo.authorizedEvents(
            for: .eva,
            sharingPolicy: EvaEvidenceSharingPolicy(permitsBody: true)
        )
        XCTAssertEqual(bodyOnly.map(\.domain), ["hydration"])

        let sensitive = repo.authorizedEvents(
            for: .eva,
            sharingPolicy: EvaEvidenceSharingPolicy(permitsMood: true, permitsCare: true)
        )
        XCTAssertEqual(Set(sensitive.map(\.domain)), ["mood", "medication"])
        XCTAssertTrue(sensitive.allSatisfy { $0.redaction == .sensitiveSummary })
    }

    func testEvaEvidenceSharingPolicyDefaultsOffAndRecoversMalformedStorage() throws {
        let suite = "LifeBoardEvidenceContractTests.eva-policy.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        XCTAssertEqual(EvaEvidenceSharingPolicyPersistence.load(from: defaults), EvaEvidenceSharingPolicy())
        let enabled = EvaEvidenceSharingPolicy(permitsBody: true, permitsMood: true, permitsCare: true)
        try EvaEvidenceSharingPolicyPersistence.save(enabled, to: defaults)
        XCTAssertEqual(EvaEvidenceSharingPolicyPersistence.load(from: defaults), enabled)

        defaults.set(Data("not-json".utf8), forKey: EvaEvidenceSharingPolicyPersistence.defaultsKey)
        XCTAssertEqual(EvaEvidenceSharingPolicyPersistence.load(from: defaults), EvaEvidenceSharingPolicy())
    }

    func testEvaEvidencePromptUsesStableCitationsAndRedactsSensitiveContent() throws {
        let now = Date(timeIntervalSince1970: 1_762_041_600)
        let standardID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        let sensitiveID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        let standard = NormalizedLifeEvent(
            id: "goal:progress", sourceID: standardID, domain: "goal", kind: "progress",
            occurredAt: now, localDay: PlanningDay(date: now, timeZone: TimeZone(secondsFromGMT: 0)!), numericValue: 0.5,
            completeness: .partial, sensitivity: .privateStandard, allowedDestinations: [.eva],
            provenance: "Goal repository",
            evidence: [.init(sourceID: standardID, kind: "goal", display: "Ship LifeBoard")],
            freshness: .stale, authorization: .authorized, redaction: .none
        )
        let sensitive = NormalizedLifeEvent(
            id: "journal:reflection", sourceID: sensitiveID, domain: "journal", kind: "reflection",
            occurredAt: now, localDay: PlanningDay(date: now, timeZone: TimeZone(secondsFromGMT: 0)!), numericValue: 9,
            completeness: .complete, sensitivity: .privateSensitive, allowedDestinations: [.eva],
            provenance: "Private journal",
            evidence: [.init(sourceID: sensitiveID, kind: "journal", display: "secret journal sentence")],
            freshness: .complete, authorization: .authorized, redaction: .sensitiveSummary
        )
        let context = EvaAuthorizedEvidenceContext(
            availability: .ready,
            events: [sensitive, standard],
            withheldDomains: ["mood"]
        )
        let prompt = try XCTUnwrap(context.promptBlock())

        XCTAssertTrue(prompt.contains("[LB-AAAAAAAA]"))
        XCTAssertTrue(prompt.contains("freshness=stale"))
        XCTAssertTrue(prompt.contains("completeness=partial"))
        XCTAssertTrue(prompt.contains("Ship LifeBoard"))
        XCTAssertTrue(prompt.contains("[LB-11111111]"))
        XCTAssertTrue(prompt.contains("source=sensitive summary"))
        XCTAssertFalse(prompt.contains("secret journal sentence"))
        XCTAssertFalse(prompt.contains("value=9"))
        XCTAssertTrue(prompt.contains("Withheld domains: mood"))

        let citations = context.citations(
            in: "A goal update [LB-AAAAAAAA] and private reflection [LB-11111111]. Duplicate [LB-AAAAAAAA]. Unknown [LB-DEADBEEF]."
        )
        XCTAssertEqual(citations.map(\.id), ["LB-AAAAAAAA", "LB-11111111"])
        XCTAssertEqual(citations.first?.label, "Ship LifeBoard")
        XCTAssertEqual(citations.last?.label, "Journal evidence")
        XCTAssertEqual(citations.last?.reference.sourceID, sensitiveID)

        let injected = context.injecting(into: #"{"tasks":[]}"#)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(injected.utf8)) as? [String: Any])
        XCTAssertNotNil(object["authorized_lifeboard_evidence"])
        XCTAssertNotNil(object["tasks"])
    }
}

final class EvaCloudWireContractTests: XCTestCase {
    func testAppleExchangeRequestMatchesSharedFixture() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let fixtureURL = repositoryRoot.appending(path: "Shared/EVACloudContracts/fixtures/apple-auth-exchange-v1.json")
        let fixtureData = try Data(contentsOf: fixtureURL)
        let request = try JSONDecoder.evaCloud.decode(EvaAppleExchangeRequestV1.self, from: fixtureData)

        XCTAssertEqual(request.challengeId.uuidString, "11111111-1111-4111-8111-111111111111")
        XCTAssertEqual(request.installationId.uuidString, "22222222-2222-4222-8222-222222222222")
        XCTAssertEqual(request.platform, "ios")

        let encodedObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder.evaCloud.encode(request)) as? NSDictionary
        )
        let fixtureObject = try XCTUnwrap(JSONSerialization.jsonObject(with: fixtureData) as? NSDictionary)
        XCTAssertEqual(encodedObject, fixtureObject)
    }

    func testAdultEligibilityRequestPreservesExplicitNullLowerBound() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let fixtureURL = repositoryRoot.appending(path: "Shared/EVACloudContracts/fixtures/adult-eligibility-v1.json")
        let fixtureData = try Data(contentsOf: fixtureURL)
        let request = try JSONDecoder.evaCloud.decode(EvaAdultEligibilityRequestV1.self, from: fixtureData)

        XCTAssertEqual(request.declaration, "unavailable")
        XCTAssertNil(request.lowerBound)

        let encodedObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder.evaCloud.encode(request)) as? NSDictionary
        )
        let fixtureObject = try XCTUnwrap(JSONSerialization.jsonObject(with: fixtureData) as? NSDictionary)
        XCTAssertEqual(encodedObject, fixtureObject)
        XCTAssertEqual(encodedObject["lowerBound"] as? NSNull, NSNull())
    }

    func testSharedStructuredFixturesDecodeThroughSwiftWireValue() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let fixtureURL = repositoryRoot.appending(path: "Shared/EVACloudContracts/fixtures/structured-results-v1.json")
        let fixtures = try JSONDecoder.evaCloud.decode(
            [String: EvaJSONValue].self,
            from: Data(contentsOf: fixtureURL)
        )
        XCTAssertEqual(
            Set(fixtures.keys),
            Set(["plan", "planRepair", "fieldSuggestion", "topThree", "taskBreakdown", "dailyBrief", "universalInputClassification", "dynamicChips"])
        )
        XCTAssertNoThrow(try JSONEncoder.evaCloud.encode(fixtures))
    }

    private func makeInferenceRequest(
        requestID: UUID,
        installationID: UUID,
        userInstructions: EvaUserInstructions? = nil
    ) -> EvaInferenceRequest {
        EvaInferenceRequest(
            requestId: requestID,
            route: .chat,
            contractVersion: EvaInferenceRequest.contractVersion,
            locale: "en_US",
            timeZone: "Asia/Kolkata",
            messages: [.init(role: .user, content: "Help me plan today.")],
            context: [.init(category: .planning, payload: .object(["tasks": .array([])]))],
            userInstructions: userInstructions,
            clientVersion: "1.0",
            platform: "ios",
            installationId: installationID,
            consentRevision: 3,
            providerCapabilities: .init(streaming: true, structuredOutput: true, spokenOutput: true)
        )
    }

    func testInferenceRequestEncodesTheSharedWireShape() throws {
        let requestID = UUID(uuidString: "11111111-1111-4111-8111-111111111111")!
        let installationID = UUID(uuidString: "22222222-2222-4222-8222-222222222222")!

        let data = try JSONEncoder.evaCloud.encode(
            makeInferenceRequest(requestID: requestID, installationID: installationID)
        )
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["requestId"] as? String, requestID.uuidString)
        XCTAssertEqual(object["route"] as? String, "chat")
        XCTAssertEqual(object["contractVersion"] as? Int, 2)
        XCTAssertEqual(object["installationId"] as? String, installationID.uuidString)
        // The client still names no model and composes no system prompt: both
        // live in the Worker so they can be corrected without an app release.
        XCTAssertNil(object["model"])
        XCTAssertNil(object["systemPrompt"])
        XCTAssertNil(object["creditCharge"])
        // Absent rather than null, so the strict server schema accepts it.
        XCTAssertNil(object["userInstructions"])
    }

    func testInferenceRequestCarriesTheCustomizedPromptOnly() async throws {
        let requestID = UUID(uuidString: "11111111-1111-4111-8111-111111111111")!
        let installationID = UUID(uuidString: "22222222-2222-4222-8222-222222222222")!
        let instructions = try XCTUnwrap(EvaUserInstructions(persona: "Be blunt. No preamble."))

        let data = try JSONEncoder.evaCloud.encode(makeInferenceRequest(
            requestID: requestID,
            installationID: installationID,
            userInstructions: instructions
        ))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let carried = try XCTUnwrap(object["userInstructions"] as? [String: Any])
        XCTAssertEqual(carried["persona"] as? String, "Be blunt. No preamble.")

        // A built-in default is not the person's own voice, so it is never sent:
        // the server already states EVA's persona and a second copy would
        // compete with it.
        // Read the MainActor-isolated defaults once, outside the assertion
        // autoclosures, which are nonisolated.
        let builtInDefault = await MainActor.run { AppManager.defaultSystemPrompt }
        let builtInPrompts = await MainActor.run {
            AppManager.legacyBuiltInSystemPrompts.union([AppManager.defaultSystemPrompt])
        }
        XCTAssertNil(EvaUserInstructions.customized(
            storedPrompt: builtInDefault,
            builtInPrompts: builtInPrompts
        ))
        XCTAssertNil(EvaUserInstructions.customized(storedPrompt: "   ", builtInPrompts: []))
        XCTAssertEqual(
            EvaUserInstructions.customized(storedPrompt: "Speak plainly.", builtInPrompts: [])?.persona,
            "Speak plainly."
        )
    }

    func testUserInstructionsAreCappedAtTheServerLimit() throws {
        let overlong = String(repeating: "a", count: EvaUserInstructions.maxPersonaCharacters + 500)
        let instructions = try XCTUnwrap(EvaUserInstructions(persona: overlong))
        // Trimming here keeps an over-long prompt from failing the whole request
        // at admission with `schema_invalid`.
        XCTAssertEqual(instructions.persona.count, EvaUserInstructions.maxPersonaCharacters)
    }

    func testStableErrorAndCreditDatesDecodeFromBackendJSON() throws {
        let json = #"{"code":"insufficient_credits","message":"No cloud credits are available yet.","requestId":"request-1","retryable":false,"recoveryAction":"tryOffline","credits":{"balance":0,"capacity":100,"refillAmount":20,"nextRefillAt":"2026-08-15T10:00:00Z"}}"#
        let error = try JSONDecoder.evaCloud.decode(EvaErrorEnvelope.self, from: Data(json.utf8))
        XCTAssertEqual(error.code, "insufficient_credits")
        XCTAssertEqual(error.credits?.balance, 0)
        XCTAssertEqual(error.recoveryAction, "tryOffline")
    }

    func testRemoteContextPolicyV2RemainsDenyByDefault() {
        let policy = RemoteEvaContextPolicy(accountID: "account-1")
        XCTAssertEqual(policy.schemaVersion, 2)
        XCTAssertFalse(policy.isRemoteEvaEnabled)
        XCTAssertTrue(policy.grantedCategories.isEmpty)
        XCTAssertFalse(policy.permits(.personalMemory, forAccountID: "account-1"))
    }
}
