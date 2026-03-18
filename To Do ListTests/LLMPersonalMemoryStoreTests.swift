import XCTest
import MLXLMCommon
@testable import To_Do_List

final class LLMPersonalMemoryStoreTests: XCTestCase {
    func testNormalizationDropsWhitespaceOnlyEntries() {
        let entries = [
            LLMPersonalMemoryEntry(text: "  "),
            LLMPersonalMemoryEntry(text: "  Keep coffee after lunch  "),
            LLMPersonalMemoryEntry(text: "\n\t")
        ]

        let normalized = LLMPersonalMemoryStoreV1.normalized(entries)

        XCTAssertEqual(normalized.count, 1)
        XCTAssertEqual(normalized.first?.text, "Keep coffee after lunch")
    }

    func testLegacyDefaultsStoreMigratesIntoSecureStorage() throws {
        let suiteName = "LLMPersonalMemoryStoreTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let secureStore = LLMSecureBlobStore(
            service: "LLMPersonalMemoryStoreTests.\(UUID().uuidString)",
            account: LLMPersonalMemoryDefaultsStore.key
        )
        defer {
            defaults.removePersistentDomain(forName: suiteName)
            secureStore.clear()
        }

        let legacyStore = LLMPersonalMemoryStoreV1(
            preferences: [LLMPersonalMemoryEntry(text: "Prefers short answers")]
        )
        let legacyData = try JSONEncoder().encode(legacyStore)
        defaults.set(legacyData, forKey: LLMPersonalMemoryDefaultsStore.key)

        let migrated = LLMPersonalMemoryDefaultsStore.load(defaults: defaults, secureStore: secureStore)

        XCTAssertEqual(migrated, legacyStore)
        if secureStore.loadData() == legacyData {
            XCTAssertNil(defaults.data(forKey: LLMPersonalMemoryDefaultsStore.key))
        } else {
            XCTAssertEqual(defaults.data(forKey: LLMPersonalMemoryDefaultsStore.key), legacyData)
        }
    }

    func testStableMemoryCompilerBuildsExecutiveSections() {
        let store = LLMPersonalMemoryStoreV1(
            preferences: [
                LLMPersonalMemoryEntry(text: "Prefer concise answers"),
                LLMPersonalMemoryEntry(text: "Prioritize ruthlessly")
            ],
            routines: [
                LLMPersonalMemoryEntry(text: "Energy drops after lunch"),
                LLMPersonalMemoryEntry(text: "Starting is the hardest part")
            ],
            currentGoals: [
                LLMPersonalMemoryEntry(text: "Ship the weekly review flow")
            ]
        )

        let block = EvaStableMemoryCompiler.promptBlock(from: store, model: .defaultModel)

        XCTAssertEqual(
            block,
            """
            User memory:
            Working style: Prefer concise answers; Prioritize ruthlessly
            Routines and blockers: Energy drops after lunch; Starting is the hardest part
            Current goals: Ship the weekly review flow
            """
        )
    }

    func testStableMemoryCompilerTrimsToPersonalMemoryBudget() {
        let store = LLMPersonalMemoryStoreV1(
            preferences: (0..<6).map { LLMPersonalMemoryEntry(text: "Preference \($0) " + String(repeating: "x", count: 120)) },
            routines: [],
            currentGoals: []
        )

        let block = EvaStableMemoryCompiler.promptBlock(from: store, model: .defaultModel)
        let tokenCount = LLMTokenBudgetEstimator.estimatedTokenCount(for: block ?? "")

        XCTAssertNotNil(block)
        XCTAssertLessThanOrEqual(tokenCount, ModelConfiguration.defaultModel.tokenBudget.personalMemoryTokens)
    }
}
