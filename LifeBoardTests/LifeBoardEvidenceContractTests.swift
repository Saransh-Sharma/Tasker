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

    func testSensitiveDomainsStayOffInsights() {
        for domain in ["mood", "sleep", "medication", "care"] {
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

    private func event(domain: String, sensitivity: DataSensitivity, destinations: Set<LifeBoardDestination>) -> NormalizedLifeEvent {
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
