import XCTest
@testable import LifeBoard

final class EvaMemoryStoreV3Tests: XCTestCase {
    func testMigrationPrioritizesStatedMemoryDeduplicatesAndCapsAtThirty() {
        let old = (0 ..< 35).map { index in
            EvaMemoryStatement(
                section: .routines,
                text: index == 34 ? "  Same   durable fact " : "Inferred fact \(index)",
                provenance: .inferred,
                confidence: 0.7,
                effectiveFrom: Date(timeIntervalSince1970: TimeInterval(index))
            )
        } + [
            EvaMemoryStatement(
                section: .preferences,
                text: "same durable fact",
                provenance: .userStated,
                effectiveFrom: Date(timeIntervalSince1970: 1)
            ),
            EvaMemoryStatement(
                section: .boundaries,
                text: String(repeating: "x", count: 400),
                provenance: .userStated,
                effectiveFrom: Date(timeIntervalSince1970: 2)
            ),
        ]

        let migrated = EvaMemoryStoreV3.migrating(from: EvaMemoryStoreV2(statements: old))

        XCTAssertEqual(migrated.statements.count, 30)
        XCTAssertTrue(migrated.statements.prefix(2).allSatisfy { $0.provenance == .userStated })
        XCTAssertEqual(migrated.statements.filter {
            $0.text.lowercased().contains("same durable fact")
        }.count, 1)
        XCTAssertTrue(migrated.statements.allSatisfy { $0.text.count <= 240 })
    }

    func testCandidateLaterDismissSuppressionAndExpiry() {
        let now = Date(timeIntervalSince1970: 10_000)
        let candidate = EvaMemoryCandidate(
            section: .capacity,
            text: "Protect Friday afternoons",
            createdAt: now
        )
        var inbox = EvaMemoryCandidateInbox()
        inbox.propose(candidate, now: now)
        inbox.deferCandidate(id: candidate.id)
        XCTAssertEqual(inbox.pending.first?.state, .later)

        inbox.dismiss(id: candidate.id)
        inbox.propose(candidate, now: now)
        XCTAssertTrue(inbox.pending.isEmpty)

        let expiring = EvaMemoryCandidate(
            section: .routines,
            text: "Plan on Sundays",
            createdAt: now.addingTimeInterval(-31 * 24 * 60 * 60)
        )
        inbox.propose(expiring, now: now)
        XCTAssertTrue(inbox.pending.isEmpty)
    }
}

final class EvaContextReceiptAndExclusionTests: XCTestCase {
    func testGlobalAllocatorStaysWithinItsReservedEnvelopeAndDropsWholeRecords() throws {
        let records = (0 ..< 200).map { index in
            EvaJSONValue.object([
                "id": .string(String(format: "record-%03d", index)),
                "title": .string(String(repeating: "work ", count: 30)),
            ])
        }
        let budget = EvaContextBudget.cloud(inputTokenCap: 2_048, outputTokenCap: 256)
        let allocated = EvaEnvelopeAllocator.allocate([
            .init(category: .planning, payload: .object(["tasks": .array(records)])),
            .init(category: .journal, payload: .array(records)),
        ], budget: budget)
        let encoded = try JSONEncoder.evaCloud.encode(allocated)
        let reserved = budget.systemPromptTokens + budget.reservedOutputTokens
            + budget.slashContextTokens + budget.executiveContextTokens
        let cap = LLMTokenBudgetEstimator.estimatedCharacterBudget(
            for: max(256, budget.inputTokens - reserved)
        )

        XCTAssertLessThanOrEqual(encoded.count, cap + 512, "Section framing is bounded overhead")
        XCTAssertNoThrow(try JSONSerialization.jsonObject(with: encoded))
        XCTAssertTrue(allocated.contains(where: { $0.category == .planning }))
        XCTAssertTrue(allocated.first(where: { $0.category == .planning })?.metadata?.availability == "partial")
    }

    func testExclusionDropsWholeRecordAndInvalidatesPlanningOverview() throws {
        let suiteName = "EvaContextReceiptAndExclusionTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        var exclusions = EvaContextExclusionStore.load(defaults: defaults)
        exclusions.exclude(category: "planning", sourceID: "task-1", defaults: defaults)
        let section = EvaCloudContextSection(
            category: .planning,
            payload: .object([
                "renderedOverview": .string("Private task title"),
                "tasks": .array([
                    .object(["id": .string("task-1"), "title": .string("Private task title")]),
                    .object(["id": .string("task-2"), "title": .string("Keep this")]),
                ]),
            ]),
            metadata: .init(
                availability: "complete",
                availableCount: 2,
                includedCount: 2,
                partialReasons: [],
                sourceIDs: ["task-1", "task-2"],
                selectionReasons: ["semanticMatch"],
                freshnessAt: Date(timeIntervalSince1970: 1_000)
            )
        )

        let filtered = exclusions.filtering(section)
        let encoded = String(decoding: try JSONEncoder.evaCloud.encode(filtered), as: UTF8.self)
        XCTAssertFalse(encoded.contains("task-1"))
        XCTAssertFalse(encoded.contains("Private task title"))
        XCTAssertTrue(encoded.contains("task-2"))
        XCTAssertTrue(encoded.contains("userExcludedRecords"))
        XCTAssertEqual(filtered.metadata?.includedCount, 1)
        XCTAssertEqual(filtered.metadata?.selectionReasons, ["semanticMatch"])
        XCTAssertEqual(filtered.metadata?.freshnessAt, Date(timeIntervalSince1970: 1_000))
    }

    func testAllocatorPreservesProviderPartialReasonsAndSelectionProvenance() {
        let section = EvaCloudContextSection(
            category: .dayLoop,
            payload: .object(["closedDays": .number(4)]),
            metadata: .init(
                availability: "partial", availableCount: nil, includedCount: nil,
                partialReasons: ["openHistoryUnavailable"], sourceIDs: [],
                selectionReasons: ["routeBaseline"], freshnessAt: Date(timeIntervalSince1970: 2_000)
            )
        )
        let allocated = EvaEnvelopeAllocator.allocate(
            [section], budget: .cloud(inputTokenCap: 4_000, outputTokenCap: 500)
        )
        XCTAssertEqual(allocated.first?.metadata?.availability, "partial")
        XCTAssertEqual(allocated.first?.metadata?.partialReasons, ["openHistoryUnavailable"])
        XCTAssertEqual(allocated.first?.metadata?.selectionReasons, ["routeBaseline"])
    }

    func testHistoricalReceiptRemainsImmutableWhenFutureExclusionsChange() throws {
        let runtime = EvaTurnRuntime(
            provider: .cloud,
            modelName: EvaModelSelection.cloudSentinel,
            route: .chat,
            configurationVersion: 8,
            contractVersion: 3,
            consentRevision: 4,
            grants: [],
            creditReady: true,
            contextBudget: .cloud(inputTokenCap: 4_000, outputTokenCap: 500),
            contextRenderMode: .richCloud,
            outputProcessingPolicy: .cloudValidated,
            timeoutPolicy: .init(firstByteSeconds: 20, inactivitySeconds: 25, resourceSeconds: 75)
        )
        let section = EvaCloudContextSection(
            category: .planning,
            payload: .array([.object(["id": .string("task-1")])]),
            metadata: .init(
                availability: "complete", availableCount: 1, includedCount: 1,
                partialReasons: [], sourceIDs: ["task-1"]
            )
        )
        let receipt = try XCTUnwrap(EvaContextReceiptSnapshot.make(runtime: runtime, sections: [section]))
        let original = try XCTUnwrap(receipt.encodedData)

        var exclusions = EvaContextExclusionStore.load()
        exclusions.exclude(category: "planning", sourceID: "task-1")
        defer { exclusions.restore(category: "planning", sourceID: "task-1") }

        XCTAssertEqual(receipt.encodedData, original)
        XCTAssertEqual(receipt.categories.first?.sourceIDs, ["task-1"])
    }
}
